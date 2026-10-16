/* Owner-local fire control, shared radar frames. Separate from transport, intel and CM loops. */
if (missionNamespace getVariable ["NeroOP_adLoopStarted",false]) exitWith {};NeroOP_adLoopStarted=true;
waitUntil {sleep 1;missionNamespace getVariable ["NeroOP_campReady",false]};
private _cached=[];private _scanAt=-10;
while {!(missionNamespace getVariable ["NeroOP_campFinished",false])} do {
 if (serverTime-_scanAt>=2) then {_scanAt=serverTime;_cached=vehicles select {alive _x && {!(_x isKindOf "Air")} && {getText(configFile >> "CfgNeroAirDefense" >> getText(configFile >> "CfgVehicles" >> typeOf _x >> "NeroAD_original") >> "category")!="" || {isClass(configFile >> "CfgNeroAirDefense" >> typeOf _x)}}};};private _all=_cached select {alive _x};
 {private _v=_x;if (local _v) then {
  private _original=getText(configFile >> "CfgVehicles" >> typeOf _v >> "NeroAD_original");if (_original=="") then {_original=typeOf _v;};private _cfg=configFile >> "CfgNeroAirDefense" >> _original;
  private _category=getText(_cfg >> "category");private _side=[west,east] find side group effectiveCommander _v;private _controlled=[_v] call NeroOP_fnc_campaignPlayerControl;
  _v setVariable ["NeroOP_adOriginal",_original];_v setVariable ["NeroOP_adManaged",true];
  if (_category=="RADAR") then {
   _v setVehicleReportRemoteTargets true;
   if (!_controlled) then {_v setVehicleRadar (if (serverTime>=(_v getVariable ["NeroOP_radarSilentUntil",0])) then {1} else {2});};
   private _tracks=if (isVehicleRadarOn _v) then {getSensorTargets _v select {(_x#1)=="air" && {"activeradar" in (_x#3)} && {(_x#2)!="friendly"} && {alive (_x#0)} && {[_side,_x#0] call NeroOP_fnc_campaignIFF} && {_v distance (_x#0)<=getNumber(_cfg >> "radarRange")} && {count lineIntersectsSurfaces [getPosASL _v vectorAdd [0,0,3],getPosASL (_x#0),_v,_x#0,true,1,"GEOM","NONE"]==0}}} else {[]};
   _v setVariable ["NeroOP_adRadarFrame",[serverTime,_side,getNumber(_cfg >> "radarRange"),_tracks],true];_v setVariable ["NeroOP_radarContacts",count _tracks,true];if (_side in [0,1]) then {{private _t=_x#0;if ([_side,_t] call NeroOP_fnc_campaignIFF) then {_t confirmSensorTarget [[west,east]#_side,true];};} forEach _tracks;};if (count _tracks>0 && {!_controlled}) then {private _target=(_tracks#0)#0;{if (local _x) then {_x reveal [_target,4];_x doTarget _target;};} forEach crew _v;};
  };
 };} forEach _all;
 {private _v=_x;private _original=getText(configFile >> "CfgVehicles" >> typeOf _v >> "NeroAD_original");if (_original=="") then {_original=typeOf _v;};_v setVariable ["NeroOP_adOriginal",_original];private _cfg=configFile >> "CfgNeroAirDefense" >> _original;
   if !(_v getVariable ["NeroOP_adInit",false]) then {
    _v setVariable ["NeroOP_adInit",true];_v setVariable ["NeroOP_adMagazineLinked",false];
    if (local _v && {getNumber(configFile >> "CfgVehicles" >> typeOf _v >> "isUav")==1} && {!([_v] call NeroOP_fnc_campaignPlayerControl)}) then {_v setAutonomous true;};
    _v addEventHandler ["IncomingMissile",{params ["_v","_ammo"];private _a=configFile >> "CfgAmmo" >> _ammo;private _arm=isClass(_a >> "Components" >> "SensorsManagerComponent" >> "Components" >> "AntiRadiationSensorComponent") || {toLower _ammo find "harm">=0} || {toLower _ammo find "kh31p">=0};if (_arm && {local _v} && {!([_v] call NeroOP_fnc_campaignPlayerControl)}) then {_v setVariable ["NeroOP_radarSilentUntil",serverTime+25];_v setVehicleRadar 2;};}];
    _v addEventHandler ["Fired",{params ["_v","_weapon","_muzzle","_mode","_ammo","_mag","_p",["_gunner",objNull]];
     if (!local _p) exitWith {};private _cfg=configFile >> "CfgNeroAirDefense" >> (_v getVariable ["NeroOP_adOriginal",typeOf _v]);private _t=missileTarget _p;if (isNull _t && {!isNull _gunner}) then {_t=assignedTarget _gunner;};
     if (!isNull _t && {!([[west,east] find side group effectiveCommander _v,_t] call NeroOP_fnc_campaignIFF)}) exitWith {deleteVehicle _p;};
     if (getNumber(_cfg >> "stationary")==1 && {getText(configFile >> "CfgAmmo" >> _ammo >> "simulation")=="shotMissile"} && {!isNull _t} && {_v distance _t>getNumber(_cfg >> "localRange")}) then {
      private _records=_v getVariable ["NeroOP_adAuthorized",[]];private _valid=_records findIf {(_x#0)==_t && {alive (_x#1)} && {isVehicleRadarOn (_x#1)} && {_v distance (_x#1)<=3000} && {serverTime-(_x#2)<=2} && {_t distance (_x#1)<=(_x#3)} && {private _frame=(_x#1) getVariable ["NeroOP_adRadarFrame",[-10,-1,0,[]]];serverTime-(_frame#0)<=2 && {(_frame#3) findIf {(_x#0)==_t}>=0}}}>=0;
      if (!_valid) then {deleteVehicle _p;private _pair=(getArray(_cfg >> "magazinePairs")) select {_mag in _x};if (count _pair>0) then {private _path=if (isNull _gunner) then {[0]} else {_v unitTurret _gunner};_v addMagazineTurret [(_pair#0)#0,_path,1];};diag_log format ["[NeroOP AD] denied stale/outside radar launch class=%1",typeOf _v];};
     };
     if (getNumber(_cfg >> "ahead")==1 && {getText(configFile >> "CfgAmmo" >> _ammo >> "simulation")=="shotBullet"}) then {private _target=if (isNull _gunner) then {objNull} else {assignedTarget _gunner};if (isNull _target) then {_target=_v getVariable ["NeroOP_adTarget",objNull];};if (!isNull _target && {_target isKindOf "Air"} && {_v distance _target<=getNumber(_cfg >> "gunRange")}) then {[_p,_v,_target,_gunner] spawn NeroOP_fnc_campaignADAhead;};};
    }];
   };
 } forEach _all;
 private _radars=_all select {private _o=getText(configFile >> "CfgVehicles" >> typeOf _x >> "NeroAD_original");if (_o=="") then {_o=typeOf _x;};getText(configFile >> "CfgNeroAirDefense" >> _o >> "category")=="RADAR" && {isVehicleRadarOn _x}};
 {private _v=_x;private _o=_v getVariable ["NeroOP_adOriginal",typeOf _v];private _cfg=configFile >> "CfgNeroAirDefense" >> _o;if (getNumber(_cfg >> "stationary")==1 && {getText(_cfg >> "category") in ["AAA","SAM"]}) then {private _side=[west,east] find side group effectiveCommander _v;private _linked=_radars findIf {private _f=_x getVariable ["NeroOP_adRadarFrame",[-10,-1,0,[]]];(_f#1)==_side && {_side in [0,1]} && {_v distance _x<=3000} && {serverTime-(_f#0)<=2}}>=0;[_v,_linked] call NeroOP_fnc_campaignADMagazine;};} forEach _all;
 {private _v=_x;if (local _v) then {
  private _original=_v getVariable ["NeroOP_adOriginal",typeOf _v];private _cfg=configFile >> "CfgNeroAirDefense" >> _original;private _category=getText(_cfg >> "category");
  if (_category in ["AAA","SAM"]) then {
   private _static=getNumber(_cfg >> "stationary")==1;private _localRange=getNumber(_cfg >> "localRange");private _gunRange=getNumber(_cfg >> "gunRange");private _missileRange=getNumber(_cfg >> "missileRange");private _side=[west,east] find side group effectiveCommander _v;
   private _controlled=[_v] call NeroOP_fnc_campaignPlayerControl;if (getNumber(configFile >> "CfgVehicles" >> typeOf _v >> "isUav")==1 && {!isAutonomous _v}) then {_controlled=true;};private _nodes=_radars select {private _f=_x getVariable ["NeroOP_adRadarFrame",[-10,-1,0,[]]];(_f#1)==_side && {_side in [0,1]} && {_v distance _x<=3000} && {serverTime-(_f#0)<=2}};
   if (_static) then {
    [_v,count _nodes>0] call NeroOP_fnc_campaignADMagazine;
    _v setVehicleReceiveRemoteTargets (count _nodes>0);_v setVehicleReportRemoteTargets false;
    if (!_controlled) then {_v setVehicleRadar (if (count _nodes==0 && {serverTime>=(_v getVariable ["NeroOP_radarSilentUntil",0])}) then {1} else {2});};
   };
   private _candidates=[];private _authorized=[];
   {private _t=_x#0;if (alive _t && {(_x#1)=="air"} && {(_x#2)!="friendly"} && {!_static || {_v distance _t<=_localRange}} && {(_x#3) findIf {_x in ["activeradar","ir","visual"]}>=0}) then {_candidates pushBack [_v distance _t,_t,objNull,false];};} forEach getSensorTargets _v;
   {private _radar=_x;private _frame=_radar getVariable ["NeroOP_adRadarFrame",[-10,-1,0,[]]];
    {private _t=_x#0;private _gate=[_static,_missileRange>0,_localRange,_v distance _t,_v distance _radar,_frame#2,_radar distance _t,serverTime-(_frame#0),alive _radar && {isVehicleRadarOn _radar},(_frame#1)==_side,alive _t && {count lineIntersectsSurfaces [getPosASL _radar vectorAdd [0,0,3],getPosASL _t,_radar,_t,true,1,"GEOM","NONE"]==0}] call NeroOP_fnc_campaignADGate;
     if (_gate#0) then {_authorized pushBack [_t,_radar,_frame#0,_frame#2];_candidates pushBack [_v distance _t,_t,_radar,true];};
    } forEach (_frame#3);
   } forEach _nodes;
   // Unknown IFF is not permission to fire on an allied vehicle.
   _candidates=_candidates select {[_side,_x#1] call NeroOP_fnc_campaignIFF};
   _v setVariable ["NeroOP_adAuthorized",_authorized,true];private _rank=[];{_rank pushBack [(_x#0)-(if (getNumber(configFile >> "CfgNeroAirDefense" >> "patriotBMD")==1 && {toLower _original in ["b_sam_system_03_f","i_e_sam_system_03_f"]} && {(_x#1) getVariable ["NeroMS_ballistic",false]}) then {100000} else {0}),_forEachIndex];} forEach _candidates;_rank sort true;
   private _old=_v getVariable ["NeroOP_adTarget",objNull];private _same=_candidates findIf {(_x#1)==_old};private _chosen=if (count _candidates==0) then {[]} else {if (_same>=0) then {_candidates#_same} else {_candidates#((_rank#0)#1)}};
   if (count _rank>0 && {getNumber(configFile >> "CfgNeroAirDefense" >> "patriotBMD")==1} && {toLower _original in ["b_sam_system_03_f","i_e_sam_system_03_f"]} && {(_rank#0)#0<0}) then {_chosen=_candidates#((_rank#0)#1);};
   if (count _chosen>0) then {private _preferred=_candidates findIf {(_x#1)==(_chosen#1) && {_x#3}};if (_preferred>=0) then {_chosen=_candidates#_preferred;};};
   _v setVariable ["NeroOP_radarSupported",count _chosen>0 && {(_chosen#3)},true];
   if (_controlled && {_static}) then {{if (local _x && {_x getVariable ["NeroOP_adCrewManaged",false]}) then {_x enableAI "AUTOTARGET";_x setUnitCombatMode "YELLOW";_x setVariable ["NeroOP_adCrewManaged",false];};} forEach crew _v;};
   if (!_controlled) then {
    if (_static) then {{if (local _x) then {_x setVariable ["NeroOP_adCrewManaged",true];_x enableAI "AUTOTARGET";};} forEach crew _v;};
    if (count _chosen>0) then {_chosen params ["_range","_target","_radar","_external"];_v setVariable ["NeroOP_adTarget",_target,true];
     if (_target!=_old || {serverTime-(_v getVariable ["NeroOP_adAimAt",-10])>2}) then {_v setVariable ["NeroOP_adAimAt",serverTime];{if (alive _x && {local _x}) then {_x reveal [_target,4];_x doTarget _target;_x doWatch _target;};} forEach crew _v;};
     private _limit=if (_static && {_external} && {_missileRange>0}) then {(_radar getVariable ["NeroOP_adRadarFrame",[0,0,0,[]]])#2} else {_localRange};
     if (_static) then {{if (local _x) then {private _salvo=_v getVariable ["NeroOP_bmdSalvo",[objNull,0]];private _spent=(_salvo#0)==_target && {(_salvo#1)>=2};private _mode=if (_range<=_limit && {!_spent}) then {"YELLOW"} else {"BLUE"};if (unitCombatMode _x!=_mode) then {_x setUnitCombatMode _mode;};};} forEach crew _v;};
     private _salvo=_v getVariable ["NeroOP_bmdSalvo",[objNull,0]];private _spent=(_salvo#0)==_target && {(_salvo#1)>=2};
     if (!_spent && {_range<=_limit} && {canFire _v} && {serverTime-(_v getVariable ["NeroOP_adFireAt",-10])>=1}) then {_v setVariable ["NeroOP_adFireAt",serverTime]; {if (alive _x && {local _x}) then {_x doFire _target;};} forEach crew _v;};
     if (_missileRange>0 && {_range<=_limit}) then {[_v,_target,_limit] call NeroOP_fnc_campaignMissileEngage;};
    } else {_v setVariable ["NeroOP_adTarget",objNull];if (_static) then {{if (local _x) then {_x setUnitCombatMode "BLUE";};} forEach crew _v;};if (!isNull _old && {_static}) then {{if (local _x) then {_x doTarget objNull;_x doWatch objNull;_x doFire objNull;};} forEach crew _v;};};
   };
  };
 };} forEach _all;
 sleep .2;
};
