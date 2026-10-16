params ["_entry","_success"];
if (!isServer) exitWith {};_entry params ["_id","_side","_source","_target","_amount","_truck","_group","_deadline","_path"];
private _active=NeroOP_campConvoys findIf {(_x#0)==_id};if (_active<0) exitWith {};
if (_success) then {_success=!isNull _truck && {alive _truck} && {(NeroOP_campOwners#_target)==_side} && {_truck distance2D (NeroOP_campPositions#_target)<(NeroOP_campRadii#_target)} && {count ([NeroOP_campOwners,NeroOP_campLinks,_source,_target,_side] call NeroOP_fnc_campaignPath)>0};};
private _result=[NeroOP_campStocks,NeroOP_campLedger,if (_success) then {"deliver"} else {"lost"},_id,_source,_target,_amount] call NeroOP_fnc_campaignStock;
if !(_result#2) exitWith {};NeroOP_campStocks=_result#0;NeroOP_campLedger=_result#1;NeroOP_campConvoys deleteAt _active;
deleteMarker (_truck getVariable ["NeroOP_campCargoMarker",""]);_truck setVariable ["NeroOP_campCargo",0,true];
diag_log format ["[NeroOP CAMPAIGN] CONVOY %1 side=%2 target=%3 cargo=%4",if (_success) then {"DELIVERED"} else {"LOST"},_side,_target,_amount];
_truck setVariable ["NeroOP_supplyReserved",false];if (alive _truck && {alive driver _truck}) then {[_truck,_side] spawn NeroOP_fnc_campaignTruckReturn;};
