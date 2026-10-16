params ["_p","_launcher","_cfg","_side"];
if (isNull _p || {!local _p} || {_p getVariable ["NeroMS_controlled",false]}) exitWith {};
_p setVariable ["NeroMS_controlled",true];_p setVariable ["NeroMS_ballistic",true,true];
// Let the native launch/GPS handler supply its target first; never invent a hostile target.
private _until=time+2;private _target=[];
// ACE GPS uses local PB/TOO data rather than vanilla missileTargetPos.
// Snapshot only the actual player's launch on this owner; never reuse another player's GPS data for AI.
private _aceTarget=[];private _operator=effectiveCommander _launcher;
if (hasInterface && {!isNull _operator} && {isPlayer _operator} && {local _operator} && {!isNil "ace_missileguidance_fnc_gps_getAttackData"}) then {
 private _data=[] call ace_missileguidance_fnc_gps_getAttackData;
 if (_data isEqualType [] && {count _data>=1} && {(_data#0) isEqualType []} && {count (_data#0)==3} && {!((_data#0) isEqualTo [0,0,0])}) then {_aceTarget=+(_data#0);};
};
waitUntil {sleep .02;private _object=missileTarget _p;_target=if (!isNull _object) then {getPosASL _object} else {missileTargetPos _p};if ((count _target!=3 || {_target isEqualTo [0,0,0]}) && {count _aceTarget==3}) then {_target=_aceTarget;};isNull _p || {time>_until} || {count _target==3 && {!(_target isEqualTo [0,0,0])}}};
if (isNull _p || {!local _p}) exitWith {};
if (count _target!=3 || {_target isEqualTo [0,0,0]}) exitWith {diag_log "[NeroMS] KINZHAL_NO_TARGET: native projectile retained";};
private _cep=getNumber(_cfg >> "cep");private _angle=random 360;
// Rayleigh radial scatter: median radius = CEP, not uniform radius.
private _error=_cep*sqrt (-(ln ((random 1) max .000001))/ln 2);
_target=_target vectorAdd [sin _angle*_error,cos _angle*_error,0];
private _start=getPosASL _p;private _range=_start distance2D _target;
if (_range<1000) exitWith {diag_log "[NeroMS] KINZHAL_SHORT_RANGE: native projectile retained";};
private _launchSpeed=vectorMagnitude velocity _launcher max vectorMagnitude velocity _p;
private _born=time;private _last=time;private _travel=0;private _u=0;
private _horizontal=_target vectorDiff _start;_horizontal set [2,0];private _axis=vectorNormalized _horizontal;
_p setMissileTarget objNull;
if (!isNil "NeroOP_fnc_campaignCruiseTrack") then {[_p,_launcher,_side] spawn NeroOP_fnc_campaignCruiseTrack;};
diag_log format ["[NeroMS] KINZHAL_START range=%1 speed=%2 altitude=%3 target=%4",_range,_launchSpeed,_start#2,_target];
while {!isNull _p && {alive _p} && {local _p} && {time-_born<600}} do {
 private _dt=(time-_last) max .001 min .1;_last=time;
 private _pos=getPosASL _p;
 // Progress derives from actual position, never from moving the missile with setPos.
 _u=(((_pos vectorDiff _start) vectorDotProduct _axis)/_range) max 0 min 1;
 private _profile=[time-_born,_u,_range,_launchSpeed,getNumber(_cfg >> "maximum"),getNumber(_cfg >> "boostSeconds")] call NeroMS_fnc_curve;
 private _look=(_u+(200/_range)) min 1;
 private _ahead=_start vectorAdd (_horizontal vectorMultiply _look);
 private _height=(_start#2)+((_target#2)-(_start#2))*_look+4*(40000 min (_range*.30))*_look*(1-_look);
 _ahead set [2,_height];
 if (_u>.98 || {_p distance _target<1000}) then {_ahead=_target;};
 private _wanted=vectorNormalized (_ahead vectorDiff _pos);private _current=vectorNormalized velocity _p;
 // Bounded turn rate: no low-altitude zigzag or instantaneous missile reversal.
 private _turn=acos ((_current vectorDotProduct _wanted) max -1 min 1);
 private _blend=if (_turn<.01) then {1} else {((_dt*12)/_turn) min 1};
 private _dir=vectorNormalized ((_current vectorMultiply (1-_blend)) vectorAdd (_wanted vectorMultiply _blend));
 _p setVectorDir _dir;_p setVelocity (_dir vectorMultiply (_profile#0));
 if (time-(_p getVariable ["NeroMS_logAt",-100])>=1) then {_p setVariable ["NeroMS_logAt",time];diag_log format ["[NeroMS] KINZHAL_SAMPLE age=%1 progress=%2 speed=%3 altitudeASL=%4",time-_born,_u,vectorMagnitude velocity _p,_pos#2];};
 sleep .01;
};
// Loss of locality hands control to the engine; never delete a live round merely because the loop ended.
diag_log format ["[NeroMS] KINZHAL_END age=%1 null=%2 local=%3",time-_born,isNull _p,local _p];
