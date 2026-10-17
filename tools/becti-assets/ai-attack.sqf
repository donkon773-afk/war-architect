/* Own only automatic town orders. Explicit player orders retain native handling.
   One seed owns one waypoint; cancellation removes that waypoint only. */
params ["_group","_town","_seed","_side","_reload","_order"];
if (!isServer || {isRemoteExecuted} || {!local _group} || {isNull _town} || {[_group] call NeroOP_fnc_campaignPlayerControl}) exitWith {};
if (_group getVariable ["WA_BECTI_directorSeed",-1]==_seed) exitWith {};
_group setVariable ["WA_BECTI_directorSeed",_seed];
private _token="WA_BECTI_"+str _seed;
private _valid={!(missionNamespace getVariable ["CTI_GameOver",false]) && {local _group} && {alive leader _group} && {!([_group] call NeroOP_fnc_campaignPlayerControl)} && {_group getVariable ["cti_order_seed",-1]==_seed} && {_group getVariable ["cti_order",-1] in [CTI_ORDER_TAKETOWN_AUTO,CTI_ORDER_TAKEHOLDTOWN_AUTO]} && {(_group getVariable ["cti_order_pos",objNull]) isEqualTo _town}};
private _base=getArray(missionConfigFile >> "CfgNeroOperation" >> (if (_side==west) then {"spawnWest"} else {"spawnEast"}));
private _id=_side call CTI_CO_FNC_GetSideID;
private _heading=(getPosATL _town) getDir _base;
private _raw=(getPosATL _town) getPos [650,_heading];
private _stage=[_raw,0,70,8,0,.35,0,[],[_raw,_raw]] call BIS_fnc_findSafePos;
if (surfaceIsWater _stage) then {_stage=(getPosATL _town) getPos [300,_heading];};
private _lastPhase="";private _lastPoint=[-10000,-10000];private _lastType="";private _wp=[];
private _road=[];private _roadIndex=0;private _roadTarget=[];private _roadRetry=0;
private _finished=false;private _retarget=false;
while {call _valid} do {
 if (_town getVariable ["cti_town_sideID",-1]==_id) exitWith {_finished=true;};
 if (missionNamespace getVariable ["CTI_SM_STRATEGIC",0]==1) then {
  private _logic=_side call CTI_CO_FNC_GetSideLogic;
  if (!(_town in ((_logic getVariable ["CTI_ACTIVE",[]])+(_logic getVariable ["CTI_AVAILLABLE",[]])))) then {_retarget=true;};
 };
 if (_retarget) exitWith {};
 private _state=[_group] call NeroOP_fnc_bectiAIState;
 _state params ["_ready","_role","_v","_live","_reason","_power"];
 private _reports=[_group] call NeroOP_fnc_bectiAIContacts;
 private _threat=0;
 {if ((_x#1) distance2D _town<1100) then {_threat=_threat+(if ((_x#2) isKindOf "Tank") then {8} else {if ((_x#2) isKindOf "Car") then {3} else {1}});};} forEach _reports;
 private _infantry=0;private _armor=0;private _groundReady=0;private _infantryGroup=grpNull;
 {
  if (_x!=_group && {(_x getVariable ["cti_order_pos",objNull]) isEqualTo _town} && {!([_x] call NeroOP_fnc_campaignPlayerControl)}) then {
   private _mate=[_x] call NeroOP_fnc_bectiAIState;
   if (_mate#0) then {
    if ((_mate#1) in ["Infantry","InfantryAT","InfantryAA","Mechanized"] && {leader _x distance2D leader _group<1400}) then {_infantry=_infantry+1;_infantryGroup=_x;};
    if ((_mate#1) in ["Armored","Mechanized"] && {leader _x distance2D leader _group<1400}) then {_armor=_armor+1;};
    if (_x getVariable ["WA_BECTI_phase",""] in ["ADVANCE","ASSAULT","COVER"]) then {_groundReady=_groundReady+1;};
   };
  };
 } forEach (_side call CTI_CO_FNC_GetSideGroups);
 if (isNil {_group getVariable "WA_BECTI_stageTown"} || {!((_group getVariable "WA_BECTI_stageTown") isEqualTo _town)}) then {_group setVariable ["WA_BECTI_stageTown",_town];_group setVariable ["WA_BECTI_stageAt",-1];};
 if (_ready && {leader _group distance2D _stage<180} && {_group getVariable ["WA_BECTI_stageAt",-1]<0}) then {_group setVariable ["WA_BECTI_stageAt",serverTime];};
 private _waited=if (_group getVariable ["WA_BECTI_stageAt",-1]<0) then {0} else {serverTime-(_group getVariable "WA_BECTI_stageAt")};
 private _phase=[_ready,_role,_reason,_power,_threat,_infantry,_armor,leader _group distance2D _stage,_waited,leader _group distance2D _town] call NeroOP_fnc_bectiAIPolicy;
 private _point=+_stage;private _type="MOVE";private _target=objNull;private _height=1200;
 private _air=!isNull _v && {_v isKindOf "Air"};
 if (_phase=="PREPARE") then {
  private _template=missionNamespace getVariable [format ["CTI_SQUAD_%1_%2",_side,_role],[]];
  if (count _template>3) then {
   private _structures=_side call CTI_CO_FNC_GetSideStructures;
   private _factory=[_template#3,leader _group,_structures] call CTI_CO_FNC_GetClosestStructure;
   _point=if (alive _factory) then {getPosATL _factory} else {+_base};
   if (serverTime>(_group getVariable ["WA_BECTI_requestAt",0]) && {alive _factory} && {_group getVariable ["cti_independent",false]}) then {_group setVariable ["WA_BECTI_requestAt",serverTime+30];[_group,_side,_template#2,_factory] call NeroOP_fnc_bectiAIRequest;};
   if (!isNull _v && {_reason=="BOARDING"}) then {
    private _foot=units _group select {alive _x && {local _x} && {vehicle _x==_x}};
    {if (_v emptyPositions "cargo">0) then {_x assignAsCargo _v;[_x] orderGetIn true;};} forEach _foot;
    _point=getPosATL _v;
   };
  };
  if (_live<3 && {leader _group distance2D _base>800} && {_threat>0}) then {_phase="WITHDRAW";};
 };
 if (_phase in ["ADVANCE","ASSAULT"]) then {
  private _offset=if (_role=="Armored") then {550} else {if (_role=="Motorized") then {400} else {0}};
  _point=(getPosATL _town) getPos [_offset,_heading];
  if (_role=="Mechanized" && {leader _group distance2D _town<700} && {!isNull _v}) then {
   {private _u=_x#0;if (_u in units _group && {local _u}) then {unassignVehicle _u;[_u] orderGetIn false;};} forEach fullCrew [_v,"cargo",false];
   _group setVariable ["WA_BECTI_dismountedFor",_town];
   _point=(getPosATL _town) getPos [350,_heading];
   {if (vehicle _x==_x && {local _x}) then {_x doMove getPosATL _town;};} forEach units _group;
  };
 };
 if (_phase=="COVER") then {_point=if (!isNull _infantryGroup) then {(getPosATL leader _infantryGroup) getPos [350,_heading]} else {+_stage};};
 if (!isNull _v && {getNumber(configFile >> "CfgVehicles" >> typeOf _v >> "maxSpeed")<=0}) then {_point=getPosATL _v;};
 if (_phase=="RETARGET") exitWith {_retarget=true;};
 if (_phase=="WITHDRAW") then {
  _point=+_base;
  if (!isNull _v) then {
   if (!canMove _v || {_reason=="DAMAGED"}) then {
    [_v,_group,_seed] spawn NeroOP_fnc_bectiAIRepair;
    {if (!isNull _infantryGroup && {local _x} && {alive _x} && {count _reports>0}) then {_x doTarget ((_reports#0)#0);};} forEach (if (isNull _infantryGroup) then {[]} else {units _infantryGroup});
   };
  };
 };
 if (_air && {_phase!="PREPARE"}) then {
  private _task=[_group,_town,_state,_reports,_groundReady,_base] call NeroOP_fnc_bectiAIAir;
  _phase=_task#0;_point=_task#1;_type=_task#2;_target=_task#3;_height=_task#4;
  _v flyInHeight _height;
  if (!isNull _target && {driver _v knowsAbout _target>=1.5}) then {{if (local _x && {alive _x}) then {_x doTarget _target;};} forEach crew _v;};
  if (_phase=="RETURN" && {serverTime>(_v getVariable ["WA_BECTI_landAt",0])}) then {
   _v setVariable ["WA_BECTI_landAt",serverTime+45];
   if (_v isKindOf "Plane" && {_v getVariable ["WA_BECTI_landingAirport",-1]>=0}) then {_v landAt (_v getVariable "WA_BECTI_landingAirport");};
   if (_v isKindOf "Helicopter" && {_v distance2D _base<700}) then {_v landAt [ATLToASL _base,"Land",-1,true];};
  };
 };
 private _contact=_reports findIf {(_x#1) distance2D leader _group<650}>=0;
 private _destination=+_point;
 if (!_air && {!isNull _v} && {!_contact} && {_v distance2D _point>350} && {_phase in ["ASSEMBLE","ADVANCE","WITHDRAW","PREPARE","COVER"]}) then {
  if (count _roadTarget==0 || {_roadTarget distance2D _point>200} || {count _road==0 && {serverTime>_roadRetry}}) then {
   _roadTarget=+_point;_roadRetry=serverTime+45;_road=[getPosATL _v,_point,_side] call NeroOP_fnc_bectiAIRoad;_roadIndex=0;
  };
  if (!call _valid) exitWith {};
  if (count _road==0) then {_destination=getPosATL _v;_phase="WAIT_ROAD";} else {
   while {_roadIndex<count _road-1 && {_v distance2D (_road#_roadIndex)<90}} do {_roadIndex=_roadIndex+1;};
   _destination=_road#_roadIndex;
  };
 };
 if (!call _valid) exitWith {};
 if (_phase!=_lastPhase || {_destination distance2D _lastPoint>80} || {_type!=_lastType} || {count _wp==0}) then {
  {if (waypointDescription _x==_token) then {deleteWaypoint _x;};} forEach +(waypoints _group);
  _wp=_group addWaypoint [_destination,20];_wp setWaypointDescription _token;_wp setWaypointType _type;
  _wp setWaypointCompletionRadius (if (_air) then {200} else {50});
  _wp setWaypointSpeed (if (_air) then {"FULL"} else {"NORMAL"});_wp setWaypointBehaviour "AWARE";
  if (_type=="LOITER") then {_wp setWaypointLoiterRadius 1400;};
  _group setCurrentWaypoint _wp;
  _group setVariable ["WA_BECTI_phase",_phase,true];_group setVariable ["WA_BECTI_destination",_destination];
  diag_log format ["[WA BECTI ATTACK] group=%1 role=%2 phase=%3 town=%4 crew=%5 ready=%6 reason=%7 target=%8",_group,_role,_phase,_town,_live,_ready,_reason,_destination];
  _lastPoint=+_destination;_lastType=_type;_lastPhase=_phase;
 };
 sleep 5;
};
{if (waypointDescription _x==_token) then {deleteWaypoint _x;};} forEach +(waypoints _group);
if (_group getVariable ["WA_BECTI_directorSeed",-1]==_seed) then {_group setVariable ["WA_BECTI_directorSeed",-1];_group setVariable ["WA_BECTI_phase","",true];};
if (call _valid && {_finished || {_retarget}}) then {
 if (_retarget) then {_group setVariable ["WA_BECTI_avoidTown",[_town,serverTime+180]];};
 _group setVariable ["cti_order",if (_order==CTI_ORDER_TAKEHOLDTOWN_AUTO) then {CTI_ORDER_TAKEHOLDTOWNS} else {CTI_ORDER_TAKETOWNS},true];
 _group setVariable ["cti_team_reload",true];
};
