/* Request first delivers physical supply; service never teleports ammunition for free. */
params ["_unit","_side"];
if (!isServer || {_unit getVariable ["ACE_isUnconscious",false]}) exitWith {};
private _vehicle=vehicle _unit;
/* cursorObject is client-local; on foot use a server query of nearby friendly campaign vehicles. */
if (vehicle _unit==_unit) then {private _rank=[];{if (alive _x && {_x getVariable ["NeroOP_side",-1]==_side} && {_x distance2D _unit<50}) then {_rank pushBack [_x distance2D _unit,_x];};} forEach (vehicles);_rank sort true;_vehicle=if (count _rank>0) then {(_rank#0)#1} else {objNull};};
if (isNull _vehicle || {!alive _vehicle} || {_vehicle getVariable ["NeroOP_side",-1]!=_side} || {_unit distance2D _vehicle>50} || {speed _vehicle>5} || {(getPosATL _vehicle)#2>5}) exitWith {_unit setVariable ["NeroOP_notice","Остановите свою технику в захваченном связанном секторе; подойдите не дальше 50 м.",true];};
private _graph=[NeroOP_campOwners,NeroOP_campLinks,NeroOP_campRoots#_side,_side] call NeroOP_fnc_campaignGraph;private _near=(_graph#0) findIf {_vehicle distance2D (NeroOP_campPositions#_x)<NeroOP_campRadii#_x};
if (_near<0) exitWith {};private _target=(_graph#0)#_near;private _cost=getNumber(missionConfigFile >> "CfgNeroOperation" >> "Gameplay" >> "serviceCost");
if ((NeroOP_campStocks#_target)>=_cost) exitWith {private _ok=false;isNil {_ok=[_vehicle,_side,true] call NeroOP_fnc_campaignService;};_unit setVariable ["NeroOP_notice",if (_ok) then {"Техника обслужена за местное снабжение."} else {"Обслуживание отклонено: пауза, противник или недостаточно снабжения."},true];};
if (_target==NeroOP_campRoots#_side) exitWith {_unit setVariable ["NeroOP_notice","Недостаточно снабжения базы.",true];};
NeroOP_campServiceRequests pushBackUnique [_vehicle,_side,_target,_unit];[_side,_target] spawn NeroOP_fnc_campaignConvoy;_unit setVariable ["NeroOP_notice","Запрошена физическая доставка. Обслуживание после прибытия колонны; оставайтесь в секторе.",true];
