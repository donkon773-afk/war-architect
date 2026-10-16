/* Bounded hull-width sweep of a short path. GEOM rays at two heights, terrain,
 * water and nearby people/vehicles. It is a conservative query, not PhysX. */
params ["_mover","_points",["_width",3],["_length",6]];
private _start = getPosATL _mover;
private _near = nearestObjects [_mover,["CAManBase","LandVehicle"],45];
private _others = _near select {_x != _mover && {!(_x in crew _mover)} && {!(_x isKindOf "CAManBase") || {alive _x && {isNull objectParent _x}}}};
private _safe = true;private _previous = _start;
private _half = _width/2+0.6;
private _slope = if (_mover isKindOf "Tank") then {0.91} else {0.94};
{
    private _end = _x;private _distance = _previous distance2D _end;
    private _bearing = _previous getDir _end;
    /* Include hull overhang at subsequent bends; the initial rear escape
     * checks the leading face, so a touching rock at the nose can be left. */
    private _steps = ((ceil (_distance/3)) max 1) min 12;
    for "_step" from 1 to _steps do {
        private _p = _previous getPos [_distance*_step/_steps,_bearing];
        if ((surfaceIsWater _p && {!isOnRoad _p}) || {((surfaceNormal _p) # 2) < _slope}) exitWith {_safe = false;};
    };
    if (!_safe) exitWith {};
    {
        private _other = _x;private _radius = 0.8;
        if (_other isKindOf "LandVehicle") then {private _box = 2 boundingBoxReal _other;_radius = (_box param [2,3])+0.5;};
        if ([getPosATL _other,_previous,_end] call NeroAI_fnc_motionPointDistance < _half+_radius) exitWith {_safe = false;};
    } forEach _others;
    if (!_safe) exitWith {};
    {
        private _offset = _x;
        {
            private _height = _x;
            private _a = _previous getPos [_offset,_bearing+90];
            private _b = _end getPos [_offset,_bearing+90];
            _b = _b getPos [_length/2,_bearing];
            _a set [2,_height];_b set [2,_height];
            if ((lineIntersectsSurfaces [ATLToASL _a,ATLToASL _b,_mover,objNull,true,1,"GEOM","NONE"]) isNotEqualTo []) exitWith {_safe = false;};
        } forEach [0.35,1.2];
        if (!_safe) exitWith {};
    } forEach [-_half,0,_half];
    if (!_safe) exitWith {};
    _previous = _end;
} forEach _points;
_safe
