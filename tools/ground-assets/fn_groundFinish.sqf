params ["_winner",["_reason",""]];
if (!isServer || {NeroOP_groundFinished}) exitWith {};
NeroOP_groundFinished=true;
private _end=if (_winner<0) then {"GroundError"} else {["GroundWest","GroundEast"]#_winner};
[_end,_winner] remoteExecCall ["NeroOP_fnc_groundEnd",0];
diag_log format ["[NeroOP GROUND] FINISH winner=%1 reason=%2 issued=%3",_winner,_reason,NeroOP_groundIssued];
