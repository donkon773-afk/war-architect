/* BECTI adapter: native commander/FSM owns objectives and purchases.
   These owner-local safety actions preserve waypoints and player authority. */
waitUntil {sleep 1;missionNamespace getVariable ["CTI_Init_Common",false]};
NeroOP_campReady=true;NeroOP_campFinished=false;if (isServer) then {NeroOP_campMissiles=[];};
[] spawn NeroOP_fnc_campaignSensors;
if (getNumber(missionConfigFile >> "CfgNeroOperation" >> "DevMode" >> "radarNetwork")==1) then {[] spawn NeroOP_fnc_campaignAirDefense;};
diag_log "[WarArchitect BECTI] adapter started: native economy / native objectives / shared sensors";
while {!(missionNamespace getVariable ["CTI_GameOver",false])} do {
 {
  private _v=_x;private _g=group driver _v;
  if (alive _v && {local _v} && {alive driver _v} && {local _g} && {!([_v] call NeroOP_fnc_campaignPlayerControl)} && {!([_g] call NeroOP_fnc_campaignPlayerControl)} && {side _g in [west,east]}) then {
   _v setVariable ["NeroOP_campaignVehicle",true];_v setVariable ["NeroOP_side",[west,east] find side _g,true];
   if (_v isKindOf "Plane" && {!(_v getVariable ["WarArchitect_flightSeen",false])}) then {
    _v setVariable ["WarArchitect_flightSeen",true];
    if (!isTouchingGround _v && {speed _v>180}) then {
     private _wp=currentWaypoint _g;private _heading=getDir _v;private _p=(getPosATL _v) getPos [5000,_heading];
     _v flyInHeight 1200;driver _v doMove _p;
     [_v,_g,_wp] spawn {params ["_v","_g","_wp"];sleep 20;if (alive _v && {local _g} && {!([_g] call NeroOP_fnc_campaignPlayerControl)} && {currentWaypoint _g==_wp}) then {_g setCurrentWaypoint [_g,_wp];};};
     diag_log format ["[WarArchitect BECTI AIR] INITIAL class=%1 speed=%2 AGL=%3",typeOf _v,speed _v,(getPosATL _v)#2];
    };
   };
   if (_v isKindOf "LandVehicle" && {getNumber(missionConfigFile >> "CfgNeroOperation" >> "DevMode" >> "coordinatedAI")==1}) then {
    private _wp=currentWaypoint _g;private _target=_g getVariable ["WA_BECTI_destination",waypointPosition [_g,_wp]];private _sample=_v getVariable ["WarArchitect_motion",[getPosATL _v,serverTime,_wp]];
    private _enemy=(driver _v) findNearestEnemy _v;private _contact=!isNull _enemy && {_enemy distance2D _v<650};
    if (count _target<2 || {(_target#0)<=0} || {(_target#1)<=0} || {(_sample#2)!=_wp} || {_v distance2D (_sample#0)>8} || {_v distance2D _target<100} || {_contact} || {!canMove _v}) then {_v setVariable ["WarArchitect_motion",[getPosATL _v,serverTime,_wp]];} else {
     if (serverTime-(_sample#1)>25 && {abs speed _v<3} && {serverTime>(_v getVariable ["WarArchitect_detourAt",0])}) then {
      private _origin=getPosATL _v;private _detour=[];
      {private _p=_origin getPos [18,getDir _v+_x];if (!surfaceIsWater _p && {(surfaceNormal _p)#2>.9} && {count lineIntersectsSurfaces [getPosASL _v vectorAdd [0,0,1],ATLToASL _p vectorAdd [0,0,1],_v,objNull,true,1,"GEOM","NONE"]==0}) exitWith {_detour=_p;};} forEach [65,-65,100,-100];
      _v setVariable ["WarArchitect_detourAt",serverTime+45];_v setVariable ["WarArchitect_motion",[_origin,serverTime,_wp]];
      if (count _detour>0) then {private _seed=_g getVariable ["cti_order_seed",-1];driver _v doMove _detour;[_v,_g,_wp,_target,_seed] spawn {params ["_v","_g","_wp","_target","_seed"];sleep 8;if (alive _v && {local _v} && {local _g} && {currentWaypoint _g==_wp} && {_g getVariable ["cti_order_seed",-1]==_seed} && {!([_g] call NeroOP_fnc_campaignPlayerControl)}) then {driver _v doMove _target;};};diag_log format ["[WarArchitect BECTI MOVE] DETOUR class=%1 target=%2",typeOf _v,_target];};
     };
    };
    // Request a real nearby repair vehicle; native BECTI repair FSM performs the service.
    if (damage _v>.4 && {serverTime>(_v getVariable ["WarArchitect_repairRequestAt",0])}) then {
     _v setVariable ["WarArchitect_repairRequestAt",serverTime+90];
     private _support=vehicles select {alive _x && {local _x} && {canMove _x} && {getRepairCargo _x>0} && {alive driver _x} && {side group driver _x==side _g} && {_x distance2D _v<1500} && {!([_x] call NeroOP_fnc_campaignPlayerControl)}};
     if (!_contact && {count _support>0}) then {private _r=_support#0;driver _r doMove (getPosATL _v getPos [12,getDir _v+90]);diag_log format ["[WarArchitect BECTI REPAIR] REQUEST class=%1 support=%2",typeOf _v,typeOf _r];};
     if (_contact) then {private _cover=allGroups select {local _x && {side _x==side _g} && {_x!=_g} && {leader _x distance2D _v<800} && {!([_x] call NeroOP_fnc_campaignPlayerControl)}};if (count _cover>0) then {{if (alive _x && {local _x}) then {_x reveal [_enemy,3];_x doTarget _enemy;};} forEach units (_cover#0);};};
    };
   };
  };
 } forEach vehicles;
 sleep 3;
};
NeroOP_campFinished=true;
