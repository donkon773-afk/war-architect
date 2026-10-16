params ["_unit","_target","_position"];
if (!isRemoteExecuted || {remoteExecutedOwner!=2} || {_unit!=player} || {!local _unit} || {!alive _unit} || {vehicle _unit!=_unit}) exitWith {};
private _grant=_unit getVariable ["NeroOP_travelGrant",[]];if (count _grant!=3 || {_grant#0!=_target} || {_grant#1<serverTime} || {!((_grant#2) isEqualTo _position)}) exitWith {};
{if (!isPlayer _x && {local _x} && {alive _x} && {_x getVariable ["NeroOP_campUnit",false]} && {vehicle _x==_x} && {_x distance2D _unit<100}) then {[_x,_position,false] call NeroOP_fnc_campaignDropLocal;};} forEach units group _unit;
[_unit,_position,true] call NeroOP_fnc_campaignDropLocal;_unit setVariable ["NeroOP_travelGrant",[]];
