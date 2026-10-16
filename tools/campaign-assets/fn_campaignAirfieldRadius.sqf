/* Pure calculation for native ILS/taxi coordinates; no engine command precedence. */
params ["_position","_paths"];
private _radius=750;
if (count _position<2) exitWith {_radius};
{private _taxi=_x;for "_i" from 0 to (count _taxi)-2 step 2 do {
 private _dx=(_taxi#_i)-(_position#0);private _dy=(_taxi#(_i+1))-(_position#1);
 _radius=_radius max (sqrt(_dx*_dx+_dy*_dy)+150);
};} forEach _paths;
_radius min 5000
