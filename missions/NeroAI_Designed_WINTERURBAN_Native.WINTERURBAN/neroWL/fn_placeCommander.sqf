/* Initial placement and respawn only. No periodic rescue/teleport of units in battle. */
private _unit = _this;
if (!local _unit || {isNull _unit}) exitWith {};
private _center = missionNamespace getVariable [format ["NeroWL_spawn_%1",side group _unit],getPosATL _unit];
private _pos = [_center,70,20,_unit] call NeroWL_Mission_fnc_findOpenGround;
// Dense urban maps can leave no valid placement inside the initial 70 m.
// Search farther with a smaller clearance before leaving a commander at origin.
if (_pos isEqualTo []) then {_pos = [_center,450,5,_unit] call NeroWL_Mission_fnc_findOpenGround;};
if !(_pos isEqualTo []) then {_unit setPosATL _pos;} else {diag_log format ["[NeroWL Spawn] FAILED commander placement: %1",typeOf _unit];};
