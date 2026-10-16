params ["_unit", ["_freeze", false]];
if (!isServer || {isNull _unit} || {!isPlayer _unit}) exitWith {false};

private _uid = getPlayerUID _unit;
if (_uid isEqualTo "") exitWith {false};

private _existing = NeroAI_playerAuthority getOrDefault [_uid, []];
private _pending = _existing param [5, false];
if (_pending && {!_freeze}) exitWith {false};

private _curator = getAssignedCuratorLogic _unit;
if (isNull _curator) then {
    private _matches = allCurators select {
        (getAssignedCuratorUnit _x) isEqualTo _unit
    };
    if !(_matches isEqualTo []) then {_curator = _matches # 0;};
};
if (isNull _curator && {!(_existing isEqualTo [])}) then {
    _curator = _existing param [0, objNull];
};

private _wasLeader = _unit getVariable ["NeroAI_wasGroupLeader", false];
private _highCommandGroups = _unit getVariable ["NeroAI_highCommandGroups", []];

if (!_freeze && {alive _unit}) then {
    _wasLeader = (leader group _unit) isEqualTo _unit;
    _highCommandGroups = hcAllGroups _unit;
    _unit setVariable ["NeroAI_wasGroupLeader", _wasLeader];
    _unit setVariable ["NeroAI_highCommandGroups", _highCommandGroups];
};

/* curator, leader flag, HC groups, old object, timestamp, pending restore */
NeroAI_playerAuthority set [_uid, [
    _curator,
    _wasLeader,
    _highCommandGroups,
    _unit,
    diag_tickTime,
    _freeze
]];
true
