params [["_unit",objNull,[objNull]],["_group",grpNull,[grpNull]]];
if (!hasInterface || {_unit!=player} || {!local _unit} || {!alive _unit} || {isNull _group}) exitWith {};
if (isRemoteExecuted && {remoteExecutedOwner!=2}) exitWith {};
if !(_group getVariable ["NeroOP_groundGroup",false]) exitWith {};
if (side group _unit!=side _group) exitWith {};
[_unit,_group] spawn {
 params ["_unit","_group"];private _deadline=diag_tickTime+15;
 waitUntil {sleep .1;isNull _group || {!alive _unit} || {diag_tickTime>_deadline} || {local _group && {(_group getVariable ["NeroOP_slotCommander",objNull])==_unit}}};
 if (isNull _group || {!local _group} || {!alive _unit} || {_unit!=player} || {(_group getVariable ["NeroOP_slotCommander",objNull])!=_unit}) exitWith {};
 private _leader=leader _group;if (isNull _leader || {!alive _leader}) exitWith {};
 _unit setPosATL (getPosATL _leader);[_unit] joinSilent _group;_group selectLeader _unit;
 _unit setCaptive false;_unit setVariable ["NeroOP_notice","Вы командуете отрядом. Используйте штатные команды Arma."];
 diag_log format ["[NeroOP GROUND] COMMANDER READY group=%1 units=%2",groupId _group,count units _group];
};
