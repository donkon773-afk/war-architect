/* Server-only transaction. The caller enters an isNil critical section. */
params ["_side","_index","_parent",["_buyer",objNull],["_restore",[]],["_empty",false]];
if (!isServer || {NeroOP_campFinished} || {!(_side in [0,1])}) exitWith {objNull};
private _cfg=missionConfigFile >> "CfgNeroOperation";private _settings=_cfg >> "Equipment";private _rows=NeroOP_campShop#_side;
if (_index<0 || {_index>=count _rows} || {floor _index!=_index}) exitWith {objNull};
private _newCrew=getNumber(_cfg >> "DevMode" >> "independentCrew")==1;
if (((_rows#_index)#1)==0 && {((_rows#_index)#3)!="UAV"} && {count _restore==12 || {count _restore==0 && {_newCrew || {_empty}}}}) exitWith {[_side,_index,_parent,_buyer,_restore,_empty] call NeroOP_fnc_campaignBuyCrew};
private _row=_rows#_index;_row params ["_class","_kind","_price","_category"];private _role=_row param [5,_category];
private _drone=_category=="UAV" || {getNumber(configFile >> "CfgVehicles" >> _class >> "isUav")==1};
private _support=_category in ["ARTILLERY_SP","ARTILLERY_STATIC","MLRS","AAA","SAM","RADAR","STATIC"];
private _artillery=_category in ["ARTILLERY_SP","ARTILLERY_STATIC","MLRS"];private _supportCrew=if (_class isKindOf "StaticWeapon") then {1} else {2};
private _loading=count _restore>0;private _ai=if (_loading) then {_restore#8} else {isNull _buyer};
if (!_loading && {isNull _parent || {!local _parent && {_ai}} || {!(_parent getVariable ["NeroOP_campGroup",false])} || {_ai && {[_parent] call NeroOP_fnc_campaignPlayerControl}}}) exitWith {objNull};
private _special=if (toLower _class find "fp5">=0) then {0} else {if (toLower _class find "tu95">=0) then {1} else {-1}};
if (!_loading && {_special>=0} && {_side!=_special || {!([serverTime,NeroOP_campSpecialUntil#_special,{alive (_x#4) && {(_x#4) getVariable ["NeroOP_specialKind",-1]==_special}} count NeroOP_campEquipment] call NeroOP_fnc_campaignSpecialGate)}}) exitWith {objNull};
private _key=if (_loading) then {_restore#2} else {_parent getVariable ["NeroOP_groupKey",-1]};
if (_key<1) exitWith {objNull};
private _candidates=if (isNull _parent) then {[]} else {units _parent select {alive _x && {!isPlayer _x} && {!([_x] call NeroOP_fnc_campaignPlayerControl)} && {!(_x getVariable ["ACE_isUnconscious",false])} && {_x getVariable ["NeroOP_campUnit",false]} && {_x!=leader _parent} && {vehicle _x==_x || {((assignedVehicleRole _x) param [0,""])=="cargo"}}}};
private _count=if (isNull _parent) then {0} else {{alive _x && {_x getVariable ["NeroOP_campUnit",false]}} count units _parent};
private _source=-1;private _position=[];private _graph=[NeroOP_campOwners,NeroOP_campLinks,NeroOP_campRoots#_side,_side] call NeroOP_fnc_campaignGraph;
private _reserve=if (_ai) then {2*getNumber(_cfg >> "reinforcementCost")+getNumber(_cfg >> "captureCost")} else {0};
if (_loading) then {_position=+(_restore#3);_source=NeroOP_campRoots#_side;} else {
 private _funds=(_graph#0) select {(NeroOP_campStocks#_x)>=_price+_reserve};
 if (_ai) then {
  private _near=(_graph#0) findIf {leader _parent distance2D (NeroOP_campPositions#_x)<(NeroOP_campRadii#_x)+180};
  if (_near>=0 && {count _funds>0}) then {private _node=(_graph#0)#_near;if ((NeroOP_campStocks#_node)>=_price+_reserve) then {_source=_node;_position=getPosATL leader _parent;};};
 } else {
  _source=[_buyer,_side,_price,true] call NeroOP_fnc_campaignWarehouse;if (_source>=0) then {_position=NeroOP_campPositions#_source;};
 };
};
if (_source<0 || {count _position<2}) exitWith {objNull};
if (!_loading && {_ai} && {!( [false,_parent getVariable ["NeroOP_liftBusy",false],_parent getVariable ["NeroOP_rideBusy",false],_parent getVariable ["NeroOP_dropBusy",false]] call NeroOP_fnc_campaignTransitGate)}) exitWith {objNull};
if (!_loading && {_ai}) then {private _field=switch (_category) do {case "AAA":{"aaaLimit"};case "SAM":{"samLimit"};case "RADAR":{"radarLimit"};case "MLRS":{"mlrsLimit"};case "ARTILLERY_SP";case "ARTILLERY_STATIC":{"artilleryLimit"};default {""};};if (_field!="") then {private _used={(_x#1)==_side && {alive (_x#4)} && {private _v=_x#4;private _role=_v getVariable ["NeroOP_assetCategory",""];if (_field=="artilleryLimit") then {_role in ["ARTILLERY_SP","ARTILLERY_STATIC"]} else {_role==_category}}} count NeroOP_campEquipment;if (_used>=getNumber(_settings >> _field)) then {_source=-1;};};};
if (_source<0) exitWith {objNull};
private _stationary=!_ai && {_class isKindOf "StaticWeapon" || {_category in ["RADAR","SAM"]}};
private _existing=NeroOP_campEquipment findIf {(_x#1)==_side && {(_x#3)==_kind} && {(_x#10)==_key} && {alive (_x#4)}};
private _fleet={(_x#1)==_side && {(_x#3)==_kind} && {alive (_x#4)}} count NeroOP_campEquipment;
private _limit=getNumber(_settings >> (["groundLimit","airLimit"]#_kind));
if (!_loading && {!([_price,NeroOP_campStocks#_source,_reserve,NeroOP_campEquipmentIssued#_side,getNumber(_settings >> "totalPurchases"),_fleet,_limit,_existing>=0 && {!_stationary},!_ai || {serverTime-(_parent getVariable [["NeroOP_groundBuyAt","NeroOP_airBuyAt"]#_kind,-10000])>=getNumber(_settings >> "cooldown") && {serverTime-(NeroOP_campBuyAt#_side)>=5}},_kind==1 && {_ai} && {!_drone},_count,1] call NeroOP_fnc_campaignBuyGate)}) exitWith {objNull};
if (_ai && {!_loading} && {_kind==1} && {!_drone} && {count _candidates<1}) exitWith {objNull};
if (_ai && {!_loading} && {_support} && {!_drone} && {count _candidates<_supportCrew || {_count-_supportCrew<2}}) exitWith {objNull};
if (_fleet>=_limit || {!isClass(configFile >> "CfgVehicles" >> _class)}) exitWith {objNull};
private _borrowRestore=_loading && {_ai} && {_kind==0} && {!_drone} && {_category in ["CAR","APC","TANK"]} && {count (_restore#7)==0} && {count _candidates>=2} && {_count>=4};
private _detached=_borrowRestore || {_support} || {_kind==0 && {_ai} && {!_drone} && {_category in ["CAR","APC","TANK"]} && {!_loading || {count (_restore#7)>0}}};
private _spawn=+_position;if (_ai && {_support} && {_class isKindOf "StaticWeapon"} && {!_loading}) then {_position=NeroOP_campPositions#([_side,_position] call NeroOP_fnc_campaignDefense);_spawn=+_position;};
if (_loading && {_kind==1} && {!_ai} && {!_drone}) then {private _base=NeroOP_campPositions#(NeroOP_campRoots#_side);_spawn=[_base#0+30,_base#1+30,0];};
if (_kind==0) then {
 if (_category=="SHIP") then {_spawn=[_position,30,1500,8,2,.35,0,[],[]] call BIS_fnc_findSafePos;} else {
 _spawn=[_position,15,75,6,0,.35,0,[],[_position,_position]] call BIS_fnc_findSafePos;
 _spawn=_spawn findEmptyPosition [0,30,_class];};
} else {if (!_loading) then {_spawn=[_position#0,_position#1,if (_category=="HELICOPTER") then {180} else {1400}];};};
if (count _spawn<2 || {(surfaceIsWater _spawn)!=(_category=="SHIP")} || {_spawn#0<500 || {_spawn#0>worldSize-500} || {_spawn#1<500} || {_spawn#1>worldSize-500}}) exitWith {objNull};
private _parked=_loading && {_kind==1} && {_spawn#2<5};
private _adClass=getText(configFile >> "CfgNeroAirDefense" >> _class >> "spawnClass");if (_adClass=="") then {_adClass=_class;};
private _vehicle=createVehicle [_adClass,_spawn,[],0,if (_kind==1 && {!_parked} && {(!_loading || {_ai})}) then {"FLY"} else {"NONE"}];
if (isNull _vehicle) exitWith {objNull};
_vehicle setVariable ["NeroOP_loading",_loading,true];_vehicle setVariable ["NeroOP_specialKind",_special,true];
if (_special>=0) then {_vehicle setVariable ["NeroOP_specialInit",true];_vehicle addEventHandler ["Killed",{params ["_v","_killer","_instigator"];if (isServer) then {diag_log format ["[NeroOP SPECIAL] KILLED class=%1 pos=%2 source=%3 instigator=%4 lastFlight=%5",typeOf _v,getPosASL _v,typeOf _killer,typeOf _instigator,_v getVariable ["NeroOP_flightLast",[]]];private _k=_v getVariable ["NeroOP_specialKind",-1];if (_k>=0) then {NeroOP_campSpecialUntil set [_k,serverTime+([1200,900]#_k)];};};}];};
private _target=_parent getVariable ["NeroOP_campTarget",NeroOP_campRoots#_side];
private _heading=if (_loading) then {_restore#4} else {(_spawn getDir (NeroOP_campPositions#(_target max 0)))};
_vehicle setVariable ["NeroOP_airRole",_role,true];_vehicle setVariable ["NeroOP_assetCategory",_category,true];_vehicle setDir _heading;_vehicle setVariable ["NeroOP_side",_side,true];_vehicle setVariable ["NeroOP_campaignVehicle",true,true];
_vehicle setVariable ["NeroOP_stationary",_stationary,true];_vehicle setVariable ["NeroOP_support",_support,true];_vehicle setVariable ["NeroOP_artillery",_category in ["ARTILLERY_SP","ARTILLERY_STATIC","MLRS"],true];
if (_kind==0 && {_ai} && {!_drone} && {!_support} && {!_loading} && {count (fullCrew [_vehicle,"",true] select {!(_x#4)})<count units _parent}) then {_detached=true;};_vehicle setVariable ["NeroOP_detachedCrew",_detached,true];
private _flight=grpNull;private _crew=[];private _ok=!_detached || {_loading} || {_drone} || {count _candidates>=_supportCrew && {_count-_supportCrew>=2}};
if (!_ok) exitWith {deleteVehicle _vehicle;objNull};
if (_drone) then {createVehicleCrew _vehicle;private _oldCrew=crew _vehicle;private _oldGroups=_oldCrew apply {group _x};_flight=createGroup [[west,east]#_side,true];_oldCrew joinSilent _flight;{if (count units _x==0) then {deleteGroup _x;};} forEach _oldGroups;_ok=count _oldCrew>0;_vehicle setVariable ["NeroOP_drone",true,true];if (_special==0) then {_vehicle setVariable ["NeroOP_fpEvade",true,true];};_vehicle setVariable ["NeroOP_droneBuyer",_buyer,true];_flight setVariable ["NeroOP_campFlight",true,true];_flight setVariable ["NeroOP_side",_side,true];} else {if (_detached && {_ai}) then {
 _flight=createGroup [[west,east]#_side,true];_flight setVariable ["NeroOP_campSupport",true,true];_flight setVariable ["NeroOP_side",_side,true];
 if (_loading && {!_borrowRestore}) then {{private _u=_flight createUnit [_x,_spawn,[],0,"NONE"];_u setVariable ["NeroOP_campUnit",true,true];_crew pushBack _u;} forEach (_restore#7);} else {_crew=_candidates select [0,_supportCrew];{unassignVehicle _x;if (vehicle _x!=_x) then {moveOut _x;};} forEach _crew;_crew joinSilent _flight;};
 [_vehicle,_flight] call NeroOP_fnc_campaignCrew;_flight setCombatMode "RED";_flight setBehaviourStrong "AWARE";
 _ok=count _crew>0 && {_crew findIf {vehicle _x!=_vehicle}<0} && {if (_loading) then {!isNull driver _vehicle || {!isNull gunner _vehicle}} else {(!_support || {!isNull gunner _vehicle}) && {_class isKindOf "StaticWeapon" || {!isNull driver _vehicle}}}};
} else {if (_kind==1) then {
 _flight=createGroup [[west,east]#_side,true];_flight setVariable ["NeroOP_campFlight",true,true];_flight setVariable ["NeroOP_side",_side,true];
 if (_ai) then {
  private _seats=(fullCrew [_vehicle,"",true]) select {(_x#1)=="driver" || {!(_x#4) && {(_x#1) in ["turret","gunner","commander"]}}};
  private _pylonTurrets=(getAllPylonsInfo _vehicle) apply {_x#2};private _seatRank=[];{_seatRank pushBack [if ((_x#1)=="driver") then {0} else {if ((_x#3) in _pylonTurrets) then {1} else {if (count (_vehicle weaponsTurret (_x#3))>0) then {2} else {3}}},_forEachIndex];} forEach _seats;_seatRank sort true;_seats=_seatRank apply {_seats#(_x#1)};
  private _wanted=(count _seats) min getNumber(_settings >> "pilots") min (if (_loading) then {count (_restore#7)} else {count _candidates min (_count-2)});
  if (_loading) then {{private _u=_flight createUnit [_x,_spawn,[],0,"NONE"];_u setVariable ["NeroOP_campUnit",true,true];_crew pushBack _u;} forEach (_restore#7);} else {_crew=_candidates select [0,_wanted];{unassignVehicle _x;if (vehicle _x!=_x) then {moveOut _x;};} forEach _crew;_crew joinSilent _flight;};
  {private _seat=_seats#_forEachIndex;if ((_seat#1)=="driver") then {_x assignAsDriver _vehicle;_x moveInDriver _vehicle;} else {_x assignAsTurret [_vehicle,_seat#3];_x moveInTurret [_vehicle,_seat#3];};} forEach (_crew select [0,count _seats]);
  _ok=count _crew>0 && {!isNull driver _vehicle} && {_crew findIf {vehicle _x!=_vehicle}<0};
 } else {if (!_loading) then {_vehicle enableSimulationGlobal false;_vehicle allowDamage false;};};
} else {
 if (_ai && {!isNull _parent}) then {_ok=[_vehicle,_parent] call NeroOP_fnc_campaignCrew;};
};};};
if (_ok && {!_loading}) then {
 NeroOP_campSeq=NeroOP_campSeq+1;private _spent=[NeroOP_campStocks,NeroOP_campLedger,"spend","asset:"+str NeroOP_campSeq,_source,-1,_price] call NeroOP_fnc_campaignStock;
 _ok=_spent#2;if (_ok) then {NeroOP_campStocks=_spent#0;NeroOP_campLedger=_spent#1;NeroOP_campEquipmentIssued set [_side,(NeroOP_campEquipmentIssued#_side)+1];NeroOP_campBuyAt set [_side,serverTime];_parent setVariable [["NeroOP_groundBuyAt","NeroOP_airBuyAt"]#_kind,serverTime];};
};
if (!_ok) exitWith {if (_drone) then {{deleteVehicle _x;} forEach crew _vehicle;};{unassignVehicle _x;moveOut _x;} forEach crew _vehicle;if (!_loading && {_kind==1 || {_detached}} && {!_drone}) then {_crew joinSilent _parent;};if (_borrowRestore) then {_crew joinSilent _parent;} else {if (_loading) then {{deleteVehicle _x;} forEach _crew;};};deleteVehicle _vehicle;if (!isNull _flight) then {deleteGroup _flight;};objNull};
if (_loading) then {_vehicle setDamage (_restore#5);_vehicle setFuel (_restore#6);_vehicle setVariable ["NeroOP_savedAmmo",[_restore#9,_restore#10],true];};
NeroOP_campAssetSeq=NeroOP_campAssetSeq+1;private _id=NeroOP_campAssetSeq;
_vehicle setVariable ["NeroOP_assetId",_id,true];_vehicle setVariable ["NeroOP_airHeading",_heading,true];
NeroOP_campEquipment pushBack [_id,_side,_class,_kind,_vehicle,_parent,_flight,_ai,serverTime,_source,_key];
if (!isNull _parent) then {_parent setVariable [["NeroOP_groundVehicle","NeroOP_airVehicle"]#_kind,_vehicle,true];};
if (_category in ["AAA","SAM","RADAR"]) then {_vehicle setVehicleRadar 1;_vehicle setVehicleReportRemoteTargets true;_vehicle setVehicleReceiveRemoteTargets true;_vehicle setVehicleReportOwnPosition true;};
if (_kind==1 && {_ai || {_drone}}) then {_vehicle engineOn true;_vehicle flyInHeight (if (_vehicle isKindOf "Helicopter") then {150} else {900});_vehicle setVehicleRadar 1;_flight setCombatMode "RED";_vehicle setVelocity [sin _heading*(if (_vehicle isKindOf "Helicopter") then {35} else {180}),cos _heading*(if (_vehicle isKindOf "Helicopter") then {35} else {180}),0];[_vehicle] call NeroOP_fnc_airArm;if (_parked) then {_vehicle setVelocity [0,0,0];_vehicle engineOn false;};};
if (_ai && {_kind==1}) then {{if (!isPlayer _x) then {_x setVariable ["ACE_GForceCoef",.55,true];};} forEach _crew;[_vehicle,!_loading] call NeroOP_fnc_campaignAirLoadout;};if (_loading) then {[_vehicle] call NeroOP_fnc_campaignAmmoRestore;};if (_ai || {_drone} || {_loading}) then {_vehicle setVariable ["NeroOP_airArmed",true,true];};
if (!_ai && {!_loading}) then {if (_drone) then {[_buyer,_vehicle] remoteExecCall ["NeroOP_fnc_campaignDrone",owner _buyer];} else {if (_kind==1) then {[_buyer,_vehicle,_flight] call NeroOP_fnc_campaignLaunchFlight;};};};
if (_drone && {_kind==1} && {!_ai}) then {private _wp=_flight addWaypoint [_spawn,800];_wp setWaypointType "LOITER";_wp setWaypointLoiterRadius 900;};
diag_log format ["[NeroOP EQUIPMENT] BUY side=%1 class=%2 kind=%3 AI=%4 pilots=%5 restored=%6 parent=%7",_side,_class,_kind,_ai,count _crew,_loading,_key];
_vehicle
