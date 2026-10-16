/* A separate supervisor. It never takes control of a human crew or UAV operator. */
private _cfg=missionConfigFile >> "CfgNeroOperation";private _rules=_cfg >> "Equipment";private _lastFleetPurchase=[-1000,-1000];
while {!NeroOP_campFinished} do {
 sleep 5;
 {private _group=_x;private _uid=_group getVariable ["NeroOP_hcUID",""];if (_uid!="" && {!(_group getVariable ["NeroOP_dropBusy",false])} && {units _group findIf {alive _x}>=0}) then {private _found=allPlayers findIf {getPlayerUID _x==_uid && {alive _x} && {side group _x==([west,east]#(_group getVariable ["NeroOP_side",-1]))}};if (_found>=0) then {private _unit=allPlayers#_found;if (_group getVariable ["NeroOP_hcCommander",objNull]!=_unit) then {private _logic=_unit getVariable ["NeroOP_hcLogic",objNull];if (isNull _logic) then {private _logics=createGroup [sideLogic,true];isNil {_logic=_logics createUnit ["HighCommand",[0,0,0],[],0,"NONE"];_logic setVariable ["addAllGroups",false,true];_logic synchronizeObjectsAdd [_unit];_unit setVariable ["NeroOP_hcLogic",_logic,true];};};_group setVariable ["NeroOP_hcCommander",_unit,true];_group setGroupOwner owner _unit;[_unit,_group,_logic] remoteExec ["NeroOP_fnc_campaignHC",owner _unit];};};};} forEach NeroOP_campGroups;
 NeroOP_campSupplyTrucks=NeroOP_campSupplyTrucks select {alive _x && {alive driver _x}};
 for "_side" from 0 to 1 do {private _fleet={(_x getVariable ["NeroOP_side",-1])==_side} count NeroOP_campSupplyTrucks;private _wanted=getNumber(_cfg >> "Gameplay" >> "truckFleet") min getNumber(_cfg >> "convoyLimit");if (_fleet<_wanted && {getNumber(_rules >> "aiPurchases")==1} && {serverTime-(_lastFleetPurchase#_side)>60} && {(NeroOP_campStocks#(NeroOP_campRoots#_side))>getNumber(_cfg >> "Gameplay" >> "truckCost")+2*getNumber(_cfg >> "reinforcementCost")}) then {_lastFleetPurchase set [_side,serverTime];isNil {[_side] call NeroOP_fnc_campaignSupplyTruck;};};};
 {private _r=_x;_r params ["_vehicle","_side","_target","_unit"];if (!alive _vehicle || {(NeroOP_campOwners#_target)!=_side} || {!alive _unit} || {side group _unit!=([west,east]#_side)}) then {NeroOP_campServiceRequests=NeroOP_campServiceRequests-[_r];} else {if (_vehicle distance2D (NeroOP_campPositions#_target)<NeroOP_campRadii#_target) then {private _paid=false;isNil {_paid=[_vehicle,_side,true] call NeroOP_fnc_campaignService;};if (_paid) then {NeroOP_campServiceRequests=NeroOP_campServiceRequests-[_r];_unit setVariable ["NeroOP_notice","Доставка получена, боезапас и техника восстановлены за снабжение.",true];};};};} forEach +NeroOP_campServiceRequests;
 {if (!local _x && {!([_x] call NeroOP_fnc_campaignPlayerControl)}) then {_x setGroupOwner 2;};} forEach NeroOP_campGroups;
 {private _entry=_x;_entry params ["_id","_side","_class","_kind","_vehicle","_parent","_flight","_ai"];
  if (!alive _vehicle || {!alive driver _vehicle && {_kind==1 || {_vehicle getVariable ["NeroOP_rideState",""] in ["BOARD","TRAVEL","UNLOAD"]}}}) then {private _g=_vehicle getVariable ["NeroOP_liftCustomer",_parent];if (!isNull _g && {local _g} && {!([_g] call NeroOP_fnc_campaignPlayerControl)}) then {if ((_g getVariable ["NeroOP_liftVehicle",objNull]) isEqualTo _vehicle) then {_g setVariable ["NeroOP_liftBusy",false];_g setVariable ["NeroOP_liftVehicle",objNull];};if ((_g getVariable ["NeroOP_rideVehicle",objNull]) isEqualTo _vehicle) then {_g setVariable ["NeroOP_rideBusy",false];_g setVariable ["NeroOP_rideVehicle",objNull];};{if (alive _x && {local _x} && {vehicle _x==_vehicle}) then {unassignVehicle _x;[_x] orderGetIn false;_x action ["GetOut",_vehicle];};} forEach units _g;[_g,true] call NeroOP_fnc_campaignOrder;};{deleteVehicle _x;} forEach (_vehicle getVariable ["NeroOP_liftPads",[]]);_vehicle setVariable ["NeroOP_liftPads",[]];};
  if (alive _vehicle) then {
   private _laser=_vehicle getVariable ["NeroOP_strikeLaser",objNull];if (!isNull _laser && {serverTime>(_vehicle getVariable ["NeroOP_laserUntil",0])}) then {deleteVehicle _laser;_vehicle setVariable ["NeroOP_strikeLaser",objNull];};
   private _pilot=_vehicle getVariable ["NeroOP_pendingPilot",objNull];
   if (!isNull _pilot && {serverTime-(_vehicle getVariable ["NeroOP_pendingAt",serverTime])>25}) then {
    if (driver _vehicle==_pilot && {alive _pilot} && {isPlayer _pilot}) then {[_pilot,"READY",_id] call NeroOP_fnc_campaignEquipmentAction;} else {
     private _base=NeroOP_campPositions#(NeroOP_campRoots#_side);_vehicle setPosATL [_base#0+30,_base#1+30,0];_vehicle enableSimulationGlobal true;_vehicle allowDamage true;_vehicle setVariable ["NeroOP_pendingPilot",objNull,true];
    };
   };
   if (_vehicle getVariable ["NeroOP_independentCrew",false] && {!isNull _flight}) then {private _uid=_vehicle getVariable ["NeroOP_crewUID",""];private _commander=(allPlayers select {alive _x && {getPlayerUID _x==_uid}}) param [0,objNull];if (!isNull _commander && {_flight getVariable ["NeroOP_hcCommander",objNull]!=_commander}) then {[_commander,_flight] call NeroOP_fnc_campaignAttachHC;};};
   private _drone=_vehicle getVariable ["NeroOP_drone",false];private _controlled=[_vehicle] call NeroOP_fnc_campaignPlayerControl || {!isNull _flight && {[_flight] call NeroOP_fnc_campaignPlayerControl}};if (_controlled) then {_vehicle forceSpeed -1;private _customer=_vehicle getVariable ["NeroOP_liftCustomer",grpNull];if (!isNull _customer) then {_customer setVariable ["NeroOP_liftBusy",false];};{if (local _x) then {_x enableAI "AUTOCOMBAT";};} forEach crew _vehicle;};
   if (_ai && {!_controlled} && {local _vehicle}) then {
    if (_kind==1 && {alive driver _vehicle} && {local _flight}) then {[_entry] call NeroOP_fnc_campaignAirTask;};
    if (_kind==0) then {
     if (canFire _vehicle && {!(_vehicle getVariable ["NeroOP_adManaged",false])}) then {private _aa=_vehicle getVariable ["NeroOP_assetCategory",""] in ["AAA","SAM"];private _targets=(NeroOP_campIntel#_side) select {(_x#2)==_aa && {alive (_x#0)} && {_vehicle distance2D (_x#1)<(if (_aa) then {12000} else {2200})}};if (count _targets>0 && {!(_vehicle getVariable ["NeroOP_artillery",false])}) then {private _t=(_targets#0)#0;{if (local _x && {alive _x}) then {_x reveal [_t,2];_x doTarget _t;_x doFire _t;};} forEach crew _vehicle;};};
     if (!(_vehicle getVariable ["NeroOP_artillery",false]) && {fuel _vehicle<.25 || {damage _vehicle>.65} || {[_vehicle] call NeroOP_fnc_campaignAmmoEmpty}}) then {_vehicle setVariable ["NeroOP_needsService",true];if ([_vehicle,_side] call NeroOP_fnc_campaignService) then {_vehicle setVariable ["NeroOP_needsService",false];};};
     if (_vehicle getVariable ["NeroOP_artillery",false]) then {if (!isNull _parent) then {[_vehicle,if (isNull _flight) then {_parent} else {_flight},_side] call NeroOP_fnc_campaignArtillery;};private _ammo=getArtilleryAmmo [_vehicle];private _rounds=(magazinesAllTurrets [_vehicle,true]) findIf {(_x#0) in _ammo && {(_x#2)>0}}>=0;_vehicle setVariable ["NeroOP_needsService",!_rounds || {fuel _vehicle<.25} || {damage _vehicle>.65}];if (_vehicle getVariable ["NeroOP_needsService",false] && {[_vehicle,_side] call NeroOP_fnc_campaignService}) then {_vehicle setVariable ["NeroOP_needsService",false];};};
     if (_drone && {local _flight} && {_vehicle isKindOf "StaticWeapon"}) then {private _target=[_side,getPosATL _vehicle] call NeroOP_fnc_campaignDefense;if (_vehicle getVariable ["NeroOP_droneTarget",-1]!=_target) then {{deleteWaypoint _x;} forEach +(waypoints _flight);private _wp=_flight addWaypoint [NeroOP_campPositions#_target,100];_wp setWaypointType "HOLD";_vehicle setVariable ["NeroOP_droneTarget",_target];};};
     if (!(_vehicle isKindOf "StaticWeapon") && {!(_vehicle getVariable ["NeroOP_stationary",false])} && {!isNull _parent} && {local _parent} && {!([_parent] call NeroOP_fnc_campaignPlayerControl)}) then {
      private _groundGroup=if ((_vehicle getVariable ["NeroOP_detachedCrew",false] || {_drone}) && {!isNull _flight}) then {_flight} else {_parent};private _target=_parent getVariable ["NeroOP_campTarget",-1];_groundGroup setVariable ["NeroOP_attackHold",_parent getVariable ["NeroOP_attackHold",false]];if (_vehicle getVariable ["NeroOP_support",false] || {_drone}) then {_target=[_side,getPosATL _vehicle] call NeroOP_fnc_campaignDefense;};
      if (_vehicle getVariable ["NeroOP_needsService",false]) then {private _graph=[NeroOP_campOwners,NeroOP_campLinks,NeroOP_campRoots#_side,_side] call NeroOP_fnc_campaignGraph;private _nodes="true" configClasses (_cfg >> "Sectors");private _rank=[];{if (getText((_nodes#_x) >> "kind") in ["base","depot"] && {(NeroOP_campStocks#_x)>=30}) then {_rank pushBack [_vehicle distance2D (NeroOP_campPositions#_x),_x];};} forEach (_graph#0);_rank sort true;if (count _rank>0) then {_target=(_rank#0)#1;};};
      _groundGroup setVariable ["NeroOP_campTarget",_target];
      private _boarding=false;if (!(_vehicle getVariable ["NeroOP_independentCrew",false]) && {_vehicle getVariable ["NeroOP_assetCategory",""] in ["CAR","APC"]} && {_vehicle getVariable ["NeroOP_detachedCrew",false]}) then {_boarding=[_vehicle,_parent,_groundGroup,_target] call NeroOP_fnc_campaignRide;};
      if (!_boarding) then {
      private _pos=getPosATL _vehicle;private _anchor=_vehicle getVariable ["NeroOP_vehicleAnchor",[_pos,serverTime]];
      if (_pos distance2D (_anchor#0)>25) then {_vehicle setVariable ["NeroOP_vehicleAnchor",[_pos,serverTime]];} else {if (_target>=0 && {_vehicle distance2D (NeroOP_campPositions#_target)>500} && {serverTime-(_anchor#1)>(if (getNumber(_cfg >> "DevMode" >> "coordinatedAI")==1) then {18} else {60})} && {!(_vehicle getVariable ["NeroOP_avoidBusy",false])} && {!(_vehicle getVariable ["NeroOP_repairBusy",false])} && {!(_vehicle getVariable ["NeroOP_routeBusy",false])}) then {[_vehicle,_groundGroup,_target] spawn NeroOP_fnc_campaignAvoidObstacle;_vehicle setVariable ["NeroOP_groundTarget",-1];_vehicle setVariable ["NeroOP_vehicleAnchor",[_pos,serverTime]];_vehicle engineOn true;};};if (isNil {_vehicle getVariable "NeroOP_vehicleAnchor"}) then {_vehicle setVariable ["NeroOP_vehicleAnchor",[_pos,serverTime]];};
      private _static=_vehicle isKindOf "StaticWeapon";
      if (!_static && {_target>=0} && {alive driver _vehicle} && {canMove _vehicle} && {!(_vehicle getVariable ["NeroOP_avoidBusy",false])} && {!(_vehicle getVariable ["NeroOP_repairBusy",false])} && {!(_vehicle getVariable ["NeroOP_routeBusy",false])} && {serverTime>=(_vehicle getVariable ["NeroOP_routeRetryAt",0])} && {(_vehicle getVariable ["NeroOP_groundTarget",-1])!=_target}) then {[_vehicle,_groundGroup,_target] spawn NeroOP_fnc_campaignVehicleOrder;};
      if (_target>=0 && {!_static} && {!(_parent getVariable ["NeroOP_attackHold",false])} && {!(_parent getVariable ["NeroOP_liftBusy",false])} && {!(_parent getVariable ["NeroOP_rideBusy",false])} && {(NeroOP_campOwners#_target)!=_side} && {_vehicle distance2D (NeroOP_campPositions#_target)<(NeroOP_campRadii#_target)+220}) then {
       {if (local _x && {alive _x} && {abs speed _vehicle<8} && {((assignedVehicleRole _x) param [0,""])=="cargo"}) then {unassignVehicle _x;moveOut _x;};} forEach units _parent;
       private _point=(NeroOP_campPositions#_target) getPos [(NeroOP_campRadii#_target)-50,(NeroOP_campPositions#_target) getDir getPosATL _vehicle];
       {if (alive _x && {vehicle _x==_x} && {local _x}) then {_x doMove _point;};} forEach units _parent;
      };
      };
     };
    };
   };
  };
 } forEach +NeroOP_campEquipment;
 if (getNumber(_rules >> "aiPurchases")==1) then {
  for "_side" from 0 to 1 do {
   private _groups=NeroOP_campGroups select {(_x getVariable ["NeroOP_side",-1])==_side && {local _x} && {[false,_x getVariable ["NeroOP_liftBusy",false],_x getVariable ["NeroOP_rideBusy",false],_x getVariable ["NeroOP_dropBusy",false]] call NeroOP_fnc_campaignTransitGate} && {alive leader _x} && {!([_x] call NeroOP_fnc_campaignPlayerControl)}};
   private _start=NeroOP_campShopCursor#_side;private _bought=false;
   for "_offset" from 0 to (count _groups)-1 do {
    private _group=_groups#((_start+_offset) mod count _groups);
    if (!_bought && {serverTime>=(_group getVariable ["NeroOP_nextEquipment",0])} && {serverTime-(NeroOP_campBuyAt#_side)>=5}) then {
     _group setVariable ["NeroOP_nextEquipment",serverTime+15];
     private _frames=NeroOP_campEquipment select {(_x#1)==_side && {alive (_x#4)}};
     private _normal={(_x#3)==0 && {!((_x#4) getVariable ["NeroOP_support",false])}} count _frames;
     private _air={(_x#3)==1} count _frames;private _bomber=_frames findIf {(_x#4) getVariable ["NeroOP_airRole",""]=="BOMBER"}>=0;
     private _escort=_frames findIf {(_x#4) getVariable ["NeroOP_airRole",""]=="FIGHTER"}>=0;
     private _gv=_group getVariable ["NeroOP_groundVehicle",objNull];private _av=_group getVariable ["NeroOP_airVehicle",objNull];private _target=_group getVariable ["NeroOP_campTarget",-1];
     private _lift=_target>=0 && {leader _group distance2D (NeroOP_campPositions#_target)>3500};
     private _roles=[_normal,_air,count _groups,getNumber(_rules >> "airLimit"),alive _gv,alive _av,_bomber,_escort,_lift] call NeroOP_fnc_campaignDoctrine;
     if (!alive _gv && {_normal>=2} && {(_group getVariable ["NeroOP_groupKey",0]) mod 3==0}) then {_roles=["AAA","SAM","RADAR","MLRS","ARTILLERY_SP","ARTILLERY_STATIC"]+_roles;};
     if (!alive _gv && {(_group getVariable ["NeroOP_groupKey",0]) mod 3!=0}) then {private _preferred=if ((_group getVariable ["NeroOP_groupKey",0]) mod 4==0) then {"TANK"} else {if ((_group getVariable ["NeroOP_groupKey",0]) mod 4==2) then {"CAR"} else {"APC"}};_roles=[_preferred]+(_roles-[_preferred]);};
     if (_side==0 && {_normal>=2}) then {_roles=["FLAMINGO"]+_roles;};if (_side==1 && {_escort} && {_normal>=2}) then {_roles=["BOMBER"]+_roles;};
     private _rank=[];
     {private _index=_x;private _row=NeroOP_campShop#_side#_index;private _role=_row param [5,_row#3];private _priority=_roles find _role;
      if (_priority>=0) then {private _used={private _v=_x#4;(_v getVariable ["NeroOP_airRole",_v getVariable ["NeroOP_assetCategory",""]])==_role} count _frames;private _cap=if (_role in ["BOMBER","FLAMINGO"]) then {1} else {((floor (getNumber(_rules >> "airLimit")/4)) max 1) min 3};if ((_row#1)==0 || {_used<_cap}) then {_rank pushBack [_priority+(if (_role in ["AAA","SAM","RADAR","MLRS","ARTILLERY_SP","ARTILLERY_STATIC"]) then {4*_used} else {0}),_used,_row#2,_index];};};
     } forEach (NeroOP_campAIShop#_side);_rank sort true;
     {if (!_bought) then {private _v=objNull;isNil {_v=[_side,_x#3,_group] call NeroOP_fnc_campaignBuy;};if (!isNull _v) then {_bought=true;_group setVariable ["NeroOP_nextEquipment",serverTime+15];NeroOP_campShopCursor set [_side,(_start+_offset+1) mod count _groups];};};} forEach _rank;
    };
   };
  };
 };
 private _counts=[[0,0],[0,0]];private _rows=[];
 {if (alive (_x#4)) then {private _side=_x#1;private _kind=_x#3;(_counts#_side) set [_kind,((_counts#_side)#_kind)+1];_rows pushBack [_x#0,_side,_x#2,_kind,count crew (_x#4),_x#7 || {(_x#4) getVariable ["NeroOP_drone",false]},isNull driver (_x#4),_x#10,(_x#4) getVariable ["NeroOP_independentCrew",false]];};} forEach NeroOP_campEquipment;
 NeroOP_campEquipmentState=[_rows,_counts,+NeroOP_campEquipmentIssued,[0,1] apply {(getNumber(_rules >> "cooldown")-serverTime+(NeroOP_campBuyAt#_x)) max 0}];publicVariable "NeroOP_campEquipmentState";
 {if (!alive (_x#4) && {!isNull (_x#6)} && {count units (_x#6)==0}) then {deleteGroup (_x#6);};} forEach NeroOP_campEquipment;
 {if (!alive (_x#4)) then {private _customer=(_x#4) getVariable ["NeroOP_liftCustomer",grpNull];if (!isNull _customer) then {_customer setVariable ["NeroOP_liftBusy",false];};deleteVehicle ((_x#4) getVariable ["NeroOP_strikeLaser",objNull]);};} forEach NeroOP_campEquipment;NeroOP_campEquipment=NeroOP_campEquipment select {alive (_x#4)};NeroOP_campCrates=NeroOP_campCrates select {!isNull _x && {alive _x}};
};
