params ["_range",["_tracked",false]];
if !(_range isEqualType 0 && {_tracked isEqualType true}) exitWith {0};
((.02+.23*((_range max 0) min 15000)/15000)*(if (_tracked) then {.5} else {1})) min .25
