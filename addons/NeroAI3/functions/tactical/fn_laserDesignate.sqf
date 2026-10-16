/* Assigns at most two equipped AI designators to a confirmed hostile near the
 * ordered coordinates. It never invents or creates a target. */
params ["_group", "_position"];
if (!isServer || {!([_group] call NeroAI_fnc_validateGroup)}) exitWith {[false, "Группа недоступна."]};
if !(_position isEqualType [] && {count _position >= 2}) exitWith {[false, "Для лазерной подсветки нужны координаты."]};

private _leader = leader _group;
private _friendlySide = side _leader;
private _designators = (units _group) select {
    private _unit = _x;
    alive _unit && {local _unit} && {
        private _laserWeapons = (weapons _unit) select {
            private _weaponClass = _x;
            "laserdesignator" in toLower _weaponClass
        };
        !(_laserWeapons isEqualTo []) && {_unit ammo (_laserWeapons # 0) > 0}
    }
};
if (_designators isEqualTo []) exitWith {
    _group setVariable ["NeroAI_designationState", "NO_DESIGNATOR", true];
    [false, "В группе нет исправного лазерного целеуказателя."]
};

private _candidates = nearestObjects [_position, ["LandVehicle", "Air", "Ship", "Man"], 100];
_candidates = _candidates select {
    alive _x && {(_friendlySide getFriend (side _x)) < 0.6} && {(_leader knowsAbout _x) > 0}
};
if (_candidates isEqualTo []) exitWith {
    { _x doWatch _position; } forEach ((units _group) select {alive _x});
    [_group] call NeroAI_fnc_uavRecon;
    _group setVariable ["NeroAI_designationState", ["SEARCHING", _position, diag_tickTime], true];
    [false, "В указанной точке нет подтверждённой цели; группа ведёт безопасную доразведку."]
};

private _ranked = [];
{
    private _priority = if (_x isKindOf "Man") then {1} else {0};
    _ranked pushBack [(_priority * 1000) + (_x distance2D _position), _x];
} forEach _candidates;
_ranked sort true;
private _target = (_ranked # 0) # 1;

_designators = _designators select {
    [_x, "VIEW", _target] checkVisibility [eyePos _x, aimPos _target] > 0.12
};
if (_designators isEqualTo []) exitWith {
    { _x doWatch _position; } forEach ((units _group) select {alive _x});
    [_group] call NeroAI_fnc_uavRecon;
    _group setVariable ["NeroAI_designationState", ["NO_LINE_OF_SIGHT", netId _target, _position, diag_tickTime], true];
    [false, "Цель подтверждена, но прямой видимости для лазера нет; группа продолжает доразведку."]
};

_designators resize ((count _designators) min 2);
{
    private _operator = _x;
    private _laserWeapons = (weapons _operator) select {
        private _weaponClass = _x;
        "laserdesignator" in toLower _weaponClass
    };
    private _weapon = _laserWeapons # 0;
    _operator doTarget _target;
    _operator doWatch _target;
    [_operator, _target, _weapon, _group] spawn {
        params ["_operator", "_target", "_weapon", "_group"];
        uiSleep 1.5;
        if (!alive _operator || {isNull _target} || {!local _operator}) exitWith {};
        _operator selectWeapon _weapon;
        _operator forceWeaponFire [_weapon, _weapon];
        uiSleep 0.5;
        if (!isNull (laserTarget _operator)) then {
            _group setVariable ["NeroAI_designationState", ["ACTIVE", netId _target, getPosATL _target, diag_tickTime], true];
        } else {
            _group setVariable ["NeroAI_designationState", ["ORDERED_NO_SPOT", netId _target, getPosATL _target, diag_tickTime], true];
            ["WARN", format ["Laser spot was not confirmed for %1.", _group getVariable ["NeroAI_callsign", groupId _group]]] call NeroAI_fnc_log;
        };
    };
} forEach _designators;

private _targetPos = getPosATL _target;
_group setVariable ["NeroAI_designationState", ["ORDERED", netId _target, _targetPos, diag_tickTime], true];
private _callsign = _group getVariable ["NeroAI_callsign", groupId _group];
[_leader, format ["%1: цель %2 подтверждена, начинаю лазерную подсветку, сетка %3-%4.", _callsign, typeOf _target, round (_targetPos # 0), round (_targetPos # 1)], "SIDE"] remoteExecCall ["NeroAI_fnc_clientSpeech", 0];
["INFO", format ["%1 ordered %2 designator(s) onto %3.", _callsign, count _designators, typeOf _target]] call NeroAI_fnc_log;
[true, format ["Цель %1 назначена операторам лазерной подсветки.", typeOf _target]]
