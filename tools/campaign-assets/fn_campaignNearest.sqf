/* Stable indices: apply does not define _forEachIndex. */
params ["_positions","_point"];
private _rank=[];
{private _dx=(_x#0)-(_point#0);private _dy=(_x#1)-(_point#1);private _distance=sqrt (_dx*_dx+_dy*_dy);private _index=_forEachIndex;private _row=[_distance,_index];
 private _slot=_rank findIf {(_x#0)>_distance || {(_x#0)==_distance && {(_x#1)>_index}}};
 if (_slot<0) then {_rank pushBack _row;} else {_rank=(_rank select [0,_slot])+[_row]+(_rank select [_slot,count _rank-_slot]);};
} forEach _positions;
_rank
