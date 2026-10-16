/* Pure time profile, speeds in m/s. Terminal phase is latched by the caller. */
params ["_age","_terminalAge",["_terminalStart",277.777778]];
if (_terminalAge>=0) exitWith {_terminalStart+(500-_terminalStart)*((_terminalAge/2) max 0 min 1)};
45+(277.777778-45)*((_age/7) max 0 min 1)
