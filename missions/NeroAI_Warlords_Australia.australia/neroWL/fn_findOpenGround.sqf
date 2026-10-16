/* Bounded terrain search. Returns ATL ground coordinates or [] on failure.
 * Terrain buildings must be checked separately: findEmptyPosition alone can
 * accept a position inside an Australia model with imperfect geometry. */
params ["_center",["_radius",450],["_clearance",80],["_ignore",objNull]];
private _found = [];
for "_attempt" from 0 to 119 do {
    private _ring = floor (_attempt / 12);
    private _distance = if (_attempt == 0) then {0} else {_radius * ((_ring + 1) / 10)};
    private _angle = (_attempt mod 12) * 30;
    private _candidate = [(_center # 0) + sin _angle * _distance,(_center # 1) + cos _angle * _distance,0];
    private _flat = _candidate isFlatEmpty [5,-1,0.12,30,0,false,_ignore];
    if (count _flat >= 3) then {
        private _pos = ASLToATL _flat;
        if (!surfaceIsWater _pos && {count (nearestTerrainObjects [_pos,["HOUSE","BUILDING","WALL","FENCE"],_clearance,false,true]) == 0} && {count (nearestObjects [_pos,["House","LandVehicle"],8]) == 0} && {(nearestObjects [_pos,["Man"],3]) findIf {_x != _ignore && {alive _x}} < 0}) exitWith {
            _pos set [2,0];
            _found = _pos;
        };
    };
};
_found
