if(getNumber(missionConfigFile >> "NeroWL_observer")!=1)exitWith{};
if(isServer && {!(missionNamespace getVariable ["NeroAI_vanillaMode",false])})then{NeroAI_maxEnemyArmyGroups=48;NeroAI_maxEnemyGroups=0;NeroAI_friendlyAutoEnrollEnabled=true;NeroAI_maxFriendlyGroups=16;};
if(hasInterface)then{[]spawn{
 waitUntil{sleep 1;!isNull player};
 if(side group player!=civilian)exitWith{};
 [] spawn {
  waitUntil {sleep 1;count (missionNamespace getVariable ["BIS_WL_sectors",[]]) >= 3};
  private _markers=[];
  {
   private _name=format ["NeroWL_observerSector_%1",_forEachIndex];
   createMarkerLocal [_name,getPosATL _x];
   _name setMarkerShapeLocal "ELLIPSE";
   _name setMarkerSizeLocal [200,200];
   _name setMarkerBrushLocal "Border";
   _name setMarkerTextLocal (_x getVariable ["Name","Сектор"]);
   _markers pushBack [_name,_x];
  } forEach BIS_WL_sectors;
  NeroWL_observerReady=true;
  while {true} do {
   {private _side=(_x#1) getVariable ["BIS_WL_sectorSide",resistance];(_x#0) setMarkerColorLocal (if(_side==west)then{"ColorBLUFOR"}else{if(_side==east)then{"ColorOPFOR"}else{"ColorIndependent"}});} forEach _markers;
   sleep 5;
  };
 };
 player allowDamage false;player setCaptive true;removeAllWeapons player;
 player addAction["Режим наблюдателя",{["Initialize",[player,[],true]]call BIS_fnc_EGSpectator;}];
 player addAction["Открыть Зевс",{["Terminate"]call BIS_fnc_EGSpectator;if(!isNull getAssignedCuratorLogic player)then{openCuratorInterface;};}];
 hint "LLM против LLM. Наблюдатель — меню действий. Зевс — Y. Игрок не является участником захвата.";
};};
