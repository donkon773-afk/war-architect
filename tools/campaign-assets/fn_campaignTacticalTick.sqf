/* Campaign adapter: supply graph and existing command authority remain authoritative. */
if (!isServer || {getNumber(missionConfigFile >> "CfgNeroOperation" >> "DevMode" >> "coordinatedAI")!=1}) exitWith {};
for "_side" from 0 to 1 do {
 private _root=NeroOP_campRoots#_side;private _base=NeroOP_campPositions#_root;private _contacts=NeroOP_campIntel#_side;
 private _groups=NeroOP_campGroups select {local _x && {(_x getVariable ["NeroOP_side",-1])==_side} && {alive leader _x} && {!([_x] call NeroOP_fnc_campaignPlayerControl)} && {!(_x getVariable ["NeroOP_dropBusy",false])}};
 private _baseThreat=_contacts findIf {!(_x#2) && {alive (_x#0)} && {(_x#1) distance2D _base<1200}}>=0;
 private _plan=[count _groups,_baseThreat,0,0,true] call NeroOP_fnc_campaignTeamPlan;private _rank=[];{_rank pushBack [leader _x distance2D _base,_forEachIndex];} forEach _groups;_rank sort true;
 private _defenders=(_rank select [0,_plan#0]) apply {_groups#(_x#1)};
 {private _g=_x;_g setVariable ["NeroOP_baseDefense",_g in _defenders];private _target=_g getVariable ["NeroOP_campTarget",_root];if (_target<0 || {_target>=count NeroOP_campPositions}) then {_target=_root;};
  if (_g in _defenders) then {_target=_root;};
  private _pos=NeroOP_campPositions#(_target max 0);private _near=_groups select {leader _x distance2D _pos<1800};private _friends=0;{_friends=_friends+({alive _x} count units _x);} forEach _near;
  private _enemies=0;{if (alive (_x#0) && {!(_x#2)} && {(_x#1) distance2D _pos<900}) then {_enemies=_enemies+(if ((_x#0) isKindOf "Tank") then {8} else {if ((_x#0) isKindOf "LandVehicle") then {3} else {1}});};} forEach _contacts;{private _v=_x#4;if ((_x#1)==_side && {alive _v} && {_v distance2D _pos<1800}) then {_friends=_friends+(if (_v isKindOf "Tank") then {8} else {3});};} forEach NeroOP_campEquipment;
  private _ready=leader _g distance2D _pos<1800 || {_enemies==0};private _allocation=[count _groups,_baseThreat,_friends,_enemies,_ready] call NeroOP_fnc_campaignTeamPlan;
  private _hold=(NeroOP_campOwners#(_target max 0))!=_side && {!(_allocation#2)};
  private _old=_g getVariable ["NeroOP_attackHold",false];_g setVariable ["NeroOP_attackHold",_hold];
  if (_hold) then {private _stage=_pos getPos [NeroOP_campRadii#_target+500,_pos getDir _base];if (leader _g distance2D _stage<180) then {_g setSpeedMode "LIMITED";};};
  if (!(_old isEqualTo _hold) || {_g in _defenders && {(_g getVariable ["NeroOP_campTarget",-1])!=_root}}) then {[_g,true] call NeroOP_fnc_campaignOrder;};
 } forEach _groups;
};
{_x params ["_id","_side","_class","_kind","_v","_parent","_crew"];
 if (_kind==0 && {alive _v} && {!isNull _crew} && {local _crew} && {!([_crew] call NeroOP_fnc_campaignPlayerControl)} && {damage _v>.35 || {!canMove _v}} && {serverTime>(_v getVariable ["NeroOP_repairAt",0])}) then {
  private _near=(NeroOP_campIntel#_side) select {!(_x#2) && {alive (_x#0)} && {(_x#1) distance2D _v<650}};
  private _cover=NeroOP_campGroups select {local _x && {(_x getVariable ["NeroOP_side",-1])==_side} && {!([_x] call NeroOP_fnc_campaignPlayerControl)} && {leader _x distance2D _v<1000}};
  if (count _near>0) then {private _g=_cover param [0,grpNull];if (!isNull _g) then {private _target=(_near#0)#0;{if (local _x && {alive _x}) then {_x reveal [_target,3];_x doTarget _target;};} forEach units _g;};} else {
   private _engineers=units _crew select {alive _x && {local _x} && {[_x getUnitTrait "engineer",_x getVariable ["ACE_IsEngineer",false]] call NeroOP_fnc_campaignEngineerGate} && {"ToolKit" in items _x || {"ToolKit" in itemCargo _v}} && {!(_x getVariable ["ACE_isUnconscious",false])}};
   if (count _engineers>0) then {_v setVariable ["NeroOP_repairAt",serverTime+30];private _engineer=_engineers#0;[_v,_engineer,_crew,_side] spawn NeroOP_fnc_campaignFieldRepair;};
  };
 };
} forEach NeroOP_campEquipment;
