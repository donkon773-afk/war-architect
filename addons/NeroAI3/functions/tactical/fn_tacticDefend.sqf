/* Bounded defence adapter. Stock LAMBS Garrison/Defend install deferred CBA
 * callbacks/PFHs that survive terminate, and Defend clears native waypoints.
 * Keep LAMBS Danger for combat; own just the reversible positioning here. */
params ["_group","_position","_radius","_buildings","_epoch"];
private _live = {!isNull _group && {local _group} && {(_group getVariable ["NeroWL_routeEpoch",-1]) isEqualTo _epoch}};
if !(call _live) exitWith {};
private _units = units _group select {alive _x && {local _x} && {!isPlayer _x} && {isNull objectParent _x}};
private _spots = [];
if (_buildings) then {{_spots append (_x buildingPos -1);} forEach nearestObjects [_position,["House","Building"],_radius];};
if (_spots isEqualTo []) then {_spots = (nearestTerrainObjects [_position,["WALL","BUNKER","BUSH"],_radius,false,true]) apply {getPosATL _x};};
_spots = _spots select {!surfaceIsWater _x};
_group enableAttack false;
private _orders = [];
{
    private _spot = _spots param [_forEachIndex,_position getPos [8 + 3 * _forEachIndex,137 * _forEachIndex]];
    _orders pushBack [_x,_spot];
    _x doMove _spot;
} forEach _units;
while {(call _live) && {_orders findIf {alive (_x # 0)} >= 0}} do {
    {
        _x params ["_unit","_spot"];
        if (alive _unit && {local _unit} && {!isPlayer _unit} && {group _unit isEqualTo _group} && {_unit distance2D _spot < 3}) then {_unit disableAI "PATH";};
    } forEach _orders;
    sleep 3;
};
