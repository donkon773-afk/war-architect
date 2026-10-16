/* PURE distance from a 2D point to a finite segment, used for people/traffic. */
params ["_p","_a","_b"];
private _dx = (_b # 0)-(_a # 0);private _dy = (_b # 1)-(_a # 1);
private _length2 = _dx*_dx+_dy*_dy;
private _t = if (_length2 < 0.01) then {0} else {((((_p # 0)-(_a # 0))*_dx+((_p # 1)-(_a # 1))*_dy)/_length2) max 0 min 1};
sqrt (((_p # 0)-(_a # 0)-_t*_dx)^2+((_p # 1)-(_a # 1)-_t*_dy)^2)
