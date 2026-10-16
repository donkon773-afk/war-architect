/* Pure short-map surrogate. Public sources do not provide a measured Kinzhal flight curve.
   Returns speed and excess altitude. 2800 m/s is a configurable peak estimate, not Mach 10 at all altitudes.
   Short range limits attained speed; terminal drag reduces the achieved peak instead of adding a second boost. */
params ["_age","_progress","_range","_launchSpeed","_peak","_boost"];
private _u=(_progress max 0) min 1;
private _start=(_launchSpeed max 45) min _peak;
private _energy=(_range/100000) min 1;
private _attainable=(_start+(_peak-_start)*sqrt (_energy max 0)) min _peak;
private _speed=_start+(_attainable-_start)*((_age/(_boost max 1)) max 0 min 1);
if (_u>.65) then {_speed=_speed*(1-.25*((_u-.65)/.35));};
private _apex=(40000 min (_range*.30)) max 0;
[_speed,4*_apex*_u*(1-_u)]
