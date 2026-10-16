/* Connected local supply point; no client-provided coordinates or prices. */
params ["_unit","_side",["_price",0],["_anySector",false]];
private _cfg=missionConfigFile >> "CfgNeroOperation";private _nodes="true" configClasses (_cfg >> "Sectors");
private _graph=[NeroOP_campOwners,NeroOP_campLinks,NeroOP_campRoots#_side,_side] call NeroOP_fnc_campaignGraph;
private _rank=[];
{if ((_anySector || {getText((_nodes#_x) >> "kind") in ["base","depot"]}) && {_unit distance2D (NeroOP_campPositions#_x)<(NeroOP_campRadii#_x)+100} && {(NeroOP_campStocks#_x)>=_price}) then {_rank pushBack [_unit distance2D (NeroOP_campPositions#_x),_x];};} forEach (_graph#0);
_rank sort true;if (count _rank==0) then {-1} else {(_rank#0)#1}
