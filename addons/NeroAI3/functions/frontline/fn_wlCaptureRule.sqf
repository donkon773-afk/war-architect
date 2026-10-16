/* PURE: a historical conquest cannot bypass a broken connection. */
params ["_target","_current","_history","_available"];
_target in _available && {_target isEqualTo _current || {_target in _history}}
