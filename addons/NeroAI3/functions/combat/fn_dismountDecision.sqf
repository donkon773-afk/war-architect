/* PURE: cargo leaves for the urban final leg, never the gun crew. */
params ["_cargo","_crewOnly","_manual","_urban","_distance","_knownNear","_sinceHit","_speed"];
if (_manual || {_crewOnly} || {_cargo <= 0}) exitWith {"KEEP"};
if (!(_urban && {_distance >= 0} && {_distance <= 450}) && {_knownNear >= 300}) exitWith {"RIDE"};
if (_knownNear < 100 || {_sinceHit < 10}) exitWith {"WAIT_COVER"};
if (abs _speed >= 3) exitWith {"STOP"};
"DISEMBARK"
