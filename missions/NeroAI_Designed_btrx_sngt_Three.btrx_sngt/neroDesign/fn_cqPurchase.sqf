/* One physical purchase, server-authoritative purse and allowlisted catalog. */
params["_wl","_class",["_kind",""],["_batch",false]];
if(!isServer || {isNull _wl} || {!alive _wl} || {!(_wl in BIS_WL_allWarlords)})exitWith{[false,"Нет командира CP."]};
private _g=group _wl;private _s=side _g;
private _reserve=if(isPlayer _wl)then{0}else{missionNamespace getVariable["NeroAI_purchaseReserveCP",1500]};
if(_kind in ["PLANE","HELICOPTER","UAV"] && {!isPlayer _wl})exitWith{[_g,_kind]call NeroAI_fnc_purchaseAirAsset};
private _result=[false,"Недоступная покупка."];
isNil{
 if(!_batch && {diag_tickTime-(_wl getVariable["NeroWL_CQlastBuy",-100])<5})exitWith{_result=[false,"Пауза между покупками."];};
 private _cat=missionNamespace getVariable["BIS_WL_purchasable"+str _s,[]];private _rows=[];{_rows append _x;}forEach _cat;
 if(_kind!="")then{
  _rows=_rows select{private _c=_x#0;switch(_kind)do{case "INFANTRY":{_c isKindOf "Man"};case "TANK":{([_c]call NeroAI_fnc_groundAssetKind)=="TANK"};case "APC":{([_c]call NeroAI_fnc_groundAssetKind)=="APC"};case "CAR":{_c isKindOf "Car"};case "TRUCK":{_c isKindOf "Truck_F"};default{false};}};
  _rows=_rows select{(_x#1)<=(_wl getVariable["BIS_WL_funds",0])-_reserve};_rows=[_rows,[],{_x#1},"DESCEND"]call BIS_fnc_sortBy;
 }else{_rows=_rows select{(_x#0)==_class};};
 if(_rows isEqualTo [])exitWith{_result=[false,"Нет доступного класса или CP."];};
 private _row=_rows#0;_class=_row#0;private _cost=_row#1;private _cfg=configFile >> "CfgVehicles" >> _class;
 if(!isClass _cfg || {_cost<1} || {getNumber(_cfg >> "side")!=([east,west,resistance]find _s)})exitWith{};
 private _funds=_wl getVariable["BIS_WL_funds",0];if(_funds<_cost+_reserve)exitWith{_result=[false,"Не хватает CP с учётом резерва."];};
 private _base=missionNamespace getVariable[format["BIS_WL_base_%1",_s],objNull];private _obj=objNull;
 if(_class isKindOf "Man")then{
  if(count units _g>=(missionNamespace getVariable["BIS_WL_maxSubordinates",9])+1 || {(["INFANTRY"]call NeroAI_fnc_designPurchaseCapacity)<=0})exitWith{_result=[false,"Достигнут лимит бойцов."];};
  private _p=(getPosATL _wl)findEmptyPosition[1,25,_class];if(!(_p isEqualTo []))then{_obj=_g createUnit[_class,_p,[],0,"NONE"];};
 }else{
  if(!isPlayer _wl)then{
   private _owned=(_g getVariable["BIS_WL_groupVehs",[]])select{!isNull _x && {alive _x}};
   if(count _owned>=(missionNamespace getVariable["NeroAI_purchaseMaxVehicles",1]))exitWith{_result=[false,"Используйте имеющуюся технику группы."];};
   if(!([_g]call NeroAI_fnc_claimSidePurchaseSlot))exitWith{_result=[false,"Пауза закупки стороны или общий лимит техники."];};
   _obj=[_s,_class,getPosATL _base,_wl,false]call NeroWL_Design_fnc_spawnAsset;
  }else{_obj=[_s,_class,getPosATL _base,_wl,true]call NeroWL_Design_fnc_spawnAsset;};
 };
 if(isNull _obj)exitWith{_result=[false,"Нет безопасного спавна или достигнут общий лимит."];};
 _wl setVariable["BIS_WL_funds",_funds-_cost,true];_wl setVariable["NeroWL_CQlastBuy",diag_tickTime];_g setVariable["NeroAI_lastPurchase",diag_tickTime];
 _result=[true,format["Куплено %1 за %2 CP",getText(_cfg >> "displayName"),_cost]];diag_log format["[NeroCQ BUY] payer=%1 side=%2 class=%3 cost=%4 balance=%5",_wl,_s,_class,_cost,_funds-_cost];
};_result
