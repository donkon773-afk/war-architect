/* Called atomically by the server. Only this campaign's new groups are modified. */
params ["_index",["_target",-1],["_classes",[]],["_position",[]],["_restore",false],["_savedGuard",false,[true]],["_savedKey",-1],["_hcUID",""],["_localSource",-1]];
if (!isServer || {NeroOP_campFinished} || {!(_index in [0,1])}) exitWith {grpNull};
private _cfg=missionConfigFile >> "CfgNeroOperation";private _army=_cfg >> (["WEST","EAST"]#_index);
private _active=NeroOP_campGroups select {(_x getVariable ["NeroOP_side",-1])==_index && {units _x findIf {alive _x}>=0} && {((_x getVariable ["NeroOP_hcUID",""])!="")==(_hcUID!="")}};
if (count _active>=(if (_hcUID=="") then {getNumber(_army >> "active")} else {getNumber(_cfg >> "Gameplay" >> "supportGroups")}) || {!_restore && {(NeroOP_campIssued#_index)>=(NeroOP_campBudget#_index)}}) exitWith {grpNull};
private _source=-1;private _cost=getNumber(_cfg >> "reinforcementCost");
if (!_restore) then {
 private _graph=[NeroOP_campOwners,NeroOP_campLinks,NeroOP_campRoots#_index,_index] call NeroOP_fnc_campaignGraph;
 private _rank=(_graph#0) select {(NeroOP_campStocks#_x)>=_cost && {_localSource<0 || {_x==_localSource}}};
 _rank=_rank apply {[-((NeroOP_campPositions#_x) distance2D (NeroOP_campPositions#(NeroOP_campRoots#_index))),_x]};_rank sort true;
 if (count _rank>0) then {_source=(_rank#0)#1;_target=_source;_position=NeroOP_campPositions#_source;_classes=[];for "_n" from 0 to getNumber(_army >> "groupSize")-1 do {_classes pushBack ((getArray(_army >> "classes"))#(_n mod count getArray(_army >> "classes")));};};
};
if ((!_restore && {_source<0}) || {count _position!=2} || {surfaceIsWater _position}) exitWith {grpNull};
private _plan=if (!_restore && {missionNamespace getVariable ["NeroOP_campReady",false]}) then {[_index,_source,count _classes] call NeroOP_fnc_campaignDropPlan} else {[objNull,objNull,_source]};
if (count _plan==0) exitWith {grpNull};
if (!isNull (_plan#0)) then {_position=NeroOP_campPositions#(NeroOP_campRoots#_index);};
private _group=createGroup [[west,east]#_index,true];if (isNull _group) exitWith {[_plan] call NeroOP_fnc_campaignDeliveryAbort;grpNull};
{private _pos=[_position,5,100,2,0,.4,0,[],[_position,_position]] call BIS_fnc_findSafePos;
 if (!surfaceIsWater _pos && {_pos distance2D _position<130} && {getNumber(configFile >> "CfgVehicles" >> _x >> "side")==([1,0]#_index)} && {_x isKindOf "CAManBase"}) then {
  private _unit=_group createUnit [_x,_pos,[],0,"NONE"];if (!isNull _unit) then {_unit setSkill getNumber(_army >> "skill");{_unit setSkill [_x,getNumber(_cfg >> "Gameplay" >> _x)];} forEach ["spotDistance","spotTime","courage","commanding","reloadSpeed"];_unit setVariable ["NeroOP_campUnit",true,true];};
 };
} forEach _classes;
if (!isNull (_plan#0)) then {{_x moveInCargo (_plan#0);} forEach units _group;};
private _ok=(isNull (_plan#0) || {units _group findIf {vehicle _x!=(_plan#0)}<0}) && {count units _group>=(if (_restore) then {1} else {2})};
if (_ok && {!_restore}) then {
 NeroOP_campSeq=NeroOP_campSeq+1;private _ledger=[NeroOP_campStocks,NeroOP_campLedger,"spend","group:"+str NeroOP_campSeq,_source,-1,_cost] call NeroOP_fnc_campaignStock;
 _ok=_ledger#2;if (_ok) then {NeroOP_campStocks=_ledger#0;NeroOP_campLedger=_ledger#1;NeroOP_campIssued set [_index,(NeroOP_campIssued#_index)+1];};
};
if (!_ok) exitWith {{deleteVehicle _x;} forEach units _group;deleteGroup _group;[_plan] call NeroOP_fnc_campaignDeliveryAbort;grpNull};
_group setVariable ["NeroOP_hcUID",_hcUID,true];_group setVariable ["NeroOP_side",_index,true];_group setVariable ["NeroOP_campGroup",true,true];_group setVariable ["NeroOP_campTarget",_target];
_group setVariable ["NeroOP_campGuard",if (_restore) then {_savedGuard} else {((NeroOP_campIssued#_index) mod 3)==0}];
if (_savedKey>0) then {NeroOP_campGroupSeq=NeroOP_campGroupSeq max _savedKey;} else {NeroOP_campGroupSeq=NeroOP_campGroupSeq+1;_savedKey=NeroOP_campGroupSeq;};_group setVariable ["NeroOP_groupKey",_savedKey,true];
_group setVariable ["NeroOP_stagingAt",serverTime];_group setBehaviourStrong "AWARE";_group setCombatMode "RED";_group setFormation "WEDGE";NeroOP_campGroups pushBack _group;
if (!isNull (_plan#0)) then {_group setVariable ["NeroOP_dropBusy",true,true];[_plan,+units _group,_group,true,if (_hcUID=="") then {objNull} else {(allPlayers select {getPlayerUID _x==_hcUID}) param [0,objNull]}] spawn NeroOP_fnc_campaignDropFlight;} else {[_group,true] call NeroOP_fnc_campaignOrder;};
diag_log format ["[NeroOP CAMPAIGN] GROUP side=%1 units=%2 issued=%3 restored=%4 source=%5",_index,count units _group,NeroOP_campIssued#_index,_restore,_source];_group
