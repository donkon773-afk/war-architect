/* Pure ballistic intercept time, bounded; no steering of the shell. */
params ["_origin","_velocity","_target","_targetVelocity"];
private _r=_target vectorDiff _origin;private _speed=vectorMagnitude _velocity;
if (_speed<100) exitWith {-1};
// Use the fired shell's actual axis, not an imaginary redirected intercept.
private _relative=_targetVelocity vectorDiff _velocity;
private _square=_relative vectorDotProduct _relative;
if (_square<1) exitWith {-1};
private _time=-(_r vectorDotProduct _relative)/_square;
private _miss=vectorMagnitude (_r vectorAdd (_relative vectorMultiply _time));
if (_miss>30) exitWith {-1};
if (_time<.12 || {_time>8}) exitWith {-1};
(_time-12/_speed) max .1
