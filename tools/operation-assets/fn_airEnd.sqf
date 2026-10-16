params [["_end","AirDraw",[""]],["_winner","DRAW",[""]]];
if (!hasInterface) exitWith {};
if (isRemoteExecuted && {remoteExecutedOwner!=2}) exitWith {};
if !(_end in ["AirWest","AirEast","AirDraw","AirError"]) exitWith {};
private _won=(_winner=="WEST" && {side group player==west}) || {_winner=="EAST" && {side group player==east}};
[_end,_won,5] call BIS_fnc_endMission;
