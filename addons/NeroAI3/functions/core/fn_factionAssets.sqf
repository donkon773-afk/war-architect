/* NeroAI 4.7.0 [Any Warlords]: vehicle pools drawn from the MISSION's own factions.
 *
 *   [_sideKey, _kind] call NeroAI_fnc_factionAssets  ->  [class, ...]  (may be [])
 *
 * _sideKey  BLUE | RED | GREEN            (Warlords: WEST / EAST / RESISTANCE)
 * _kind     TANK | APC | CAR | MORTAR | UAV_ARMED | UAV_RECON | ALL
 *
 * The faction comes from NeroAI_fnc_scenarioProfile (BIS_WL_factionsPool). Two
 * sources, merged, deduplicated, cached per faction:
 *   1. the Warlords group pools — for GREEN the very lists vanilla uses to spawn
 *      sector garrisons (BIS_WL_grpPool_motorized/mechanized/armored), for the
 *      armies CfgGroups >> West/East >> <faction>; every "vehicle" entry that is
 *      not a soldier;
 *   2. a one-off CfgVehicles scan: scope 2, faction == <faction>, land vehicle or
 *      UAV or static mortar. This is what makes an RHS/CUP/vanilla port work
 *      without a class list — the mod's own faction tag is the catalogue.
 * Kinds follow fn_purchaseAsset: a TANK/APC/CAR must carry a real weapon
 * (horns, smoke, lasers, countermeasures do not count) and must not be a
 * support vehicle (ambulance/repair/fuel/ammo); unarmed transports are left
 * out on purpose — a garrison park is meant to fight. */
params [["_sideKey", "GREEN"], ["_kind", "ALL"]];
_sideKey = toUpper _sideKey;
_kind = toUpper _kind;
if (!isServer) exitWith {[]};

private _profile = [] call NeroAI_fnc_scenarioProfile;
private _faction = (_profile getOrDefault ["factionClasses", createHashMap]) getOrDefault [_sideKey, ""];
private _cache = missionNamespace getVariable ["NeroAI_factionAssetCache", createHashMap];
private _cacheKey = format ["%1|%2", _sideKey, _faction];
private _pools = _cache getOrDefault [_cacheKey, nil];

if (isNil "_pools") then {
    private _cfgVehs = configFile >> "CfgVehicles";
    private _cfgWeapons = configFile >> "CfgWeapons";
    private _fnc_armed = {
        params ["_cfg"];
        if (isClass (_cfg >> "Components" >> "TransportPylonsComponent")) exitWith {true};
        private _real = {
            (count (_this select {
                private _w = toLower _x;
                !(_w isEqualTo "") && {(_w find "horn") < 0} && {(_w find "smoke") < 0} && {(_w find "laser") < 0}
                    && {(_w find "counter") < 0} && {(_w find "cmflauncher") < 0} && {(_w find "sensorsmanager") < 0} && {(_w find "headlights") < 0}
            })) > 0
        };
        if ((getArray (_cfg >> "weapons")) call _real) exitWith {true};
        private _armed = false;
        {
            if ((getArray (_x >> "weapons")) call _real) exitWith { _armed = true; };
            { if ((getArray (_x >> "weapons")) call _real) exitWith { _armed = true; }; } forEach ("true" configClasses (_x >> "Turrets"));
            if (_armed) exitWith {};
        } forEach ("true" configClasses (_cfg >> "Turrets"));
        _armed
    };
    private _fnc_support = {
        params ["_cfg"];
        private _name = toLower (getText (_cfg >> "displayName"));
        (_name find "ambulance") >= 0 || {(_name find "medic") >= 0} || {(_name find "repair") >= 0} || {(_name find "fuel") >= 0}
            || {(_name find "ammo") >= 0} || {(_name find "salvage") >= 0} || {(_name find "санитар") >= 0} || {(_name find "medevac") >= 0}
    };
    /* kind of one class, "" when it is nothing a garrison should field */
    private _fnc_kindOf = {
        params ["_class"];
        private _cfg = _cfgVehs >> _class;
        if (!isClass _cfg || {getNumber (_cfg >> "scope") != 2}) exitWith {""};
        if (getNumber (_cfg >> "isUav") == 1) exitWith {
            if (_class isKindOf "Air" || {_class isKindOf "LandVehicle"}) then {
                if ([_cfg] call _fnc_armed) then {"UAV_ARMED"} else {"UAV_RECON"}
            } else {""}
        };
        if (_class isKindOf "StaticMortar") exitWith {"MORTAR"};
        if (!(_class isKindOf "LandVehicle") || {_class isKindOf "StaticWeapon"}) exitWith {""};
        if ([_cfg] call _fnc_support || {!([_cfg] call _fnc_armed)}) exitWith {""};
        [_class] call NeroAI_fnc_groundAssetKind
    };

    _pools = createHashMap;
    { _pools set [_x, []]; } forEach ["TANK", "APC", "CAR", "MORTAR", "UAV_ARMED", "UAV_RECON"];
    private _fnc_add = {
        params ["_class"];
        private _k = [_class] call _fnc_kindOf;
        if !(_k isEqualTo "") then {
            private _list = _pools get _k;
            _list pushBackUnique _class;
        };
    };

    if !(_faction isEqualTo "") then {
        /* 1. Warlords group pools / CfgGroups of this faction */
        private _groupClasses = [];
        if (_sideKey isEqualTo "GREEN") then {
            {
                private _pool = missionNamespace getVariable [_x, []];
                if (_pool isEqualType []) then { _groupClasses append (_pool select {_x isEqualType configNull}); };
            } forEach ["BIS_WL_grpPool_motorized", "BIS_WL_grpPool_mechanized", "BIS_WL_grpPool_armored"];
        };
        if (_groupClasses isEqualTo []) then {
            private _branch = switch (_sideKey) do { case "RED": {"East"}; case "GREEN": {"Indep"}; default {"West"} };
            private _factionCfg = configFile >> "CfgGroups" >> _branch >> _faction;
            if (isClass _factionCfg) then {
                { _groupClasses append ("true" configClasses _x); } forEach ("true" configClasses _factionCfg);
            };
        };
        {
            { [getText (_x >> "vehicle")] call _fnc_add; } forEach ("true" configClasses _x);
        } forEach _groupClasses;

        /* 2. CfgVehicles by faction tag — the mod's own catalogue */
        private _byFaction = format ["getNumber (_x >> 'scope') == 2 && {getText (_x >> 'faction') == '%1'}", _faction] configClasses _cfgVehs;
        { [configName _x] call _fnc_add; } forEach _byFaction;
    };

    _cache set [_cacheKey, _pools];
    missionNamespace setVariable ["NeroAI_factionAssetCache", _cache];
    ["INFO", format ["Faction assets %1 (%2): tank %3, apc %4, car %5, mortar %6, uav armed %7 / recon %8.", _sideKey, _faction,
        count (_pools get "TANK"), count (_pools get "APC"), count (_pools get "CAR"), count (_pools get "MORTAR"),
        count (_pools get "UAV_ARMED"), count (_pools get "UAV_RECON")]] call NeroAI_fnc_log;
};

if (_kind isEqualTo "ALL") exitWith { +_pools };
+(_pools getOrDefault [_kind, []])
