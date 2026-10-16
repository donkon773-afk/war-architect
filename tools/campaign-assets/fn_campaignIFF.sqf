/* Explicit launch allegiance takes priority over engine UAV/proxy allegiance. */
params ["_observer","_target"];
if (!(_observer in [0,1]) || {isNull _target}) exitWith {false};
private _side=_target getVariable ["NeroOP_side",-1];
if !(_side in [0,1]) then {private _source=_target getVariable ["NeroOP_source",objNull];if (!isNull _source) then {_side=_source getVariable ["NeroOP_side",-1];};};
if (_side in [0,1]) exitWith {_observer!=_side};
private _unit=if (_target isKindOf "Man") then {_target} else {effectiveCommander _target};
!isNull _unit && {([west,east]#_observer) getFriend side group _unit<.6}
