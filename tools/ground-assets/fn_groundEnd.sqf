params [["_end","GroundError",[""]],["_winner",-1,[0]]];
if (!hasInterface || {isRemoteExecuted && {remoteExecutedOwner!=2}}) exitWith {};
if !(_end in ["GroundWest","GroundEast","GroundError"]) exitWith {};
[_end,([west,east] find side group player)==_winner,5] call BIS_fnc_endMission;
