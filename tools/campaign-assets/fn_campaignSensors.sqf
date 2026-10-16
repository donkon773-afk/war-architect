/* Local sensor control; never assign the player an AI order. Native sensor tracks drive radar support. */
if (missionNamespace getVariable ["NeroOP_sensorLoopStarted",false]) exitWith {};NeroOP_sensorLoopStarted=true;
waitUntil {sleep 1;missionNamespace getVariable ["NeroOP_campReady",false]};
while {!(missionNamespace getVariable ["NeroOP_campFinished",false])} do {
 private _emitters=vehicles select {alive _x && {isVehicleRadarOn _x}};
 private _vehicles=vehicles select {alive _x && {_x isKindOf "Air" || {_x getVariable ["NeroOP_campaignVehicle",false]}} && {!(_x getVariable ["NeroOP_cruise",false])}};
 {private _v=_x;
  if !(_v getVariable ["NeroOP_sensorInit",false]) then {
   _v setVariable ["NeroOP_sensorInit",true];_v setVehicleReceiveRemoteTargets true;_v setVehicleReportRemoteTargets true;
   if (local _v && {_v isKindOf "Air"} && {!(_v getVariable ["NeroOP_loading",false])} && {!(_v getVariable ["NeroOP_cmAdded",false])}) then {private _cm=magazinesAllTurrets [_v,true] select {toLower (_x#0) find "flare">=0 || {toLower (_x#0) find "chaff">=0} || {toLower (_x#0) find "countermeasure">=0}};{if (_v turretLocal (_x#1)) then {for "_i" from 1 to ((_v getVariable ["NeroOP_cmMultiplier",4])-1) do {_v addMagazineTurret [_x#0,_x#1];};};} forEach _cm;_v setVariable ["NeroOP_cmAdded",true,true];};
   private _stock=0;{if (toLower (_x#0) find "flare">=0 || {toLower (_x#0) find "chaff">=0} || {toLower (_x#0) find "countermeasure">=0}) then {_stock=_stock+(_x#2);};} forEach magazinesAllTurrets [_v,true];_v setVariable ["NeroOP_cmInitialStock",_stock,true];
   _v addEventHandler ["IncomingMissile",{params ["_v","_ammo"];private _a=configFile >> "CfgAmmo" >> _ammo;private _arm=isClass(_a >> "Components" >> "SensorsManagerComponent" >> "Components" >> "AntiRadiationSensorComponent") || {toLower _ammo find "harm">=0} || {toLower _ammo find "kh31p">=0};if (_arm && {local _v} && {!([_v] call NeroOP_fnc_campaignPlayerControl)} && {_v getVariable ["NeroOP_assetCategory",""] in ["SAM","AAA","RADAR"]}) then {_v setVariable ["NeroOP_radarSilentUntil",serverTime+25];_v setVehicleRadar 2;};}];
   _v addEventHandler ["Fired",{params ["_v","_weapon","_muzzle","_mode","_ammo","_mag","_p",["_gunner",objNull]];if (!local _p) exitWith {};
    if (_v isKindOf "Air" && {getText(configFile >> "CfgAmmo" >> _ammo >> "simulation")=="shotCM" || {toLower _mag find "flare">=0} || {toLower _mag find "chaff">=0}}) then {
     if (isNull _gunner) then {_gunner=effectiveCommander _v;};private _at=_v getVariable ["NeroOP_cmAt",-10];if (serverTime-_at>.3 && {serverTime-_at<5}) exitWith {deleteVehicle _p;};
     if (serverTime-_at>=5) then {_v setVariable ["NeroOP_cmAt",serverTime];[_v,_muzzle,_gunner] spawn {params ["_v","_muzzle","_gunner"];private _until=serverTime+5;while {alive _v && {local _v} && {serverTime<_until}} do {if (!isNull _gunner) then {_v setWeaponReloadingTime [_gunner,_muzzle,1];};sleep .05;};if (alive _v && {local _v} && {!isNull _gunner}) then {_v setWeaponReloadingTime [_gunner,_muzzle,0];};};
      if (isServer) then {[_v] call NeroOP_fnc_campaignCountermeasure;} else {if (hasInterface && {vehicle player==_v || {getConnectedUAV player==_v}}) then {[] spawn {sleep .2;[player,"CM",0] remoteExecCall ["NeroOP_fnc_campaignEquipmentAction",2];};};};
      {if (!isServer && {(_x#1) in ["missile","threatmissile"] && {local (_x#0)} && {missileTarget (_x#0)==_v} && {getNumber(configFile >> "CfgAmmo" >> typeOf (_x#0) >> "ace_missileguidance" >> "enabled")!=1}}) then {private _missile=_x#0;private _launcher=_missile getVariable ["NeroOP_source",objNull];private _range=if (isNull _launcher) then {_missile distance _v} else {_launcher distance _v};private _chance=[_range,!isNull _launcher && {_launcher getVariable ["NeroOP_radarSupported",false]}] call NeroOP_fnc_campaignCMChance;if (random 1<_chance) then {_missile setMissileTarget objNull;};};} forEach getSensorThreats _v;
     };
    } else {if (getText(configFile >> "CfgAmmo" >> _ammo >> "simulation")=="shotMissile") then {_p setVariable ["NeroOP_source",_v,true];_p setVariable ["NeroOP_side",_v getVariable ["NeroOP_side",[west,east] find side group effectiveCommander _v],true];if (toLower _mag find "kh55">=0) then {diag_log format ["[NeroOP CRUISE] LAUNCH class=%1 mag=%2 ammo=%3 altitude=%4",typeOf _v,_mag,_ammo,(getPosATL _v)#2];[_p,_v,[west,east] find side group effectiveCommander _v] spawn NeroOP_fnc_campaignCruiseTrack;};if (isServer) then {NeroOP_campMissiles=NeroOP_campMissiles select {!isNull (_x#0) && {alive (_x#0)}};NeroOP_campMissiles pushBack [_p,_v];};};};
   }];
  };
  if (_v isKindOf "Air") then {private _friendly=side group effectiveCommander _v;{private _emitter=_x;if (alive _emitter && {_emitter!=_v} && {isVehicleRadarOn _emitter} && {_v distance _emitter<25000} && {count lineIntersectsSurfaces [getPosASL _v,getPosASL _emitter,_v,_emitter,true,1,"GEOM","NONE"]==0}) then {_friendly reportRemoteTarget [_emitter,3];};} forEach _emitters;};
 } forEach _vehicles;
 sleep 1;
};
