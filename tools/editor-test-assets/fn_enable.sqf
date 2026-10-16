params [["_logic",objNull],["_units",[]],["_activated",true]];
if (!_activated || {is3DEN} || {missionNamespace getVariable ["NeroSandbox_started",false]}) exitWith {};
// Full Operations missions register and start their own functions. Never overwrite them.
if (getText(missionConfigFile >> "CfgNeroOperation" >> "type")=="frontlineCampaign") exitWith {diag_log "[NeroSandbox] full Operations mission owns systems";};
NeroSandbox_started=true;
diag_log "[NeroSandbox] AD/AHEAD and observed-target missile assistance enabled 20261014-r2";
{
 missionNamespace setVariable ["NeroOP_fnc_"+_x,missionNamespace getVariable ("NeroSandbox_fnc_"+_x)];
} forEach ["campaignAirDefense","campaignADGate","campaignADFuse","campaignADMagazine","campaignADAhead","campaignMissileCompatible","campaignMissileGate","campaignMissileEngage","campaignPlayerControl","campaignCruiseTrack","campaignSensors","campaignCountermeasure","campaignCMChance","airAvionics","airHelmet","zeusPrepare","zeusServer","zeusClient"];
NeroOP_campMissiles=[];NeroOP_campFinished=false;NeroOP_campReady=true;
[] spawn NeroOP_fnc_campaignAirDefense;
[] spawn NeroOP_fnc_campaignSensors;
[] spawn NeroSandbox_fnc_airCombat;
if (isServer) then {[] call NeroOP_fnc_zeusPrepare;[] spawn NeroOP_fnc_zeusServer;};
if (hasInterface) then {
 [] spawn NeroOP_fnc_zeusClient;
 [] spawn {while {true} do {if (!isNull player && {vehicle player!=player}) then {[vehicle player,player] call NeroOP_fnc_airAvionics;[vehicle player,player] call NeroOP_fnc_airHelmet;};sleep 1;};};
};
// Opt-in module marks placed defenses for the sensor loop; objects placed later in Zeus are included.
while {!(missionNamespace getVariable ["NeroOP_campFinished",false])} do {
 {if (local _x && {!(_x isKindOf "Air")} && {isClass(configFile >> "CfgNeroAirDefense" >> typeOf _x) || {getText(configFile >> "CfgVehicles" >> typeOf _x >> "NeroAD_original")!=""}}) then {_x setVariable ["NeroOP_campaignVehicle",true];};} forEach vehicles;
 sleep 1;
};
