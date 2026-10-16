/* Pure geometric join: touching endpoints at the same height only. */
params ["_a","_b"];
private _near={params ["_x","_y"];_x distance2D _y<18 && {abs ((_x param [2,0])-(_y param [2,0]))<4}};
count _a>=2 && {count _b>=2} && {[_a#0,_b#0] call _near || {[_a#0,_b#1] call _near} || {[_a#1,_b#0] call _near} || {[_a#1,_b#1] call _near}}
