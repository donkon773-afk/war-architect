params ["_velocity","_previous","_dt","_up",["_coef",1]];
if (_dt<=0) exitWith {1};
private _acceleration=((_velocity vectorDiff _previous) vectorMultiply (1/_dt)) vectorAdd [0,0,9.8];
((((_acceleration vectorDotProduct _up)/9.8) max -10) min 10)*_coef
