params ["_winner",["_reason",""]];if (!isServer || {NeroOP_campFinished}) exitWith {};if (!canSuspend) exitWith {_this spawn NeroOP_fnc_campaignFinish;};NeroOP_campFinished=true;
// Finish makes delivery workers settle their paid payload and clean up their aircraft.
// Save only after those transactions have drained, otherwise the previous checkpoint would be silently reused.
private _deadline=diag_tickTime+65;waitUntil {sleep .1;(!NeroOP_campSaving && {count (missionNamespace getVariable ["NeroOP_deliveryFlights",[]])==0}) || {diag_tickTime>_deadline}};
if (_winner>=0) then {NeroOP_campWinner=_winner;};private _saved=[] call NeroOP_fnc_campaignSave;
private _end=if (_winner==-2) then {"CampaignPause"} else {if (_winner<0) then {"CampaignError"} else {["CampaignWest","CampaignEast","CampaignDraw"]#_winner}};
[_end,_winner] remoteExecCall ["NeroOP_fnc_campaignEnd",0];diag_log format ["[NeroOP CAMPAIGN] FINISH winner=%1 reason=%2 saved=%3",_winner,_reason,_saved];
