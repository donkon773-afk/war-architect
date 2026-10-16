/* Native fire mission using reported contacts, not hidden enemy positions. */
params ["_vehicle","_group","_side"];
if (!isServer || {!local _vehicle} || {!local _group} || {crew _vehicle findIf {isPlayer _x}>=0} || {isNull gunner _vehicle} || {!alive gunner _vehicle} || {speed _vehicle>8} || {serverTime-(_vehicle getVariable ["NeroOP_artyAt",-120])<120}) exitWith {};
_vehicle setVariable ["NeroOP_artyAt",serverTime];
private _contacts=[];
{if ((_x getVariable ["NeroOP_side",-1])==_side && {alive leader _x}) then {
 {if ((_x#2)==([east,west]#_side) && {_x#0>=.5} && {_x#5<=45}) then {_contacts pushBack (_x#4);};} forEach (leader _x targetsQuery [objNull,[east,west]#_side,"",[],45]);
};} forEach NeroOP_campGroups;
private _ammo=getArtilleryAmmo [_vehicle];if (count _ammo==0) exitWith {};
private _chosen=[];private _magazine="";
{private _p=_x;private _unsafe=allUnits findIf {alive _x && {side group _x==([west,east]#_side)} && {_x distance2D _p<200}}>=0;
 if (!_unsafe && {count _chosen==0}) then {{if (count _chosen==0 && {_p inRangeOfArtillery [[_vehicle],_x]}) then {_chosen=_p;_magazine=_x;};} forEach _ammo;};
} forEach _contacts;
if (count _chosen>0 && {local _vehicle} && {crew _vehicle findIf {isPlayer _x}<0}) then {_vehicle doArtilleryFire [_chosen,_magazine,if (toLower typeOf _vehicle find "fp5">=0) then {1} else {3}];diag_log format ["[NeroOP EQUIPMENT] ARTILLERY class=%1 rounds=3 reportedTarget=%2",typeOf _vehicle,_chosen];};
