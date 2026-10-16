/* Native computer/AI fire destination is delivered by the engine, never UI text. */
if (missionNamespace getVariable ["NeroOP_fpArtilleryHook",false]) exitWith {};
missionNamespace setVariable ["NeroOP_fpArtilleryHook",true];
enableEngineArtillery true;
addMissionEventHandler ["ArtilleryShellFired",{
 params ["_vehicle","_weapon","_ammo","_gunner","_instigator","_artilleryTarget","_targetPosition","_shell"];
 if (_ammo!="Flamingo_CruiseMissile" || {isNull _shell} || {!local _shell} || {!(_targetPosition isEqualType [])} || {count _targetPosition<2} || {_targetPosition#0<0} || {_targetPosition#1<0} || {_targetPosition#0>worldSize} || {_targetPosition#1>worldSize}) exitWith {};
 private _display=[_targetPosition#0,_targetPosition#1,(getTerrainHeightASL _targetPosition)+.5];
 _shell setVariable ["NeroOP_artyTargetASL",_display];
 if (_shell getVariable ["FP5_var_controller",-1]>=0) then {
  private _angle=random 360;private _radius=sqrt(random 1)*14;private _p=[(_display#0)+sin(_angle)*_radius,(_display#1)+cos(_angle)*_radius,0];_p set [2,(getTerrainHeightASL _p)+.5];
  _shell setVariable ["FP5_var_targetASL",_p,true];_shell setVariable ["FP5_var_targetATL",ASLToATL _p,true];_shell setVariable ["FP5_var_routeASL",[_p],true];_shell setVariable ["FP5_var_routeDisplayASL",[_display],true];_shell setVariable ["FP5_var_routeIndex",0,true];_shell setVariable ["FP5_var_routeRevision",1+(_shell getVariable ["FP5_var_routeRevision",0]),true];_shell setMissileTargetPos ASLToATL _p;
 };
 diag_log format ["[NeroOP FP5] COMPUTER TARGET launcher=%1 targetASL=%2",typeOf _vehicle,_display];
}];
