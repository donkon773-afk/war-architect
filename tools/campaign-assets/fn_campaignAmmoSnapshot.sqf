params ["_turrets","_pylons"];
if !(_turrets isEqualType [] && {_pylons isEqualType []}) exitWith {false};
if (count _turrets>128 || {count _pylons>32}) exitWith {false};
private _class={params ["_s"];_s isEqualType "" && {count _s>0} && {count _s<160} && {toArray _s findIf {!(_x>=48 && {_x<=57} || {_x>=65 && {_x<=90}} || {_x>=97 && {_x<=122}} || {_x==95})}<0}};
private _count={params ["_n","_min","_max"];_n isEqualType 0 && {_n>=_min} && {_n<=_max} && {floor _n==_n}};
private _valid=true;private _indices=[];
{if !(_x isEqualType [] && {count _x==3}) then {_valid=false;} else {
 if (!([_x#0] call _class) || {!((_x#1) isEqualType [])} || {count (_x#1)>8} || {(_x#1) findIf {!([_x,-1,32] call _count)}>=0} || {!([_x#2,0,10000] call _count)}) then {_valid=false;};
};} forEach _turrets;
{if !(_x isEqualType [] && {count _x==3}) then {_valid=false;} else {
 if (!([_x#0,1,32] call _count) || {(_x#0) in _indices} || {!((_x#1) isEqualTo "" || {[_x#1] call _class})} || {!([_x#2,0,10000] call _count)}) then {_valid=false;} else {_indices pushBack (_x#0);};
};} forEach _pylons;
_valid
