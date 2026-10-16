params ["_winner","_reason"];
if (!isServer || {missionNamespace getVariable ["NeroOP_finished",false]}) exitWith {};
NeroOP_finished=true;
NeroOP_state=["finished",NeroOP_account#0,[0,0],[0,0],0,_winner,_reason];publicVariable "NeroOP_state";
diag_log format ["[NeroOP AIR] FINISH winner=%1 reason=%2 stats=%3",_winner,_reason,NeroOP_account#0];
private _end=switch _winner do {case "WEST":{"AirWest"};case "EAST":{"AirEast"};case "ERROR":{"AirError"};default {"AirDraw"};};
[_end,_winner] remoteExec ["NeroOP_fnc_airEnd",0];
