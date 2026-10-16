params ["_g","_target"];
if (!isServer || {!local _g} || {[_g] call NeroOP_fnc_campaignPlayerControl} || {serverTime-(_g getVariable ["NeroOP_redeployAt",-600])<300} || {units _g findIf {alive _x && {vehicle _x!=_x}}>=0}) exitWith {false};
private _side=_g getVariable ["NeroOP_side",-1];if !(_side in [0,1]) exitWith {false};private _root=NeroOP_campRoots#_side;
if (leader _g distance2D (NeroOP_campPositions#_root)>(NeroOP_campRadii#_root)+150 || {leader _g distance2D (NeroOP_campPositions#_target)<3500}) exitWith {false};
private _graph=[NeroOP_campOwners,NeroOP_campLinks,_root,_side] call NeroOP_fnc_campaignGraph;private _rank=[];
{private _p=NeroOP_campPositions#_x;private _enemy=allUnits findIf {alive _x && {([west,east]#_side) getFriend side group _x<.6} && {_x distance2D _p<500}}>=0;
 if (_x!=_root && {!_enemy} && {!surfaceIsWater _p} && {_p distance2D (NeroOP_campPositions#_target)<leader _g distance2D (NeroOP_campPositions#_target)-1500}) then {_rank pushBack [_p distance2D (NeroOP_campPositions#_target),_x];};
} forEach (_graph#0);_rank sort true;if (count _rank==0) exitWith {false};private _p=NeroOP_campPositions#((_rank#0)#1);
_g setVariable ["NeroOP_redeployAt",serverTime];_g setVariable ["NeroOP_dropBusy",true];_g setVariable ["NeroOP_campTarget",_target];
{if (alive _x && {local _x} && {!isPlayer _x}) then {[_x,[_p#0+random 35,_p#1+random 35],false] call NeroOP_fnc_campaignDropLocal;};} forEach units _g;
[_g] spawn {params ["_g"];waitUntil {sleep 1;isNull _g || {units _g findIf {_x getVariable ["NeroOP_dropActive",false]}<0}};if (!isNull _g) then {_g setVariable ["NeroOP_dropBusy",false];[_g,true] call NeroOP_fnc_campaignOrder;};};
diag_log format ["[NeroOP DROP] AI group=%1 destination=%2 height=4500",_g getVariable ["NeroOP_groupKey",-1],(_rank#0)#1];true
