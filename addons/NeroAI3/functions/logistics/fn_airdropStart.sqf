/* Real plane and real local pilot; no invulnerability and no cargo cloning. */
params ["_buyer","_cart","_plan"];
if (!isServer || {!(_plan param [0,false])}) exitWith {objNull};
private _group = group _buyer;private _side = side _group;
private _active = missionNamespace getVariable [format ["NeroWL_dropFlight_%1",_side],objNull];
if (!isNull _active && {alive _active}) exitWith {objNull};
private _plane = createVehicle [_plan # 2,_plan # 4,[],0,"FLY"];
if (isNull _plane) exitWith {objNull};
private _crew = createGroup [_side,true];
if (isNull _crew) exitWith {deleteVehicle _plane;objNull};
private _pilot = _crew createUnit [_plan # 3,_plan # 4,[],0,"NONE"];
if (isNull _pilot) exitWith {deleteVehicle _plane;deleteGroup _crew;objNull};
_pilot moveInDriver _plane;
if (driver _plane != _pilot || {(_plane emptyPositions "cargo") < count _cart}) exitWith {deleteVehicle _pilot;deleteVehicle _plane;deleteGroup _crew;objNull};
_plane setDir ((_plan # 4) getDir (_plan # 5));_plane engineOn true;
_crew setVariable ["NeroAI_isBaseAssetCrew",true,true];_crew setCombatMode "BLUE";_crew setBehaviourStrong "CARELESS";
_pilot disableAI "AUTOCOMBAT";_pilot setSkill 0.8;
_plane flyInHeight 280;_plane flyInHeightASL [_plan # 9,_plan # 9,_plan # 9];
_plane setVariable ["NeroAI_ownerSide",_side,true];_plane setVariable ["NeroWL_deliveryAircraft",true,true];
_plane setVariable ["NeroWL_airdropManifest",[]];_plane setVariable ["NeroWL_airdropPlan",_plan];
_plane setVariable ["NeroWL_supplyExpected",count _cart];
_plane setVariable ["NeroWL_supplyId",(_group getVariable ["NeroWL_pendingPurchase",[]]) param [0,format ["FLIGHT-%1",netId _plane]]];
missionNamespace setVariable [format ["NeroWL_dropFlight_%1",_side],_plane];
_group setVariable ["NeroWL_supplyFlight",_plane,true];
_plane
