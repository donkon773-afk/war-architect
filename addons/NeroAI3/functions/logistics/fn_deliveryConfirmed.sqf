/* PURE: a nonempty but partial native return is not a complete delivery. */
params ["_expected","_returned","_livingObjects"];
_expected > 0 && {_returned == _expected} && {_livingObjects == _expected}
