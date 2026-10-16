/* PURE: don't confuse a captured objective with an invalidated objective. */
params ["_target","_owner","_side","_available",["_ready",true]];
if (!_ready || {_target isEqualTo ""}) exitWith {"WAIT"};
if (_owner isEqualTo _side) exitWith {"CAPTURED"};
if (_target in _available) then {"KEEP"} else {"RESET"}
