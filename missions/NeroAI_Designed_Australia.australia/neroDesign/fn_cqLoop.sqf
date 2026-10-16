if(!isServer)exitWith{};
private _cfg=missionConfigFile >> "CfgNeroDesign";private _incomeAt=diag_tickTime;private _planAt=-100;
while{true}do{
 private _units=allUnits select{alive _x && {side group _x in [west,east,resistance]}};
 {
  private _sector=_x;private _owner=_sector getVariable["BIS_WL_sectorSide",sideUnknown];
  if(!(_sector getVariable["NeroWL_isBase",false]))then{
   private _present=_units select{_x distance2D _sector<(_sector getVariable["Size",200]) && {vehicle _x==_x || {(getPosATL vehicle _x)#2<20}}};
   private _sides=[];{_sides pushBackUnique side group _x;}forEach _present;
   if(count _sides==1 && {(_sides#0)!=_owner})then{
    private _capturer=_sides#0;private _old=_sector getVariable["NeroWL_captureSide",sideUnknown];private _progress=if(_old==_capturer)then{(_sector getVariable["NeroWL_capture",0])+5}else{5};_sector setVariable["NeroWL_captureSide",_capturer];_sector setVariable["NeroWL_capture",_progress,true];
    if(_progress>=60)then{_sector setVariable["BIS_WL_sectorSide",_capturer,true];_sector setVariable["NeroWL_capture",0,true];_sector setVariable["NeroWL_garrisonCooldown",diag_tickTime+300];diag_log format["[NeroCQ] captured=%1 side=%2",_sector getVariable["Name",""],_capturer];};
   }else{_sector setVariable["NeroWL_capture",0,true];};
   private _near=(_units findIf{_x distance2D _sector<2500})>=0;
   private _groups=_sector getVariable["NeroWL_garrisonGroups",[]];private _living=_groups select{!isNull _x && {(units _x findIf{alive _x})>=0}};
   if(_near && {_living isEqualTo []} && {diag_tickTime>(_sector getVariable["NeroWL_garrisonCooldown",0])})then{
    if(_sector getVariable["NeroWL_garrisonSpawned",false])then{_sector setVariable["NeroWL_garrisonCooldown",diag_tickTime+300];_sector setVariable["NeroWL_garrisonSpawned",false];}else{[_sector,_sector getVariable["Size",200],_sector getVariable["Size",200],_owner]call NeroAI_fnc_spawnDesignGarrison;_sector setVariable["NeroWL_garrisonSpawned",true];};
   };
  };
 }forEach BIS_WL_sectors;
 // Keep respawned commanders in the economy, retaining the recorded purse.
 {if(alive _x && {isPlayer _x} && {!(_x in BIS_WL_allWarlords)})then{BIS_WL_allWarlords pushBackUnique _x;_x setVariable["BIS_WL_funds",getNumber(_cfg >> "startCP"),true];_x setVariable["BIS_WL_purchasable",missionNamespace getVariable["BIS_WL_purchasable"+str side group _x,[]],true];};}forEach allPlayers;
 if(diag_tickTime-_incomeAt>=60)then{_incomeAt=diag_tickTime;{private _wl=_x;private _s=side group _wl;private _owned={(_x getVariable["BIS_WL_sectorSide",sideUnknown])==_s}count BIS_WL_sectors;_wl setVariable["BIS_WL_funds",((_wl getVariable["BIS_WL_funds",0])+_owned*getNumber(_cfg >> "income"))min 50000,true];}forEach(BIS_WL_allWarlords select{alive _x});};
 if(diag_tickTime-_planAt>=60)then{_planAt=diag_tickTime;
  {private _s=_x;private _base=missionNamespace getVariable[format["BIS_WL_base_%1",_s],objNull];private _defender=_s==resistance && {getText(_cfg >> "greenRole")=="defender"};
   private _targets=BIS_WL_sectors select{!(_x getVariable["NeroWL_isBase",false]) && {(_x getVariable["BIS_WL_sectorSide",sideUnknown])!=_s}};
   if(_defender)then{_targets=BIS_WL_sectors select{!(_x getVariable["NeroWL_isBase",false]) && {(_x getVariable["BIS_WL_sectorSide",sideUnknown])==_s}};};
   if(_defender)then{_targets=_targets select{private _hub=_x;(_units findIf{side group _x!=_s && {_x distance2D _hub<((_hub getVariable["Size",200])+600)}})>=0};};
   private _oldTarget=missionNamespace getVariable[format["BIS_WL_currentSector_%1",_s],objNull];private _target=_oldTarget;
   if(!(_oldTarget in _targets))then{private _ranked=_targets apply{[_x distance2D _base,_x]};_ranked sort true;_target=if(_ranked isEqualTo [])then{_base}else{(_ranked#0)#1};missionNamespace setVariable[format["BIS_WL_currentSector_%1",_s],_target,true];};
   {private _g=group _x;if(!(_g getVariable["NeroWL_garrison",false]) && {(units _g findIf{isPlayer _x})<0} && {!(vehicle leader _g isKindOf "Air")} && {isNil{_g getVariable "NeroWL_cqTarget"} || {(_g getVariable["NeroWL_cqTarget",objNull])!=_target}})then{
    _g setVariable["NeroWL_cqTarget",_target];while{count waypoints _g>0}do{deleteWaypoint((waypoints _g)#0);};private _wp=_g addWaypoint[getPosATL _target,50];_wp setWaypointType(if(_defender)then{"HOLD"}else{"SAD"});_wp setWaypointBehaviour "AWARE";
   };}forEach(BIS_WL_allWarlords select{alive _x && {!isPlayer _x} && {side group _x==_s}});
  }forEach[west,east,resistance];
 };
 sleep 5;
};
