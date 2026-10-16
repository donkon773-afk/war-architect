/* Candidate holding centers retain the combat exclusion and map turn margin. */
params ["_target","_home","_size",["_distance",13000],["_margin",3500]];
private _rank=[];
for "_angle" from 0 to 345 step 15 do {
 private _p=[(_target#0)+sin(_angle)*_distance,(_target#1)+cos(_angle)*_distance];
 if (_p#0>=_margin && {_p#1>=_margin} && {_p#0<=_size-_margin} && {_p#1<=_size-_margin}) then {private _dx=(_p#0)-(_home#0);private _dy=(_p#1)-(_home#1);_rank pushBack [_dx*_dx+_dy*_dy,_angle,_p];};
};_rank sort true;_rank apply {_x#2}
