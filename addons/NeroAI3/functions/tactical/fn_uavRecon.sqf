/* NeroAI 4.4.0 [Command]: RECON.
 *
 * LIVE INCIDENT (12-13.09): this used to grab `allUnitsUAV # 0` of the side
 * and connectTerminalToUAV it — i.e. the base package's armed strike UAVs,
 * parked cold. The connection woke their AI and they flew off across the map
 * to loiter. Base airframes are NEVER touched here any more.
 *
 * Two modes:
 *   - with a target position: a bounded RECON sortie through fn_dispatchAir
 *     (no-fly bubbles, standoff, time box, RTB, refuel/drain) — the same
 *     rules as CAS, using UAV_RECON / UAV_ARMED airframes that are READY;
 *   - without one: passive recon — what the group's own leader can see, plus
 *     any friendly UAV that is already airborne and not a parked base asset.
 * Either way the result lands in NeroAI_intel and is shared to neighbours. */
params ["_group", ["_position", []]];
if (!isServer || {!([_group] call NeroAI_fnc_validateGroup)}) exitWith {[false, "Группа недоступна.", []]};

private _cooldown = missionNamespace getVariable ["NeroAI_reconCooldownSeconds", 15];
private _now = diag_tickTime;
private _lastRecon = _group getVariable ["NeroAI_lastRecon", -_cooldown];
if ((_now - _lastRecon) < _cooldown) exitWith {[false, "Канал разведки ещё на перезарядке.", []]};

private _friendlySide = side (leader _group);
private _hasOperator = ((units _group) findIf {
    alive _x && {
        (_x getUnitTrait "UAVHacker") ||
        {(assignedItems _x findIf {"uavterminal" in toLower _x}) >= 0}
    }
}) >= 0;

private _sortieNote = "";
if (_hasOperator && {_position isEqualType []} && {(count _position) >= 2}) then {
    private _sortie = [_group, _position, "RECON"] call NeroAI_fnc_dispatchAir;
    _sortieNote = _sortie # 1;
    if (_sortie # 0) then { _group setVariable ["NeroAI_reconState", "SORTIE", true]; };
};

/* Observers: the leader, and any airborne friendly UAV that is not a cold base asset. */
private _observers = [leader _group];
{
    if (alive _x && {(side _x) isEqualTo _friendlySide} && {(getPosATL _x) # 2 > 20}
        && {!((_x getVariable ["NeroAI_airState", "PARKED"]) isEqualTo "PARKED")}) then { _observers pushBack _x; };
} forEach allUnitsUAV;

private _intel = [];
private _seen = [];
{
    private _obs = _x;
    {
        // nearTargets: [position, type, side, cost, object, positionAccuracy]
        private _target = _x param [4, objNull];
        private _combatObject = !isNull _target && {
            _target isKindOf "Man" || {_target isKindOf "LandVehicle"} ||
            {_target isKindOf "Air"} || {_target isKindOf "Ship"} ||
            {_target isKindOf "StaticWeapon"}
        };
        if (_combatObject && {alive _target} && {(_friendlySide getFriend (side _target)) < 0.6} && {!((netId _target) in _seen)}) then {
            _seen pushBack (netId _target);
            private _pos = _x # 0;
            _intel pushBack [_x # 1, [round (_pos # 0), round (_pos # 1)], round ((_obs knowsAbout _target) * 10), netId _target];
        };
    } forEach (_obs nearTargets 2500);
} forEach _observers;

_intel resize ((count _intel) min 20);
_group setVariable ["NeroAI_intel", _intel, true];
_group setVariable ["NeroAI_lastRecon", _now, true];
if !(_hasOperator) then { _group setVariable ["NeroAI_reconState", "NO_UAV_OPERATOR", true]; };
if !(_intel isEqualTo []) then {[_group, "данные разведки"] call NeroAI_fnc_shareIntel;};
[true, format ["Разведка: контактов %1.%2", count _intel, if (_sortieNote isEqualTo "") then {""} else {" " + _sortieNote}], _intel]
