params ["_unit","_group","_logic"];
if (!hasInterface || {isRemoteExecuted && {remoteExecutedOwner!=2}} || {_unit!=player} || {isNull _group} || {side _group!=side group player} || {_group getVariable ["NeroOP_hcUID",""]!=getPlayerUID player} || {isNull _logic}) exitWith {};
[_unit,_group,_logic] spawn {params ["_unit","_group","_logic"];private _deadline=diag_tickTime+15;waitUntil {sleep .1;local _group || {diag_tickTime>_deadline}};if (!local _group || {_unit!=player}) exitWith {};
 player setVariable ["BIS_HC_scope",_logic,true];player hcSetGroup [_group,"Подкрепление "+str (_group getVariable ["NeroOP_groupKey",0]),"teamgreen"];
 /* Native HighCommand starts BIS_fnc_HC_Local once for all clients, including JIP,
    and restarts it after respawn. Starting it again here duplicates its GUI handlers. */
 systemChat "Подкрепление — самостоятельный отряд. Ctrl+Пробел: High Command; приказы задаются на карте.";
};
