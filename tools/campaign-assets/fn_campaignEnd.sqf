params [["_end","CampaignError",[""]],["_winner",-1,[0]]];
if (!hasInterface || {isRemoteExecuted && {remoteExecutedOwner!=2}} || {!(_end in ["CampaignWest","CampaignEast","CampaignDraw","CampaignPause","CampaignError"])}) exitWith {};
[_end,([west,east] find side group player)==_winner,5] call BIS_fnc_endMission;
