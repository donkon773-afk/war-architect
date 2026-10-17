// Server-only, explicit creation/load boundary. Never a gameplay teleport loop.
params ["_hq","_requested","_side",["_reason","creation"]];
if (!isServer || {isNull _hq} || {!local _hq} || {!alive _hq}) exitWith {false};
private _valid = {
    params ["_p"];
    _p isEqualType [] && {count _p >= 2} && {(_p#0) isEqualType 0} && {(_p#1) isEqualType 0} && {(_p#0)>0} && {(_p#1)>0} && {(_p#0)<worldSize} && {(_p#1)<worldSize} && {!surfaceIsWater _p}
};
private _center = _requested;
if !([_center] call _valid) then {
    _center = getArray (missionConfigFile >> "CfgNeroOperation" >> (if (_side==west) then {"spawnWest"} else {"spawnEast"}));
};
if !([_center] call _valid) exitWith {diag_log format ["[WarArchitect BECTI HQ] invalid anchor side=%1 reason=%2",_side,_reason];false};
// Saved ATL height may be kilometres below terrain after an earlier bad spawn.
// Find a free ground position using XY, never restore that height or velocity.
private _chosen = [];
for "_i" from 0 to 24 do {
    private _probe = [_center#0,_center#1,0];
    if (_i>0) then {_probe = _probe getPos [12 + 12*floor((_i-1)/8),45*(_i-1)];};
    private _empty = _probe findEmptyPosition [0,8,typeOf _hq];
    if ([_empty] call _valid && {_empty distance2D _center <= 48} && {(surfaceNormal _empty)#2 > 0.85}) exitWith {_chosen = _empty};
};
if (count _chosen<2) exitWith {diag_log format ["[WarArchitect BECTI HQ] no free ground side=%1 reason=%2 anchor=%3",_side,_reason,_center];false};
_hq setVelocity [0,0,0];
_hq setPosATL [_chosen#0,_chosen#1,0.25];
_hq setVectorUp (surfaceNormal _chosen);
diag_log format ["[WarArchitect BECTI HQ] placed side=%1 reason=%2 class=%3 requested=%4 position=%5",_side,_reason,typeOf _hq,_requested,getPosATL _hq];
true
