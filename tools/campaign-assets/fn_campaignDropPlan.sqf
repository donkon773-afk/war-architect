/* Called before charging. Reserve real aircraft; no fallback teleport on failure. */
params ["_side","_requested","_count"];
if (!isServer || {!(_side in [0,1])} || {_count<1} || {_count>12}) exitWith {[]};
private _root=NeroOP_campRoots#_side;
if (_requested==_root || {getNumber(missionConfigFile >> "CfgNeroOperation" >> "DevMode" >> "physicalDrop")!=1}) exitWith {[objNull,objNull,_requested]};
private _flights=missionNamespace getVariable ["NeroOP_deliveryFlights",[]];
_flights=_flights select {!isNull (_x#0)};NeroOP_deliveryFlights=_flights;
if ({(_x#1)==_side} count _flights>=2) exitWith {[]};
private _army=missionConfigFile >> "CfgNeroOperation" >> (["WEST","EAST"]#_side);
private _fighter=getText(_army >> "deliveryFighter");private _transport=getText(_army >> "deliveryTransport");
if (_fighter=="" || {_transport==""} || {!isClass(configFile >> "CfgVehicles" >> _fighter)} || {!isClass(configFile >> "CfgVehicles" >> _transport)} || {NeroOP_campOwners#_root!=_side}) exitWith {[]};
private _graph=[NeroOP_campOwners,NeroOP_campLinks,_root,_side] call NeroOP_fnc_campaignGraph;private _rank=[];
{private _n=_x;private _pos=NeroOP_campPositions#_n;private _safe=!surfaceIsWater _pos && {NeroOP_campOwners findIf {_x==1-_side && {(NeroOP_campPositions#_forEachIndex) distance2D _pos<2200}}<0};
 if (_safe && {(NeroOP_campIntel#_side) findIf {alive (_x#0) && {(_x#1) distance2D _pos<6000} && {(_x#2) || {(_x#0) getVariable ["NeroOP_assetCategory",""] in ["SAM","AAA"]}}}<0}) then {_rank pushBack [_pos distance2D (NeroOP_campPositions#_requested),_n];};
} forEach (_graph#0);
_rank sort true;if (count _rank==0) exitWith {[]};private _drop=(_rank#0)#1;
if !([false,true,_count,{(_x#1)==_side} count _flights,_transport!="",_fighter!="",true] call NeroOP_fnc_campaignDeliveryGate) exitWith {[]};
private _base=NeroOP_campPositions#_root;private _dest=NeroOP_campPositions#_drop;private _dir=_base getDir _dest;private _start=_base getPos [1200,_dir+180];_start set [2,700];
private _plane=createVehicle [_transport,_start,[],0,"FLY"];
private _fighterPos=_start getPos [350,_dir+90];_fighterPos set [2,850];private _escort=createVehicle [_fighter,_fighterPos,[],0,"FLY"];
if (isNull _plane || {isNull _escort}) exitWith {deleteVehicle _plane;deleteVehicle _escort;[]};
{private _v=_x;createVehicleCrew _v;private _old=group driver _v;private _g=createGroup [[west,east]#_side,true];(crew _v) joinSilent _g;if(count units _old==0) then {deleteGroup _old;};_v setVariable ["NeroOP_side",_side,true];_v setVariable ["NeroOP_delivery",true,true];_v setDir _dir;_v setVelocity [sin _dir*130,cos _dir*130,0];_v flyInHeight 650;_g setBehaviourStrong "AWARE";_g setCombatMode "RED";
} forEach [_plane,_escort];
if (!alive driver _plane || {!alive driver _escort} || {count (fullCrew [_plane,"cargo",true])<_count}) exitWith {{private _g=group driver _x;{deleteVehicle _x;} forEach crew _x;deleteVehicle _x;deleteGroup _g;} forEach [_plane,_escort];[]};
group driver _plane setCombatMode "BLUE";{_x disableAI "AUTOCOMBAT";} forEach crew _plane;_plane lock 2;_escort lock 2;
_plane setVariable ["NeroOP_cmMultiplier",12,true];_plane setVariable ["NeroOP_cmBonus",.12,true];_escort setVariable ["NeroOP_escortFor",_plane,true];[_escort] call NeroOP_fnc_airArm;
NeroOP_deliveryFlights pushBack [_plane,_side];
[_plane,_escort,_drop]
