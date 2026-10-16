params ["_index",["_initial",false]];
if (!isServer || {NeroOP_groundFinished} || {!(_index in [0,1])}) exitWith {grpNull};
private _cfg=missionConfigFile >> "CfgNeroOperation";
private _army=_cfg >> (["WEST","EAST"]#_index);
private _active=NeroOP_groundGroups select {(_x getVariable ["NeroOP_side",-1])==_index && {units _x findIf {alive _x}>=0}};
if (count _active>=getNumber(_army >> "active") || {(NeroOP_groundIssued#_index)>=(NeroOP_groundBudget#_index)}) exitWith {grpNull};
private _zone=getArray(_cfg >> "zone"),_base=getArray(_army >> "entry");
if (_initial && {_index!=NeroOP_groundAttacker}) then {_base=_zone;};
private _classes=getArray(_army >> "classes"),_group=createGroup [[west,east]#_index,true];
if (isNull _group) exitWith {grpNull};
for "_n" from 0 to (getNumber(_army >> "groupSize")-1) do {
 private _pos=[_base,10,120,2,0,.4,0,[],[_base,_base]] call BIS_fnc_findSafePos;
 if (!surfaceIsWater _pos && {_pos distance2D _base<150}) then {
  private _class=_classes#(_n mod count _classes);
  if (isClass(configFile >> "CfgVehicles" >> _class) && {getNumber(configFile >> "CfgVehicles" >> _class >> "side")==([1,0]#_index)} && {_class isKindOf "CAManBase"}) then {
   private _unit=_group createUnit [_class,_pos,[],0,"NONE"];
   if (!isNull _unit) then {_unit setSkill getNumber(_army >> "skill");_unit setVariable ["NeroOP_groundUnit",true,true];};
  };
 };
};
if (count units _group<2) exitWith {{deleteVehicle _x;} forEach units _group;deleteGroup _group;grpNull};
_group setVariable ["NeroOP_side",_index,true];_group setVariable ["NeroOP_groundGroup",true,true];
_group setBehaviourStrong "AWARE";_group setCombatMode "RED";_group setFormation "WEDGE";
private _wp=_group addWaypoint [_zone,if (_index==NeroOP_groundAttacker) then {40} else {getNumber(_cfg >> "zoneRadius")*.5}];
_wp setWaypointType (if (_index==NeroOP_groundAttacker) then {"SAD"} else {"HOLD"});_wp setWaypointSpeed "NORMAL";
NeroOP_groundIssued set [_index,(NeroOP_groundIssued#_index)+1];NeroOP_groundGroups pushBack _group;
diag_log format ["[NeroOP GROUND] SPAWN side=%1 issued=%2 units=%3 initial=%4",_index,NeroOP_groundIssued#_index,count units _group,_initial];
_group
