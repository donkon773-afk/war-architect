/* The lost base approach, reachable now and historically owned. Prefer the
 * most recent recorded loss; otherwise use the nearest eligible approach. */
params ["_side"];
private _base = missionNamespace getVariable [format ["BIS_WL_base_%1",_side],objNull];
private _enemy = if (_side isEqualTo west) then {east} else {west};
if (isNull _base || {(_base getVariable ["BIS_WL_sectorSide",sideUnknown]) != _side}
    || {(missionNamespace getVariable [format ["BIS_WL_currentSector_%1",_enemy],objNull]) != _base}) exitWith {objNull};
private _listing = [_side] call NeroAI_fnc_wlSnapshot;
private _available = _listing param [1,[]];
private _history = missionNamespace getVariable [format ["BIS_WL_conqueredSectors_%1",_side],[]];
_history = _history + (missionNamespace getVariable [format ["NeroWL_ownershipHistory_%1",_side],[]]);
private _lost = missionNamespace getVariable [format ["NeroWL_lastLost_%1",_side],objNull];
private _candidates = (_base getVariable ["BIS_WL_connectedSectors",[]]) select {_x in _available && {_x in _history}};
if (_candidates isEqualTo []) exitWith {objNull};
if (_lost in _candidates) exitWith {_lost};
private _best = _candidates # 0;
{if ((_x distance2D _base) < (_best distance2D _base)) then {_best = _x;};} forEach _candidates;
_best
