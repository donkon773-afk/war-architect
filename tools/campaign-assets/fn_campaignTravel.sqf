params ["_unit","_side","_target"];
if (!isServer || {_target<0} || {_target>=count NeroOP_campOwners}) exitWith {};
private _check={
 private _graph=[NeroOP_campOwners,NeroOP_campLinks,NeroOP_campRoots#_side,_side] call NeroOP_fnc_campaignGraph;
 private _friendly=[west,east]#_side;private _position=NeroOP_campPositions#_target;
 private _enemy=allUnits findIf {alive _x && {(_friendly getFriend (side group _x))<.6} && {_x distance2D _position<(NeroOP_campRadii#_target)+200}}>=0;
 private _here=allUnits findIf {alive _x && {(_friendly getFriend (side group _x))<.6} && {_x distance2D _unit<300}}>=0;
 [_side,NeroOP_campOwners#_target,_target in (_graph#0),_enemy,vehicle _unit==_unit,alive _unit,!(_unit getVariable ["ACE_isUnconscious",false]),_here] call NeroOP_fnc_campaignTravelGate
};
if (!call _check) exitWith {_unit setVariable ["NeroOP_notice","Перемещение недоступно: нужна связанная своя территория без противника, боец в сознании и пешком, вне контакта.",true];};
_unit setVariable ["NeroOP_notice","Подготовка перемещения — 3 секунды. Проверяю безопасность сектора.",true];private _start=getPosATL _unit;private _owner=owner _unit;private _uid=getPlayerUID _unit;sleep 3;
if (isNull _unit || {!isPlayer _unit} || {owner _unit!=_owner} || {getPlayerUID _unit!=_uid} || {side group _unit!=([west,east]#_side)} || {_unit distance2D _start>10} || {!call _check}) exitWith {_unit setVariable ["NeroOP_notice","Перемещение отменено: изменилось положение бойца или обстановка.",true];};
private _destination=[NeroOP_campPositions#_target,5,80,2,0,.4,0,[],[[],[]]] call BIS_fnc_findSafePos;
if (count _destination<2 || {surfaceIsWater _destination}) exitWith {};
private _companions=units group _unit select {!isPlayer _x && {alive _x} && {_x getVariable ["NeroOP_campUnit",false]} && {vehicle _x==_x} && {_x distance2D _unit<100}};
/* Move only the requesting soldier and nearby AI from his own squad. */
{if (local _x) then {[_x,_destination,false] call NeroOP_fnc_campaignDropLocal;};} forEach _companions;
_unit setVariable ["NeroOP_travelGrant",[_target,serverTime+5,_destination],true];
[_unit,_target,_destination] remoteExecCall ["NeroOP_fnc_campaignTravelLocal",owner _unit];
_unit setVariable ["NeroOP_notice","Сброс над своим сектором: 4500 м. Откройте парашют вручную через меню действий.",true];
