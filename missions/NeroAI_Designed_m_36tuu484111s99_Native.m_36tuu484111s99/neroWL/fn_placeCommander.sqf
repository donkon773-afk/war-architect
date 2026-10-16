/* Initial placement and respawn only. No periodic rescue/teleport of units in battle. */
private _unit = _this;
if (!local _unit || {isNull _unit}) exitWith {};
private _center = missionNamespace getVariable [format ["NeroWL_spawn_%1",side group _unit],getPosATL _unit];
private _pos = [_center,70,20,_unit] call NeroWL_Mission_fnc_findOpenGround;
if !(_pos isEqualTo []) then {_unit setPosATL _pos;} else {diag_log format ["[NeroWL Spawn] FAILED commander placement: %1",typeOf _unit];};
