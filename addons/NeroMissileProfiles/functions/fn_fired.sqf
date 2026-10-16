params ["_launcher","_weapon","_muzzle","_mode","_ammo","_mag","_p"];
private _cfg=configFile >> "CfgNeroMissileProfiles" >> _ammo;
if (!isClass _cfg || {isNull _p} || {!local _p}) exitWith {};
private _side=_launcher getVariable ["NeroOP_side",[west,east] find side group effectiveCommander _launcher];
_p setVariable ["NeroOP_side",_side,true];_p setVariable ["NeroOP_source",_launcher,true];
private _kind=getText(_cfg >> "trajectory");
NeroMS_sequence=(missionNamespace getVariable ["NeroMS_sequence",0])+1;
private _flightId=format ["%1-%2-%3",clientOwner,round (diag_tickTime*1000),NeroMS_sequence];_p setVariable ["NeroMS_flightId",_flightId,true];
diag_log format ["[NeroMS] FIRED id=%1 class=%2 source=%3 trajectory=%4",_flightId,_ammo,typeOf _launcher,_kind];
// Artillery shells and native scripted ballistic rounds keep their native flight/submunition logic.
if (_kind=="aeroballistic") then {[_p,_launcher,_cfg,_side] spawn NeroMS_fnc_kinzhal;} else {
 if (getText(configFile >> "CfgAmmo" >> _ammo >> "simulation")=="shotMissile" && {!isNil "NeroOP_fnc_campaignCruiseTrack"}) then {[_p,_launcher,_side] spawn NeroOP_fnc_campaignCruiseTrack;};
};
