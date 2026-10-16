/* Programmable fuse + physical forward fragments. Never apply synthetic damage or guaranteed kills. */
params ["_p","_launcher","_target",["_gunner",objNull]];
if (isNull _p || {!local _p} || {isNull _target} || {!alive _target}) exitWith {};
private _active=missionNamespace getVariable ["NeroOP_aheadActive",0];
if (_active>=128) exitWith {};private _fuse=[getPosASL _p,velocity _p,getPosASL _target,velocity _target] call NeroOP_fnc_campaignADFuse;
if (_fuse<0) exitWith {};NeroOP_aheadActive=_active+1;
private _until=diag_tickTime+_fuse;private _start=getPosASL _p;
waitUntil {sleep .01;isNull _p || {!local _p} || {diag_tickTime>=_until}};
// A manoeuvring target outside the envelope must not erase the original shell.
if (!isNull _p && {local _p} && {alive _target} && {getPosASL _p distance _start>100} && {_p distance _target<=120}) then {
 private _pos=getPosASL _p;private _axis=vectorNormalized velocity _p;
 private _toTarget=(getPosASL _target) vectorDiff _pos;
 private _forward=_toTarget vectorDotProduct _axis;
 private _lateral=vectorMagnitude (_toTarget vectorDiff (_axis vectorMultiply _forward));
 if (_forward<=0 || {_lateral>12+_forward*.12}) exitWith {};
 // The cone follows the programmed ballistic axis, not a homing turn toward the target.
 private _up=if (abs(_axis vectorDotProduct [0,0,1])>.95) then {[0,1,0]} else {[0,0,1]};
 private _right=vectorNormalized (_axis vectorCrossProduct _up);_up=vectorNormalized (_right vectorCrossProduct _axis);
 deleteVehicle _p;
 private _flash=createVehicle ["NeroAD_AheadBurst",ASLToATL _pos,[],0,"CAN_COLLIDE"];_flash setPosASL _pos;if (isServer) then {_flash setShotParents [_launcher,_gunner];};triggerAmmo _flash;
 for "_i" from 1 to 18 do {private _angle=random 360;private _spread=sqrt(random 1)*.12;private _dir=vectorNormalized (_axis vectorAdd (_right vectorMultiply (cos _angle*_spread)) vectorAdd (_up vectorMultiply (sin _angle*_spread)));
  private _fragment=createVehicle ["NeroAD_AheadFragment",ASLToATL _pos,[],0,"CAN_COLLIDE"];_fragment setPosASL _pos;if (isServer) then {_fragment setShotParents [_launcher,_gunner];};_fragment setVelocity (_dir vectorMultiply 1100);
 };
};
NeroOP_aheadActive=((missionNamespace getVariable ["NeroOP_aheadActive",1])-1) max 0;
