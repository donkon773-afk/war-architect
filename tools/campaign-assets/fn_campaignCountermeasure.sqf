/* Owner-local missile guidance only. Native flare geometry and lock rules still apply. */
params ["_v"];
if (!isServer || {!alive _v} || {serverTime-(_v getVariable ["NeroOP_serverCMAt",-10])<5}) exitWith {};
private _stock=0;{if (toLower (_x#0) find "flare">=0 || {toLower (_x#0) find "chaff">=0} || {toLower (_x#0) find "countermeasure">=0}) then {_stock=_stock+(_x#2);};} forEach magazinesAllTurrets [_v,true];
private _before=_v getVariable ["NeroOP_serverCMStock",_v getVariable ["NeroOP_cmInitialStock",-1]];if (_before<0 || {_stock>=_before}) exitWith {_v setVariable ["NeroOP_serverCMStock",_stock];};
_v setVariable ["NeroOP_serverCMStock",_stock];_v setVariable ["NeroOP_serverCMAt",serverTime];
NeroOP_campMissiles=NeroOP_campMissiles select {!isNull (_x#0) && {alive (_x#0)}};
{_x params ["_missile","_launcher"];if (local _missile && {missileTarget _missile==_v} && {getNumber(configFile >> "CfgAmmo" >> typeOf _missile >> "ace_missileguidance" >> "enabled")!=1}) then {private _chance=[_launcher distance _v,_launcher getVariable ["NeroOP_radarSupported",false]] call NeroOP_fnc_campaignCMChance;if (random 1<((_chance+(_v getVariable ["NeroOP_cmBonus",0])) min .85)) then {_missile setMissileTarget objNull;};};} forEach NeroOP_campMissiles;
