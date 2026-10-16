/* PURE. Distance must improve toward the current road leg. Rocking/rotation
 * cannot renew the progress clock. Queue and deliberate hold are not stalls. */
params ["_remaining","_best","_lastProgress","_now",["_expected",true],["_mobile",true],["_queued",false],["_speed",0],["_timeout",8]];
if (!_expected) exitWith {["HOLD",_remaining,_now]};
if (!_mobile) exitWith {["DAMAGED",_best,_lastProgress]};
if (_queued) exitWith {["QUEUE",_best,_now]};
if (_remaining < _best - 2.5) then {_best = _remaining;_lastProgress = _now;};
private _state = if (_now - _lastProgress >= (_timeout max 4) && {abs _speed < 4}) then {"STALLED"} else {"MOVING"};
[_state,_best,_lastProgress]
