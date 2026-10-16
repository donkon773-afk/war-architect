/* PURE: queued approval is not payment or successful delivery. */
params ["_now","_deadline","_sameOrder","_valid","_manual","_playerOrder","_busy","_nextSide","_started"];
if (_started) exitWith {"UNCERTAIN"};
if (!_valid || {!_sameOrder}) exitWith {"CANCEL"};
if (_now >= _deadline) exitWith {"EXPIRE"};
if (_busy || {_now < _nextSide} || {_manual && {!_playerOrder}}) exitWith {"WAIT"};
"DISPATCH"
