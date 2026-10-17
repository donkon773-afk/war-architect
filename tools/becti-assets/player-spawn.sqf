// Called only at entry/respawn; never moves a player during normal play.
params ["_unit", ["_anchor", objNull], ["_reason", "entry"]];
if (isNull _unit || {!local _unit} || {!alive _unit}) exitWith {false};
private _side = side group _unit;
if !(_side in [west,east]) exitWith {false};
private _base = getArray (missionConfigFile >> "CfgNeroOperation" >> (if (_side == west) then {"spawnWest"} else {"spawnEast"}));
private _valid = {
 params ["_p"];
 _p isEqualType [] && {count _p >= 2} && {(_p#0) isEqualType 0} && {(_p#1) isEqualType 0} && {(_p#0) > 0} && {(_p#1) > 0} && {(_p#0) < worldSize} && {(_p#1) < worldSize} && {!surfaceIsWater _p}
};
private _center = if (_anchor isEqualType objNull) then {if (isNull _anchor) then {+_base} else {getPosATL _anchor}} else {+_anchor};
if !([_center] call _valid) then {_center = +_base};
if !([_center] call _valid) exitWith {diag_log format ["[WarArchitect BECTI] spawn refused: invalid base, side=%1 reason=%2",_side,_reason];false};
private _chosen = [];
// Every sample remains anchored to the base/HQ. No cumulative walk toward sea.
for "_attempt" from 0 to 23 do {
 private _angle = random 360;
 private _radius = 8 + random 22;
 private _candidate = [(_center#0) + sin _angle * _radius,(_center#1) + cos _angle * _radius,0];
 if ([_candidate] call _valid) then {
  private _empty = _candidate findEmptyPosition [0,6,typeOf _unit];
  if ([_empty] call _valid && {_empty distance2D _center <= 36}) exitWith {_chosen = _empty};
 };
 if (count _chosen >= 2) exitWith {};
};
if (count _chosen < 2) exitWith {diag_log format ["[WarArchitect BECTI] spawn refused: no free ground near %1, reason=%2",_center,_reason];false};
_unit setPosATL [_chosen#0,_chosen#1,0.25];
diag_log format ["[WarArchitect BECTI] player spawn side=%1 reason=%2 position=%3 water=%4",_side,_reason,getPosATL _unit,surfaceIsWater getPosATL _unit];
true
