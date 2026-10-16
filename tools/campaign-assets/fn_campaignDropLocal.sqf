/* Trusted local drop. Player opens the chute; AI opens at 250 m. Restore only backpack. */
params ["_unit","_position",["_manual",false]];
if (!local _unit || {!alive _unit} || {vehicle _unit!=_unit} || {_unit getVariable ["NeroOP_dropActive",false]}) exitWith {};
_unit setVariable ["NeroOP_dropActive",true,true];private _pack=(getUnitLoadout _unit)#5;
removeBackpack _unit;_unit addBackpack "B_Parachute";_unit setPosATL [_position#0,_position#1,4500];_unit setVelocity [0,0,-1];_unit switchMove "HaloFreeFall_non";
[_unit,_pack,_manual] spawn {params ["_unit","_pack","_manual"];private _deadline=serverTime+360;
 private _action=-1;if (_manual && {_unit==player}) then {_action=_unit addAction ["Открыть парашют",{(_this#0) action ["OpenParachute",_this#0];},nil,10,false,true,"","alive _this && {vehicle _this==_this} && {(getPosATL _this)#2>5}"];};
 waitUntil {sleep .2;!alive _unit || {!local _unit} || {serverTime>_deadline} || {(getPosATL _unit)#2<250}};
 if (!_manual && {alive _unit} && {local _unit} && {vehicle _unit==_unit}) then {_unit action ["OpenParachute",_unit];};
 waitUntil {sleep .5;!alive _unit || {!local _unit} || {serverTime>_deadline} || {(getPosATL _unit)#2<2 && {vehicle _unit==_unit}}};
 if (_action>=0) then {_unit removeAction _action;};
 if (alive _unit && {local _unit} && {vehicle _unit==_unit} && {(getPosATL _unit)#2<2}) then {private _current=getUnitLoadout _unit;_current set [5,_pack];_unit setUnitLoadout _current;};
 _unit setVariable ["NeroOP_dropActive",false,true];
};
