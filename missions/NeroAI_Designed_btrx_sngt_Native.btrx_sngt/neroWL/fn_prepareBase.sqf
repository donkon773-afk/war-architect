/* Evaluated after the base's typed module attributes, before native module init.
 * Move the base itself, so native respawn, airdrops and AI recruits use it too. */
private _base = _this;
if (!isServer || {isNull _base}) exitWith {};
private _side = if ((_base getVariable ["Side",-1]) == 2) then {WEST} else {EAST};
private _pos = [getPosATL _base,550,100,_base] call NeroWL_Mission_fnc_findOpenGround;
if (_pos isEqualTo []) exitWith {diag_log format ["[NeroWL Spawn] FAILED: no open base ground for %1",_side];};
_base setPosATL _pos;
missionNamespace setVariable [format ["NeroWL_spawn_%1",_side],_pos,true];
diag_log format ["[NeroWL Spawn] base %1 open ground %2; terrain clearance=100m",_side,_pos];
