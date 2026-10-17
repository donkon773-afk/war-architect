/* Role-specific tasks from shared perceived reports, with real fuel/ammunition. */
params ["_group","_town","_state","_reports","_groundReady","_base"];
_state params ["_ready","_role","_v"];
private _townPos=getPosATL _town;private _heading=_townPos getDir _base;
private _standby=_townPos getPos [3500,_heading];
private _height=if (_role=="AirBomber") then {2500} else {if (_role=="AirHeli") then {120} else {1200}};
if (serverTime<(_v getVariable ["WA_BECTI_climbUntil",0])) exitWith {
 private _point=_v getVariable ["WA_BECTI_climbPoint",(getPosATL _v) getPos [6000,getDir _v]];
 _v setVariable ["WA_BECTI_climbPoint",_point];["CLIMB",_point,"MOVE",objNull,1400]
};
if (!_ready) exitWith {
 private _landing=-1;private _airfield=+_base;
 if (_v isKindOf "Plane") then {
  private _world=configFile >> "CfgWorlds" >> worldName;
  private _airports=[[0,getArray(_world >> "ilsPosition")]];
  {_airports pushBack [_forEachIndex+1,getArray(_x >> "ilsPosition")];} forEach ("true" configClasses (_world >> "SecondaryAirports"));
  private _enemyBase=getArray(missionConfigFile >> "CfgNeroOperation" >> (if (side _group==west) then {"spawnEast"} else {"spawnWest"}));
  private _rank=[];
  {private _airportPos=_x#1;if (count _airportPos>=2 && {_airportPos distance2D _base<_airportPos distance2D _enemyBase} && {CTI_Towns findIf {_x getVariable ["cti_town_sideID",2]==(if (side _group==west) then {0} else {1}) && {_x distance2D _airportPos<2500}}<0}) then {_rank pushBack [_v distance2D _airportPos,_x#0,_airportPos];};} forEach _airports;
  _rank sort true;
  if (count _rank>0) then {_landing=(_rank#0)#1;_airfield=(_rank#0)#2;};
 };
 _v setVariable ["WA_BECTI_landingAirport",_landing];
 ["RETURN",_airfield,if (_v isKindOf "Plane" && {_landing<0}) then {"LOITER"} else {"MOVE"},objNull,_height]
};
private _aa=getArray(missionConfigFile >> "CfgWarArchitectDoctrine" >> "aaClasses");
private _danger=_reports findIf {(_x#2) in _aa && {(_x#1) distance2D _townPos<(if (_role=="AirHeli") then {4500} else {6500})}}>=0;
private _targets=if (_role=="AirIntercept") then {_reports select {(_x#2) isKindOf "Air"}} else {
 _reports select {!((_x#2) isKindOf "Air") && {(_x#1) distance2D _townPos<1600} && {_role!="AirBomber" || {(_x#2) isKindOf "Tank" || {(_x#2) isKindOf "StaticWeapon"}}}}
};
private _target=_targets param [0,[]];
if (_role=="AirIntercept") exitWith {
 if (count _target>0) then {["INTERCEPT",_target#1,"SAD",_target#0,_height]} else {["CAP",_standby,"LOITER",objNull,_height]}
};
if (_danger) exitWith {["WAIT_AA_SUPPRESSION",_standby,"LOITER",objNull,_height]};
if (count _target==0 || {_groundReady==0 && {_role!="AirBomber"}}) exitWith {["SUPPORT_STANDBY",_standby,"LOITER",objNull,_height]};
[if (_role=="AirBomber") then {"STRIKE"} else {"CAS"},_target#1,"SAD",_target#0,_height]
