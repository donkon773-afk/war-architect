/* Own-side engine facts, cached for at most 3 s. No hidden enemy enumeration.
 * [effective, initial, ready, readyVehicle, lightAT, heavyAT, riflemen, reason, suppression, usableCrew] */
params ["_group"];
if (isNull _group) exitWith {[0,0,false,false,0,0,0,"нет группы",0,0]};
private _now = diag_tickTime;
private _old = _group getVariable ["NeroWL_rulesCombatFacts",[-1e6,[]]];
if ((_now - (_old # 0)) < 3) exitWith {_old # 1};
private _living = (units _group) select {alive _x && {!(_x getVariable ["NeroWL_deliveryPending",false])}};
private _usable = _living select {lifeState _x in ["HEALTHY","INJURED"] && {!(_x getVariable ["ACE_isUnconscious",false])} && {canMove _x}};
private _initial = (_group getVariable ["NeroAI_initialStrength",count _living]) max (count _living) max 1;
private _effective = 0;
private _lightAT = 0;
private _heavyAT = 0;
private _riflemen = 0;
private _suppression = 0;
{
    private _unit = _x;
    private _magazines = (magazinesAmmoFull _unit) select {(_x param [1,0]) > 0};
    private _primary = primaryWeapon _unit;
    private _compatible = if (_primary isEqualTo "") then {[]} else {compatibleMagazines [_primary,"this"]};
    private _rifleReady = (_magazines findIf {(_x # 0) in _compatible}) >= 0;
    if (_rifleReady) then {_riflemen = _riflemen + 1;};
    private _launcher = secondaryWeapon _unit;
    private _unitTier = 0;
    if (_launcher != "") then {
        private _launcherMags = compatibleMagazines [_launcher,"this"];
        {if ((_x # 0) in _launcherMags) then {_unitTier = _unitTier max ([_x # 0] call NeroAI_fnc_rulesMagazineTier);};} forEach _magazines;
    };
    if (_unitTier >= 1) then {_lightAT = _lightAT + 1;};
    if (_unitTier >= 2) then {_heavyAT = _heavyAT + 1;};
    if (_rifleReady || {_unitTier > 0}) then {_effective = _effective + 1; _suppression = _suppression + getSuppression _unit;};
} forEach _usable;
if (_effective > 0) then {_suppression = _suppression / _effective;};
private _vehicles = [];
{private _v = objectParent _x;if (!isNull _v && {alive _v} && {_v isKindOf "LandVehicle"} && {!(_v isKindOf "StaticWeapon")}) then {_vehicles pushBackUnique _v;};} forEach _usable;
private _readyVehicle = false;
{
    private _v = _x;
    private _driver = driver _v;
    private _readyWeapon = false;
    private _vehicleTier = 0;
    if (canFire _v) then {
        {
            private _path = _x param [1,[]];
            private _shooter = if (_path isEqualTo [-1]) then {driver _v} else {_v turretUnit _path};
            if ((_x param [2,0]) > 0 && {_shooter in _usable}) then {
                private _magazine = _x # 0;
                private _compatibleWeapon = (_v weaponsTurret _path) findIf {_magazine in (compatibleMagazines _x)};
                private _ammoCfg = configFile >> "CfgAmmo" >> getText (configFile >> "CfgMagazines" >> _magazine >> "ammo");
                private _simulation = toLower (getText (_ammoCfg >> "simulation"));
                if (_compatibleWeapon >= 0 && {_simulation in ["shotbullet","shotshell","shotmissile","shotrocket"]} && {getNumber (_ammoCfg >> "airLock") != 2}) then {_readyWeapon = true;_vehicleTier = _vehicleTier max ([_magazine] call NeroAI_fnc_rulesMagazineTier);};
            };
        } forEach (magazinesAllTurrets _v);
    };
    if (_readyWeapon) then {
        if (_vehicleTier >= 1) then {_lightAT = _lightAT + 1;};
        if (_vehicleTier >= 2) then {_heavyAT = _heavyAT + 1;};
        if (canMove _v && {_driver in _usable} && {!(_v getVariable ["NeroWL_needsRepair",false])}) then {_readyVehicle = true;};
    };
} forEach _vehicles;
/* A mounted crew can fight with its vehicle even if it has few riflemen.
 * A large mechanised squad still participates as infantry in the operation. */
private _crewOnly = _readyVehicle && {(_living findIf {
    isNull objectParent _x || {(assignedVehicleRole _x param [0,""]) isEqualTo "cargo"}
}) < 0};
private _minimum = _group getVariable ["NeroAI_rulesMinAssaultStrength",missionNamespace getVariable ["NeroAI_rulesMinAssaultStrength",6]];
private _readiness = [_effective,_initial,_crewOnly,_minimum,missionNamespace getVariable ["NeroAI_rulesMinAssaultRatio",0.6],_suppression] call NeroAI_fnc_rulesReadiness;
private _result = [_effective,_initial,_readiness # 0,_crewOnly,_lightAT,_heavyAT,_riflemen,_readiness # 1,_suppression,count _usable];
_group setVariable ["NeroWL_rulesCombatFacts",[_now,_result]];
_result
