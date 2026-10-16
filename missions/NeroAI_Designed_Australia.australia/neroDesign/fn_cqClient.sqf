if(!hasInterface)exitWith{};
disableSerialization;waitUntil{sleep 1;!isNull player && {missionNamespace getVariable["NeroWL_CQready",false]} && {!isNull findDisplay 46}};
player addAction["NeroAI: покупки, цели и перемещение",{[]call NeroWL_Design_fnc_cqMenu;}];
(findDisplay 46)displayAddEventHandler["KeyDown",{if((_this#1)==23 && {!dialog})then{[]call NeroWL_Design_fnc_cqMenu;true}else{false}}];
private _hud=(findDisplay 46)ctrlCreate["RscStructuredText",87101];_hud ctrlSetPosition[safeZoneX+safeZoneW-0.36,safeZoneY+0.07,0.35,0.10];_hud ctrlSetBackgroundColor[0,0,0,0.65];_hud ctrlCommit 0;
private _outside=-1;private _lastPlayer=player;
while{true}do{
 if(player!=_lastPlayer)then{player addAction["NeroAI: покупки, цели и перемещение",{[]call NeroWL_Design_fnc_cqMenu;}];_lastPlayer=player;};
 private _s=side group player;private _target=missionNamespace getVariable[format["BIS_WL_currentSector_%1",_s],objNull];
 _hud ctrlSetStructuredText parseText format["<t size='1.1'>NeroAI · три стороны</t><br/>%1 CP · I: меню<br/>Цель: %2",round(player getVariable["BIS_WL_funds",0]),_target getVariable["Name","Выбирается"]];
 {private _id=format["NeroCQ_sector_%1",_forEachIndex];if(markerShape _id=="")then{createMarkerLocal[_id,getPosATL _x];_id setMarkerShapeLocal "ELLIPSE";_id setMarkerSizeLocal[_x getVariable["Size",200],_x getVariable["Size",200]];_id setMarkerBrushLocal "Border";};_id setMarkerColorLocal(switch(_x getVariable["BIS_WL_sectorSide",sideUnknown])do{case west:{"ColorWEST"};case east:{"ColorEAST"};default{"ColorGUER"};});_id setMarkerTextLocal((_x getVariable["Name",""])+if((_x getVariable["NeroWL_capture",0])>0)then{format[" (%1/60)",_x getVariable["NeroWL_capture",0]]}else{""});}forEach(missionNamespace getVariable["BIS_WL_sectors",[]]);
 if(getNumber(missionConfigFile >> "NeroWL_lethalZones")==1)then{
  private _bad=(BIS_WL_sectors findIf{!(_x getVariable["NeroWL_isBase",false]) && {(_x getVariable["BIS_WL_sectorSide",sideUnknown])!=_s} && {_x!=_target} && {player distance2D _x<(_x getVariable["Size",200])}})>=0;
  if(_bad && {alive player})then{if(_outside<0)then{_outside=diag_tickTime;};private _left=30-(diag_tickTime-_outside);hintSilent format["Сектор не выбран целью. Покиньте зону: %1 с",ceil _left];if(_left<=0)then{player setDamage 1;_outside=-1;};}else{_outside=-1;};
 };
 sleep 2;
};
