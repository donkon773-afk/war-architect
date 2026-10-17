/* Standard AI purchases only. Custom salvage scripts keep their native handler.
   Native account is committed after creating and validating the complete crew. */
params ["_waSeed","_waClass","_waBuyer","_waTarget","_waFactory","_waSide"];
if (!isServer || {isRemoteExecuted}) exitWith {};
private _waDone={[_waSeed,_waClass,_waTarget,_waFactory] call CTI_SE_FNC_OnClientPurchaseComplete;};
if (!(_waBuyer isEqualType grpNull)) then {_waBuyer=group _waBuyer;};
if (!(_waTarget isEqualType grpNull) || {isNull _waTarget} || {!local _waTarget} || {[_waTarget] call NeroOP_fnc_campaignPlayerControl}) exitWith {call _waDone;};
private _waMeta=missionNamespace getVariable [_waClass,[]];
private _waOriginalOrder=_waTarget getVariable ["cti_order",-1];
private _waAutoOrders=[CTI_ORDER_TAKETOWNS,CTI_ORDER_TAKEHOLDTOWNS,CTI_ORDER_TAKETOWN_AUTO,CTI_ORDER_TAKEHOLDTOWN_AUTO];
if (count _waMeta<8 || {!isClass(configFile >> "CfgVehicles" >> _waClass)}) exitWith {call _waDone;};
private _waPending={(_waFactory getVariable ["cti_queue_processing",[]]) findIf {count _x>1 && {(_x#0) isEqualTo _waSeed} && {(_x#1) isEqualTo _waClass}}>=0};
private _waFinish=time+(if (missionNamespace getVariable ["CTI_Debug",false]) then {0} else {_waMeta#3});
waitUntil {sleep .25;time>=_waFinish || {!alive _waFactory} || {!alive leader _waTarget} || {!call _waPending}};
if (!alive _waFactory || {!alive leader _waTarget} || {!call _waPending} || {[_waTarget] call NeroOP_fnc_campaignPlayerControl} || {_waOriginalOrder in _waAutoOrders && {!((_waTarget getVariable ["cti_order",-1]) in _waAutoOrders)}}) exitWith {call _waDone;};
private _waFactoryConfig=missionNamespace getVariable [format ["CTI_%1_%2",_waSide,_waFactory getVariable "cti_structure_type"],[]];
private _waOffset=if (count _waFactoryConfig>4) then {_waFactoryConfig#4} else {[0,25]};
private _waHeading=360-(_waOffset#0)+getDir _waFactory;
private _waPosition=_waFactory modelToWorld [sin (_waOffset#0)*(_waOffset#1),cos (_waOffset#0)*(_waOffset#1),0];
private _waFree=_waPosition findEmptyPosition [0,35,_waClass];
if (count _waFree<2 || {surfaceIsWater _waFree}) exitWith {diag_log format ["[WA BECTI SPAWN] NO_SPACE class=%1",_waClass];call _waDone;};
private _waCost=_waMeta#2;private _waCreated=objNull;private _waNewUnits=[];private _waError="";
private _waOriginalLeader=leader _waTarget;
private _waOriginalVehicle=vehicle _waOriginalLeader;
private _waCreate=compile preprocessFileLineNumbers "warArchitect\createNative.sqf";
if (([_waBuyer,_waSide] call CTI_CO_FNC_GetFunds)<_waCost) exitWith {call _waDone;};
if (_waClass isKindOf "Man") then {
 if ({alive _x} count units _waTarget>=getNumber(missionConfigFile >> "CfgWarArchitectDoctrine" >> str _waSide >> "groupSize")) then {_waError="GROUP_FULL";} else {
  _waCreated=["UNIT",[_waClass,_waTarget,_waFree,_waSide,true]] call _waCreate;
  if (!isNull _waCreated) then {_waNewUnits pushBack _waCreated;};
 };
} else {
 private _waExisting=(units _waTarget apply {vehicle _x}) select {!(_x isKindOf "Man") && {alive _x} && {driver _x in units _waTarget}};
 if (count _waExisting>0) then {_waError="ALREADY_HAS_VEHICLE";} else {
  if (_waOriginalLeader distance2D _waFactory>300 || {_waOriginalVehicle!=_waOriginalLeader}) then {_waError="LEADER_NOT_AT_FACTORY";} else {
   private _waAir=_waClass isKindOf "Air";private _waPlane=_waClass isKindOf "Plane";
   if (_waAir) then {_waHeading=_waFree getDir [worldSize/2,worldSize/2];};
   _waCreated=["VEHICLE",[_waClass,_waFree,_waHeading,_waSide,true,true,true,if (_waPlane) then {"FLY"} else {"NONE"}]] call _waCreate;
   if (_waPlane && {!isNull _waCreated}) then {_waCreated setVariable ["WarArchitect_flightSeen",true];};
   if (!isNull _waCreated) then {
    private _waSeats=fullCrew [_waCreated,"",true] select {toLower(_x#1)!="cargo" && {!(_x param [4,false])}};
    private _waCrewClass=missionNamespace getVariable format ["CTI_%1_%2",_waSide,if (_waAir) then {"Pilot"} else {"Crew"}];
    private _waCrewMeta=missionNamespace getVariable [_waCrewClass,[]];
    private _waCrewCost=if (count _waCrewMeta>2) then {_waCrewMeta#2} else {5};
    _waCost=_waCost+((count _waSeats-1) max 0)*_waCrewCost;
    if (count _waSeats==0 || {([_waBuyer,_waSide] call CTI_CO_FNC_GetFunds)<_waCost}) then {_waError="CREW_COST";} else {
     {
      private _waCrewUnit=if (toLower(_x#1)=="driver") then {_waOriginalLeader} else {["UNIT",[_waCrewClass,_waTarget,_waFree,_waSide,true]] call _waCreate};
      if (!isNull _waCrewUnit) then {
       if (_waCrewUnit!=_waOriginalLeader) then {_waNewUnits pushBack _waCrewUnit;};
       if (toLower(_x#1)=="driver") then {_waCrewUnit assignAsDriver _waCreated;_waCrewUnit moveInDriver _waCreated;} else {_waCrewUnit assignAsTurret [_waCreated,_x#3];_waCrewUnit moveInTurret [_waCreated,_x#3];};
      };
     } forEach _waSeats;
     if ((fullCrew [_waCreated,"",true] select {toLower(_x#1)!="cargo" && {!(_x param [4,false])}}) findIf {isNull (_x#0) || {vehicle (_x#0)!=_waCreated}}>=0) then {_waError="CREW_FAILED";};
    };
   };
  };
 };
};
if (isNull _waCreated && {_waError==""}) then {_waError="CREATE_FAILED";};
if (_waError=="") then {
 isNil {
  if (!call _waPending || {[_waTarget] call NeroOP_fnc_campaignPlayerControl} || {([_waBuyer,_waSide] call CTI_CO_FNC_GetFunds)<_waCost}) then {_waError="CANCELLED_OR_FUNDS";} else {[_waBuyer,_waSide,-_waCost] call CTI_CO_FNC_ChangeFunds;};
 };
};
if (_waError!="") then {
 if (vehicle _waOriginalLeader==_waCreated && {_waCreated!=_waOriginalLeader}) then {unassignVehicle _waOriginalLeader;moveOut _waOriginalLeader;};
 {deleteVehicle _x;} forEach _waNewUnits;
 if (!(_waClass isKindOf "Man") && {!isNull _waCreated}) then {deleteVehicle _waCreated;};
 diag_log format ["[WA BECTI SPAWN] CANCEL group=%1 class=%2 reason=%3",_waTarget,_waClass,_waError];
} else {
 _waCreated setVariable ["cti_occupant",_waSide,true];
 if (!(_waClass isKindOf "Man")) then {
  _waTarget addVehicle _waCreated;
  _waCreated setVariable ["WA_BECTI_combatVehicle",true,true];
  _waTarget setVariable ["WA_BECTI_vehicle",_waCreated,true];
  _waCreated setVariable ["v_keys",[_waTarget],true];
  if (_waClass isKindOf "Plane") then {_waCreated setVariable ["WA_BECTI_climbUntil",serverTime+30];};
  [_waCreated] spawn CTI_SE_FNC_HandleEmptyVehicle;
  // Do not leave former infantry following a jet on foot or delete them to
  // make room for crew. Redistribute AI-only surplus into an infantry group.
  if (count fullCrew [_waCreated,"cargo",true]<3) then {
   private _waSurplus=units _waTarget select {alive _x && {local _x} && {vehicle _x==_x} && {!isPlayer _x}};
   if (count _waSurplus>0) then {
    private _waReserve=createGroup [_waSide,true];_waReserve setVariable ["cti_server_group",str _waSide,true];
    _waSurplus joinSilent _waReserve;_waReserve setVariable ["cti_role","Infantry",true];_waReserve setVariable ["WA_BECTI_fixedRole",true];
    private _waTransfer=([_waTarget,_waSide] call CTI_CO_FNC_GetFunds)*.25;
    [_waTarget,_waSide,-_waTransfer] call CTI_CO_FNC_ChangeFunds;_waReserve setVariable ["cti_funds",_waTransfer,true];
    [_waReserve,_waSide] call CTI_SE_FNC_InitializeGroup;
    [_waReserve,_waSide] execFSM "Server\FSM\update_ai.fsm";
   };
  };
 };
 diag_log format ["[WA BECTI SPAWN] READY group=%1 role=%2 class=%3 crew=%4 cost=%5",_waTarget,_waTarget getVariable ["cti_role",""],_waClass,count crew _waCreated,_waCost];
};
call _waDone;
