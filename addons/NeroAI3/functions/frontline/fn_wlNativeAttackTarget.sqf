params ["_unit",["_native",objNull]];
private _side = side group _unit;
private _counter = [_side] call NeroAI_fnc_wlCounterTarget;
private _base = missionNamespace getVariable [format ["BIS_WL_base_%1",_side],objNull];
private _defending = [_unit,_base] call NeroAI_fnc_wlNativeDefense;
private _attackers = missionNamespace getVariable [format ["NeroWL_nativeHQCounter_%1",_side],[]];
if (!isNull _counter && {!_defending} && {(netId group _unit) in _attackers}) exitWith {_counter};
_native
