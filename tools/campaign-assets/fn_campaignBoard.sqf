params [["_unit",objNull,[objNull]],["_group",grpNull,[grpNull]]];
if (!hasInterface || {_unit!=player} || {!local _unit} || {!alive _unit} || {isNull _group} || {isRemoteExecuted && {remoteExecutedOwner!=2}}) exitWith {};
if (!(_group getVariable ["NeroOP_campGroup",false]) || {side group _unit!=side _group}) exitWith {};
[_unit,_group] spawn {params ["_unit","_group"];private _deadline=diag_tickTime+15;
 waitUntil {sleep .1;isNull _group || {!alive _unit} || {diag_tickTime>_deadline} || {local _group && {(_group getVariable ["NeroOP_slotCommander",objNull])==_unit}}};
 if (isNull _group || {!local _group} || {!alive _unit} || {_unit!=player} || {(_group getVariable ["NeroOP_slotCommander",objNull])!=_unit}) exitWith {};
 private _leader=leader _group;if (isNull _leader || {!alive _leader}) exitWith {};_unit setPosATL getPosATL _leader;[_unit] joinSilent _group;_group selectLeader _unit;_unit setCaptive false;
 _unit setVariable ["NeroOP_notice","Вы командуете отрядом. На карте отмечены фронт и склады."];diag_log format ["[NeroOP CAMPAIGN] COMMANDER READY units=%1",count units _group];
};
