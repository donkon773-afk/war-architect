/* Short bounded detour. No teleport, ownership/player orders rechecked after waiting. */
params ["_v","_g","_target"];
if (getNumber(missionConfigFile >> "CfgNeroOperation" >> "DevMode" >> "coordinatedAI")!=1 || {!local _g} || {!alive driver _v} || {[_g] call NeroOP_fnc_campaignPlayerControl} || {_v getVariable ["NeroOP_repairBusy",false]} || {_v getVariable ["NeroOP_avoidBusy",false]}) exitWith {};
_v setVariable ["NeroOP_avoidBusy",true];private _origin=getPosATL _v;private _found=[];
{private _p=_origin getPos [20,getDir _v+_x];if (!surfaceIsWater _p && {(surfaceNormal _p)#2>.9} && {count lineIntersectsSurfaces [getPosASL _v vectorAdd [0,0,1],ATLToASL _p vectorAdd [0,0,1],_v,objNull,true,1,"GEOM","NONE"]==0}) exitWith {_found=_p;};} forEach [65,-65,100,-100];
if (count _found>0) then {private _wp=_g addWaypoint [_found,3,1];_wp setWaypointType "MOVE";_g setCurrentWaypoint _wp;_v limitSpeed 15;sleep 8;if (local _g && {!([_g] call NeroOP_fnc_campaignPlayerControl)} && {(_g getVariable ["NeroOP_campTarget",-1])==_target}) then {_v limitSpeed getNumber(missionConfigFile >> "CfgNeroOperation" >> "Gameplay" >> "vehicleSpeed");_v setVariable ["NeroOP_groundTarget",-1];};};
_v setVariable ["NeroOP_avoidBusy",false];
