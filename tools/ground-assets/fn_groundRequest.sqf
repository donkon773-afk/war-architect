params [["_unit",objNull,[objNull]]];
if (!isServer || {isNull _unit} || {!alive _unit} || {!(isPlayer _unit || {_unit getVariable ["NeroOP_lobbySlot",false]})} || {!(missionNamespace getVariable ["NeroOP_groundReady",false])} || {NeroOP_groundFinished}) exitWith {};
if (isRemoteExecuted && {!isPlayer _unit || {remoteExecutedOwner!=owner _unit}}) exitWith {};
private _index=[west,east] find side group _unit;if (_index<0) exitWith {};
if (group _unit getVariable ["NeroOP_groundGroup",false]) exitWith {};
private _pending=_unit getVariable ["NeroOP_pendingGroup",grpNull];
if (!isNull _pending && {serverTime-(_pending getVariable ["NeroOP_claimedAt",-100])<20}) exitWith {};
if (serverTime-(_unit getVariable ["NeroOP_groundRequestAt",-100])<3) exitWith {};
_unit setVariable ["NeroOP_groundRequestAt",serverTime];
private _group=grpNull;
isNil {
 private _available=NeroOP_groundGroups select {(_x getVariable ["NeroOP_side",-1])==_index && {units _x findIf {alive _x}>=0} && {units _x findIf {alive _x && {isPlayer _x}}<0} && {!alive (_x getVariable ["NeroOP_slotCommander",objNull])} && {!(_x getVariable ["NeroOP_claimed",false])}};
 if (count _available>0) then {_group=_available#0;} else {_group=[_index] call NeroOP_fnc_groundSpawn;};
 if (!isNull _group) then {_group setVariable ["NeroOP_claimed",true];_group setVariable ["NeroOP_claimedAt",serverTime];};
};
if (isNull _group) exitWith {_unit setVariable ["NeroOP_notice","Нет свободного отряда. Дождитесь подкреплений или окончания операции.",true];};
_group setVariable ["NeroOP_slotCommander",_unit,true];
if (!isPlayer _unit) exitWith {
 if (local _unit && {local _group}) then {_unit setPosATL getPosATL leader _group;[_unit] joinSilent _group;_group selectLeader _unit;diag_log format ["[NeroOP GROUND] LOBBY BOT READY group=%1 units=%2",groupId _group,count units _group];} else {_group setVariable ["NeroOP_claimed",false];_group setVariable ["NeroOP_slotCommander",objNull,true];};
};
if (groupOwner _group!=owner _unit && {!(_group setGroupOwner owner _unit)}) exitWith {_group setVariable ["NeroOP_claimed",false];_group setVariable ["NeroOP_slotCommander",objNull,true];_unit setVariable ["NeroOP_notice","Передача отряда пока недоступна. Повторите запрос.",true];};
_unit setVariable ["NeroOP_pendingGroup",_group];
[_unit,_group] remoteExecCall ["NeroOP_fnc_groundBoard",owner _unit];
diag_log format ["[NeroOP GROUND] COMMANDER REQUEST owner=%1 side=%2",owner _unit,_index];
