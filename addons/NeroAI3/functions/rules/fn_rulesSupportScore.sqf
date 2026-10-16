/* PURE: lower score wins, -1 means unsuitable. Protected groups stay on duty.
 * AT teams may be small, but must carry ammunition for the requested threat. */
params [["_distance",0],["_effective",0],["_crewReady",false],["_lightAT",0],["_heavyAT",0],["_protected",false],["_need","SUPPORT"],["_engineers",0]];
if (_protected || {_distance > 4000} || {_distance < 0}) exitWith {-1};
if (_need isEqualTo "REPAIR" && {_engineers <= 0}) exitWith {-1};
private _typed = _need in ["HEAVY_AT","LIGHT_AT"];
if (_need isEqualTo "HEAVY_AT" && {_heavyAT <= 0}) exitWith {-1};
if (_need isEqualTo "LIGHT_AT" && {_lightAT <= 0}) exitWith {-1};
if (!_crewReady && {_effective < (if (_need isEqualTo "REPAIR") then {1} else {if (_typed) then {2} else {4}})}) exitWith {-1};
/* Keep valid scores nonnegative, so rejection is unambiguous. */
(_distance + 300) - ((_effective min 20) * 5) - (if (_crewReady) then {120} else {0})
