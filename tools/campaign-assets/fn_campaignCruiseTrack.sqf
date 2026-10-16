/* Radar target enters flight after tube clearance. Geometry loss is not interception. */
params ["_p","_launcher","_side"];
if (!(_side in [0,1]) || {isNull _p} || {!local _p} || {_p getVariable ["NeroOP_tracked",false]}) exitWith {};
_p setVariable ["NeroOP_tracked",true];_p setVariable ["NeroOP_side",_side,true];_p setVariable ["NeroOP_source",_launcher,true];private _born=time;diag_log format ["[NeroOP CRUISE] WATCH source=%1 ammo=%2",typeOf _launcher,typeOf _p];private _until=time+30;
waitUntil {sleep .05;isNull _p || {!alive _p} || {time>_until} || {((getPosATL _p)#2)>70 && {_p distance2D _launcher>250}}};
if (isNull _p || {!alive _p} || {!local _p} || {time>_until}) exitWith {diag_log format ["[NeroOP CRUISE] EARLY END source=%1 age=%2 null=%3",typeOf _launcher,time-_born,isNull _p];};
private _active=missionNamespace getVariable ["NeroOP_cruiseActive",0];if (_active>=48) exitWith {diag_log "[NeroOP CRUISE] radar proxy budget exceeded; physical missile preserved";};NeroOP_cruiseActive=_active+1;
private _proxyClass=getText(configFile >> "CfgNeroMissileProfiles" >> typeOf _p >> (["proxyWest","proxyEast"]#_side));if (_proxyClass=="") then {_proxyClass=["NeroOP_CruiseTrack_W","NeroOP_CruiseTrack_E"]#_side;};
private _proxy=createVehicle [_proxyClass,ASLToATL ((getPosASL _p) vectorDiff ((vectorNormalized velocity _p) vectorMultiply 30)),[],0,"FLY"];
if (isNull _proxy) exitWith {NeroOP_cruiseActive=(NeroOP_cruiseActive-1) max 0;};_proxy disableCollisionWith _p;_p disableCollisionWith _proxy;_proxy disableCollisionWith _launcher;_launcher disableCollisionWith _proxy;
createVehicleCrew _proxy;{_x disableAI "MOVE";_x disableAI "AUTOCOMBAT";} forEach crew _proxy;_proxy setFuel 1;
_proxy setVariable ["NeroOP_cruise",true,true];_proxy setVariable ["NeroOP_side",_side,true];_proxy setVariable ["NeroOP_projectile",_p];_proxy setVariable ["NeroOP_launcher",_launcher];_proxy setVariable ["NeroMS_ballistic",_p getVariable ["NeroMS_ballistic",false],true];
_proxy addEventHandler ["HandleDamage",{params ["_v","_selection","_damage","_source","_projectile"];
 if (_projectile=="") exitWith {0};
 if (_projectile!="" && {!(_source isEqualTo (_v getVariable ["NeroOP_launcher",objNull]))}) then {_v setVariable ["NeroOP_weaponHit",true];};_damage
}];
_proxy addEventHandler ["IncomingMissile",{params ["_proxy"];private _p=_proxy getVariable ["NeroOP_projectile",objNull];_p setVariable ["NeroOP_interceptorUntil",time+4];}];
diag_log format ["[NeroOP CRUISE] TRACK source=%1 pos=%2",typeOf _launcher,getPosATL _p];
private _deadline=time+2400;
while {!isNull _p && {alive _p} && {alive _proxy} && {damage _proxy<.8} && {time<_deadline} && {local _p}} do {
 _proxy setPosASL ((getPosASL _p) vectorDiff ((vectorNormalized velocity _p) vectorMultiply (if (_p getVariable ["NeroMS_ballistic",false]) then {0} else {30})));_proxy setVectorDirAndUp [vectorDir _p,vectorUp _p];_proxy setVelocity velocity _p;sleep (if (_p getVariable ["NeroMS_ballistic",false]) then {.02} else {.1});
};
if (!isNull _p && {alive _p} && {(!alive _proxy || {damage _proxy>=.8})}) then {
 if (_proxy getVariable ["NeroOP_weaponHit",false]) then {private _id=_p getVariable ["NeroMS_flightId",""];deleteVehicle _p;diag_log format ["[NeroOP CRUISE] INTERCEPTED source=%1 weaponHit=true flight=%2",typeOf _launcher,_id];} else {diag_log format ["[NeroOP CRUISE] PROXY LOST source=%1; projectile preserved",typeOf _launcher];};
};
{deleteVehicle _x;} forEach crew _proxy;deleteVehicle _proxy;NeroOP_cruiseActive=((missionNamespace getVariable ["NeroOP_cruiseActive",1])-1) max 0;
