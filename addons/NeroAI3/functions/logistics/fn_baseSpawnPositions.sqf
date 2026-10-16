/* Finite pre-payment plan for NeroAI carts; no model spawning for measurement.
 * isFlatEmpty returns ASL and excludes many static obstacles, not all units. */
params ["_base","_cart"];
if (isNull _base || {_cart isEqualTo []} || {count _cart > 32}) exitWith {[]};
private _radius = (((_base getVariable ["Size",300])/2)-15) min 180;
if (_radius < 15) exitWith {[]};
private _positions = [];private _reserved = [];
{
    private _class = _x;private _man = _class isKindOf "Man";
    /* sizeOf may be zero until a model exists: keep a conservative floor. */
    private _space = if (_man) then {2} else {(sizeOf _class/2) max 9};
    if (_space > 25) exitWith {_positions = [];};
    private _chosen = [];
    for "_try" from 0 to 47 do {
        private _p = (getPosATL _base) getPos [15+(_radius-15)*sqrt ((_try+1)/48),(_try+_forEachIndex*7)*137.5];
        _p set [2,0];
        private _modelFits = (_p findEmptyPosition [0,0,_class]) isNotEqualTo [];
        private _flat = if (_modelFits) then {_p isFlatEmpty [_space,-1,0.2,_space,0,false,objNull]} else {[]};
        if (_flat isNotEqualTo []) then {
            private _candidate = ASLToATL _flat;_candidate set [2,0];
            private _near = nearestObjects [_candidate,["CAManBase","LandVehicle","Air","Ship"],_space+15];
            private _clear = (_near findIf {
                private _r = if (_x isKindOf "Man") then {1} else {((2 boundingBoxReal _x) param [2,9]) max 1};
                (_x distance2D _candidate) < _space+_r+1
            }) < 0;
            if (_clear && {(_reserved findIf {(_x # 0) distance2D _candidate < (_x # 1)+_space+1}) < 0}) exitWith {_chosen = _candidate;};
        };
    };
    if (_chosen isEqualTo []) exitWith {_positions = [];};
    _positions pushBack _chosen;_reserved pushBack [_chosen,_space];
} forEach _cart;
if (count _positions != count _cart) exitWith {[]};
_positions
