if(!isServer || {!NeroAI_transportReady} || {getNumber(missionConfigFile >> "NeroWL_useDesigner")!=1})exitWith{};
private _cfg=missionConfigFile >> "CfgNeroDesign";
if(getNumber(_cfg >> "garrisonLLM")!=1)exitWith{};
private _limit=(getNumber(_cfg >> "garrisonLimit"))max 1 min 8;
private _candidates=allGroups select {_x getVariable ["NeroWL_garrison",false] && {alive leader _x} && {(units _x findIf {isPlayer _x})<0}};
private _used=0;
{
 private _g=_x;private _s=_g getVariable ["NeroWL_garrisonSector",objNull];
 private _targeted=!isNull _s && {([east,west,resistance] findIf {(missionNamespace getVariable [format["BIS_WL_currentSector_%1",_x],objNull])isEqualTo _s})>=0};
 private _attacked=!isNull _s && {(allUnits findIf {alive _x && {(side _g getFriend side group _x)<0.6} && {_x distance2D _s<((_s getVariable ["Size",200])+200)}})>=0};
 private _want=(_targeted || _attacked)&&{_used<_limit};
 if(_want)then{
   _used=_used+1;
   if(!(_g getVariable["NeroAI_active",false]) && {!(_g getVariable["NeroAI_optOut",false])})then{[objNull,_g,true]call NeroAI_fnc_registerGroup;};
 }else{
   if(_g getVariable["NeroAI_active",false])then{_g setVariable["NeroAI_active",false,true];NeroAI_activeGroups deleteAt(netId _g);};
 };
}forEach _candidates;
