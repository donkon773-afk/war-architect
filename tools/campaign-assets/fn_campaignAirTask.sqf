/* Role-specific native engagement. Reports select targets; weapons spend real ammunition. */
params ["_entry"];
_entry params ["_id","_side","_class","_kind","_v","_parent","_flight"];
if (!alive driver _v || {!local _flight} || {[_v] call NeroOP_fnc_campaignPlayerControl}) exitWith {};
private _role=_v getVariable ["NeroOP_airRole","CAS"];private _contacts=NeroOP_campIntel#_side;
private _escorting=_v getVariable ["NeroOP_escortFor",objNull];
private _return=fuel _v<.25 || {damage _v>.65} || {if (_role=="BOMBER") then {[_v] call NeroOP_fnc_campaignCruiseEmpty} else {[_v] call NeroOP_fnc_campaignAmmoEmpty}};
if (_role=="TRANSPORT_HELI") exitWith {
 private _customer=_v getVariable ["NeroOP_liftCustomer",_parent];
 if (_v getVariable ["NeroOP_liftState","IDLE"]=="IDLE" && {!_return}) then {
  private _rank=[];{private _g=_x;private _t=_g getVariable ["NeroOP_campTarget",-1];private _foot=units _g select {alive _x && {vehicle _x==_x} && {!isPlayer _x}};
   if ((_g getVariable ["NeroOP_side",-1])==_side && {local _g} && {!([_g] call NeroOP_fnc_campaignPlayerControl)} && {!(_g getVariable ["NeroOP_liftBusy",false]) && {!(_g getVariable ["NeroOP_rideBusy",false])}} && {!(_g getVariable ["NeroOP_campGuard",false])} && {serverTime>=(_g getVariable ["NeroOP_liftRetryAt",0])} && {_t>=0} && {count _foot>0} && {leader _g distance2D (NeroOP_campPositions#_t)>3500} && {count _foot<=count (fullCrew [_v,"cargo",true] select {isNull (_x#0)})}) then {_rank pushBack [_v distance2D leader _g,_forEachIndex];};
  } forEach NeroOP_campGroups;
  if (count _rank==0 && {serverTime-(_v getVariable ["NeroOP_liftIdleLogAt",-100])>=60}) then {_v setVariable ["NeroOP_liftIdleLogAt",serverTime];diag_log format ["[NeroOP LIFT] IDLE class=%1 side=%2 seats=%3 groups=%4",typeOf _v,_side,count (fullCrew [_v,"cargo",true] select {isNull (_x#0)}),NeroOP_campGroups apply {[_x getVariable ["NeroOP_groupKey",-1],_x getVariable ["NeroOP_side",-1],_x getVariable ["NeroOP_campTarget",-1],_x getVariable ["NeroOP_campGuard",false],_x getVariable ["NeroOP_rideBusy",false],_x getVariable ["NeroOP_liftBusy",false],[_x] call NeroOP_fnc_campaignPlayerControl,{alive _x && {vehicle _x==_x}} count units _x]}];};
  _rank sort true;if (count _rank>0) then {_customer=NeroOP_campGroups#((_rank#0)#1);_v setVariable ["NeroOP_liftCustomer",_customer];};
 };
 [_v,_customer,_flight,_side,_return] call NeroOP_fnc_campaignLift;
};
if (!_return && {_v isKindOf "Plane"} && {serverTime<(_v getVariable ["NeroOP_climbUntil",0])}) exitWith {
 if !(_v getVariable ["NeroOP_climbOrdered",false]) then {_v setVariable ["NeroOP_climbOrdered",true];{deleteWaypoint _x;} forEach +(waypoints _flight);private _p=(getPosATL _v) getPos [6000,_v getVariable ["NeroOP_climbHeading",getDir _v]];private _wp=_flight addWaypoint [_p,100];_wp setWaypointType "MOVE";_wp setWaypointSpeed "FULL";_wp setWaypointBehaviour "CARELESS";_flight setCurrentWaypoint _wp;_v flyInHeight 1400;};
 if (serverTime-(_v getVariable ["NeroOP_climbLogAt",-100])>=5) then {_v setVariable ["NeroOP_climbLogAt",serverTime];diag_log format ["[NeroOP AIR] INITIAL CLIMB class=%1 AGL=%2 speed=%3 damage=%4 pilotDamage=%5",typeOf _v,(getPosATL _v)#2,speed _v,damage _v,damage driver _v];};
};
private _front=[NeroOP_campOwners,NeroOP_campLinks,NeroOP_campRoots#_side,_side] call NeroOP_fnc_campaignGraph;private _patrol=_v getVariable ["NeroOP_patrolSector",-1];private _frontier=_front#1;if (count _frontier==0) then {_frontier=_front#0;};if (!(_patrol in _frontier) || {serverTime-(_v getVariable ["NeroOP_patrolAt",-1000])>240}) then {private _choices=_frontier apply {[_v distance2D (NeroOP_campPositions#_x),_x]};_choices sort true;if (count _choices>0) then {_patrol=(_choices#0)#1;_v setVariable ["NeroOP_patrolSector",_patrol];_v setVariable ["NeroOP_patrolAt",serverTime];};};private _center=if (_patrol>=0) then {(NeroOP_campPositions#_patrol) getPos [if (_role=="FIGHTER") then {3000} else {1500},(NeroOP_campPositions#_patrol) getDir (NeroOP_campPositions#(NeroOP_campRoots#_side))]} else {NeroOP_campPositions#(NeroOP_campRoots#_side)};private _target=objNull;private _reported=[];private _rank=[];
{private _r=_x;private _obj=_r#0;private _p=_r#1;
 if (alive _obj && {_v distance2D _p<30000} && {(_r#2)==(_role=="FIGHTER") && {_role!="FIGHTER" || {!alive _escorting} || {_escorting distance2D _p<6000}}}) then {
  private _unsafe=false;if !(_r#2) then {_unsafe=allUnits findIf {alive _x && {([west,east]#_side) getFriend side group _x>=.6} && {_x distance2D _p<(if (_role=="BOMBER") then {400} else {180})}}>=0;};
  if (!_unsafe) then {private _priority=_r#3;
   {private _node=_forEachIndex;if (_x==_side && {((NeroOP_campProgress#_node)#(1-_side))>0} && {_p distance2D (NeroOP_campPositions#_node)<(NeroOP_campRadii#_node)+700}) then {_priority=-10;};} forEach NeroOP_campOwners;
   _rank pushBack [_priority,_v distance2D _p,_forEachIndex];
  };
 };
} forEach _contacts;_rank sort true;
if (count _rank>0) then {private _r=_contacts#((_rank#0)#2);_target=_r#0;_reported=+(_r#1);_center=_reported;};
if (!_return && {_role in ["CAS","FIGHTER","ATTACK_HELI"]}) then {
 private _aa=_contacts select {alive (_x#0) && {!(_x#2)} && {(_x#0) getVariable ["NeroOP_assetCategory",""] in ["SAM","AAA","RADAR"] || {toLower typeOf (_x#0) find "radar">=0}}};
 if (count _aa>0) then {private _threat=_aa#0;private _emitter=_threat#0;private _arm=magazinesAllTurrets [_v,true] select {private _cfg=configFile >> "CfgAmmo" >> getText(configFile >> "CfgMagazines" >> (_x#0) >> "ammo");(_x#2)>0 && {isClass(_cfg >> "Components" >> "SensorsManagerComponent" >> "Components" >> "AntiRadiationSensorComponent") || {toLower (_x#0) find "harm">=0} || {toLower (_x#0) find "kh31p">=0}}};
  if (count _arm>0 && {isVehicleRadarOn _emitter}) then {_target=_emitter;_reported=+(_threat#1);_center=_reported getPos [12000,_reported getDir (NeroOP_campPositions#(NeroOP_campRoots#_side))];_v setVariable ["NeroOP_seadTarget",_emitter];} else {_v setVariable ["NeroOP_seadTarget",objNull];if (_v distance2D (_threat#1)<9000) then {_center=(_threat#1) getPos [12000,(_threat#1) getDir getPosATL _v];_target=objNull;};};
 };
};
if (_role=="BOMBER" && {!_return}) then {
 private _escort=_v getVariable ["NeroOP_escort",objNull];
 if (!alive _escort || {fuel _escort<.25} || {[_escort] call NeroOP_fnc_campaignPlayerControl}) then {
  _escort=objNull;private _fighters=NeroOP_campEquipment select {(_x#1)==_side && {alive (_x#4)} && {alive driver (_x#4)} && {(_x#4) getVariable ["NeroOP_airRole",""]=="FIGHTER"} && {!([_x#4] call NeroOP_fnc_campaignPlayerControl)} && {isNull ((_x#4) getVariable ["NeroOP_escortFor",objNull]) || {((_x#4) getVariable ["NeroOP_escortFor",objNull])==_v}}};
  if (count _fighters>0) then {_escort=(_fighters#0)#4;_escort setVariable ["NeroOP_escortFor",_v];};_v setVariable ["NeroOP_escort",_escort];
 };
 private _home=NeroOP_campPositions#(NeroOP_campRoots#_side);private _distance=13000;
 private _holds=[_center,_home,worldSize] call NeroOP_fnc_campaignStandoff;private _dry=_holds select {!surfaceIsWater _x};if (count _dry>0) then {_center=_dry#0;} else {if (count _holds>0) then {_center=_holds#0;} else {_center=+_home;};};_v flyInHeight 2600;
 if (alive _escort && {_escort distance2D _v<3500} && {!isNull _target} && {_v distance2D _reported>=10000} && {_v distance2D _reported<=40000} && {serverTime-(_v getVariable ["NeroOP_strikeAt",-120])>90} && {serverTime-(_v getVariable ["NeroOP_strikeAttemptAt",-10])>8}) then {
  _v setVariable ["NeroOP_strikePos",_reported];_v setVariable ["NeroOP_strikeAttemptAt",serverTime];private _bearing=getDir _v-(_v getDir _reported);_bearing=abs (((_bearing+540) mod 360)-180);
  if (_bearing<25) then {
   private _weapons=weapons _v;{_weapons append (_v weaponsTurret _x);} forEach allTurrets _v;private _weapon=(_weapons arrayIntersect _weapons) select {toLower _x find "kh55">=0};
   if (count _weapon>0) then {private _op=_v turretUnit [4];if (alive _op && {local _op}) then {
    private _laser=_v getVariable ["NeroOP_strikeLaser",objNull];if (isNull _laser) then {_laser=createVehicle [["LaserTargetW","LaserTargetE"]#_side,_reported,[],0,"CAN_COLLIDE"];_v setVariable ["NeroOP_strikeLaser",_laser];};_laser setPosATL _reported;_v setVariable ["NeroOP_laserUntil",serverTime+120];
    _op reveal [_laser,4];_op doTarget _laser;_op doWatch _reported;_v selectWeaponTurret [_weapon#0,[4]];private _state=weaponState [_v,[4]];
    if (count _state>=3 && {toLower (_state#0) find "kh55">=0}) then {_op forceWeaponFire [_state#1,_state#2];};
   };};
  };
 };
 if (!isNull _target && {_v distance2D _reported<10000}) then {_v setVariable ["NeroOP_airOrderAt",-100];};
 if (!isNull _target && {serverTime-(_v getVariable ["NeroOP_airOrderAt",-100])>90}) then {
  /* Launch course stops before the battle, followed by a withdrawal behind friendly lines. */
  {deleteWaypoint _x;} forEach +(waypoints _flight);private _launch=+_center;private _wp=_flight addWaypoint [_launch,500];_wp setWaypointType "MOVE";_wp setWaypointSpeed "FULL";private _hold=_flight addWaypoint [_center,500];_hold setWaypointType "LOITER";_hold setWaypointLoiterRadius 1800;_flight setCombatMode "BLUE";_flight setBehaviourStrong "CARELESS";{_x disableAI "AUTOCOMBAT";} forEach units _flight;_v setVariable ["NeroOP_airOrderAt",serverTime];diag_log format ["[NeroOP AIR] STANDOFF id=%1 escort=%2 reported=%3",_id,alive _escort,_reported];
 };
};
if (_role=="FIGHTER") then {private _bomber=_v getVariable ["NeroOP_escortFor",objNull];if (alive _bomber) then {if (isNull _target) then {_center=((getPosATL _bomber) getPos [1600,getDir _bomber]) getPos [500,getDir _bomber+90];_v forceSpeed (((speed _bomber/3.6) max 150)+15);};} else {_v setVariable ["NeroOP_escortFor",objNull];_v forceSpeed -1;};};
_center=[_center#0,_center#1,0];
private _wasReturning=_v getVariable ["NeroOP_returning",false];private _landing=-1;
if (_return) then {
 _center=NeroOP_campPositions#(NeroOP_campRoots#_side);_target=objNull;_v forceSpeed -1;
 if !(_v isKindOf "Helicopter") then {private _main=NeroOP_campMainAirfields#_side;private _airports=((NeroOP_campAirfieldService#_side) select {_role!="BOMBER" || {count _main==2 && {(_x#0)==_main#0}}}) apply {[if (_role=="BOMBER") then {(NeroOP_campPositions#(NeroOP_campRoots#_side)) distance2D (_x#1)} else {_v distance2D (_x#1)},_x#0,_x#1]};_airports sort true;if (count _airports>0) then {_center=(_airports#0)#2;_landing=(_airports#0)#1;};} else {_v land "LAND";};
 if (_role=="BOMBER" && {_landing>=0} && {isTouchingGround _v} && {abs speed _v<5} && {_v distance2D _center<(NeroOP_campAirfieldRadii param [_landing,750])}) then {if (_v getVariable ["NeroOP_bomberReloadAt",0]==0) then {_v setVariable ["NeroOP_bomberReloadAt",serverTime+480,true];};};
 if ([_v,_side] call NeroOP_fnc_campaignService) then {_v setVariable ["NeroOP_airOrderAt",-100];_v engineOn true;};
};
if (_role!="BOMBER" || {_return} || {isNull _target}) then {
 private _key=if (isNull _target) then {"PATROL:"+str _patrol} else {netId _target};private _prior=_v getVariable ["NeroOP_airCenter",_center];if ([serverTime-(_v getVariable ["NeroOP_airOrderAt",-100]),_v getVariable ["NeroOP_airTargetKey",""],_key,_wasReturning,_return,_prior distance2D _center,if (alive _escorting) then {30} else {90}] call NeroOP_fnc_campaignAirOrderGate) then {
  {deleteWaypoint _x;} forEach +(waypoints _flight);private _wp=_flight addWaypoint [_center,if (isNull _target) then {500} else {150}];
  _wp setWaypointType (if (_return) then {"MOVE"} else {if (isNull _target) then {if (alive _escorting) then {"MOVE"} else {"LOITER"}} else {if (_v getVariable ["NeroOP_seadTarget",objNull]==_target) then {"MOVE"} else {"SAD"}}});_wp setWaypointSpeed "FULL";_wp setWaypointLoiterRadius (if (_v isKindOf "Helicopter") then {500} else {1400});
  _flight setBehaviourStrong (if (isNull _target || {_return}) then {"CARELESS"} else {"AWARE"});_flight setCombatMode (if (isNull _target || {_return}) then {"BLUE"} else {"RED"});{if (isNull _target || {_return}) then {_x disableAI "AUTOCOMBAT";} else {_x enableAI "AUTOCOMBAT";};_x setVariable ["lambs_danger_disableAI",true];} forEach units _flight;_v flyInHeight (if (_v isKindOf "Helicopter") then {120} else {if (_role=="BOMBER" || {_role=="FIGHTER" && {alive _escorting}}) then {2600} else {900}});_v setVariable ["NeroOP_airOrderAt",serverTime];_v setVariable ["NeroOP_attackObject",_target];_v setVariable ["NeroOP_airTargetKey",_key];_v setVariable ["NeroOP_airCenter",+_center];_v setVariable ["NeroOP_returning",_return];if (_return && {_landing>=0}) then {_v landAt _landing;};
  diag_log format ["[NeroOP AIR] TASK id=%1 role=%2 target=%3 reported=%4 return=%5",_id,_role,typeOf _target,_center,_return];
 };
 if (!isNull _target && {!_return}) then {private _sead=_v getVariable ["NeroOP_seadTarget",objNull];if (_sead==_target && {isVehicleRadarOn _target} && {_v distance _target>=9000} && {serverTime-(_v getVariable ["NeroOP_armAttemptAt",-20])>15}) then {private _mags=magazinesAllTurrets [_v,true] select {(_x#2)>0 && {toLower (_x#0) find "harm">=0 || {toLower (_x#0) find "kh31p">=0}}};if (count _mags>0) then {private _path=(_mags#0)#1;private _op=if (_path isEqualTo [-1]) then {driver _v} else {_v turretUnit _path};private _weapons=_v weaponsTurret _path;private _weapon=_weapons select {(_mags#0)#0 in getArray(configFile >> "CfgWeapons" >> _x >> "magazines")};if (count _weapon>0 && {alive _op}) then {_v selectWeaponTurret [_weapon#0,_path];_op reveal [_target,3];_op doTarget _target;_v setVariable ["NeroOP_armAttemptAt",serverTime];};};};_v forceSpeed -1;{if (local _x && {alive _x}) then {_x reveal [_target,2];_x doTarget _target;_x doFire _target;};} forEach crew _v;};
};

if (!isNull _target && {!_return} && {_role in ["FIGHTER","CAS","ATTACK_HELI"]}) then {[_v,_target,30000] call NeroOP_fnc_campaignMissileEngage;};
