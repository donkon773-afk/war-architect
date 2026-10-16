/* PURE terrain/fire-position utility. A blocked shot or unsafe slope cannot
 * be compensated by a large cover bonus. Known threats only. */
params ["_travel","_slope",["_visible",false],["_hullCover",false],["_clear",true],["_water",false],["_canAim",true],["_knownNear",1e9],["_escape",true],["_preferredRange",400],["_range",400]];
if (!_clear || {_water} || {_slope < 0.92} || {!_canAim} || {!_visible} || {_knownNear < 100}) exitWith {-1e9};
400 - _travel*0.2 - abs (_range-_preferredRange)*0.25 + (if (_hullCover) then {180} else {0}) + (if (_escape) then {70} else {-150}) - (1-_slope)*1000
