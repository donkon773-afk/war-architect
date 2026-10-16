/* One authenticated basket, bounded to eight physical items. No client-supplied prices. */
params[["_unit",objNull,[objNull]],["_classes",[],[[]]],["_id","",[""]]];
if(!isServer || {isNull _unit} || {!alive _unit} || {!isPlayer _unit} || {!(_unit in (missionNamespace getVariable["BIS_WL_allWarlords",[]]))})exitWith{};
if(isRemoteExecuted && {remoteExecutedOwner!=owner _unit})exitWith{};
if(!(["BEGIN",_unit,_id]call NeroWL_Design_fnc_cqRequest))exitWith{};
private _result=[false,"Недопустимый заказ.",0];
isNil{
 private _catalog=missionNamespace getVariable["BIS_WL_purchasable"+str side group _unit,[]];
 private _quote=[_catalog,_classes,_unit getVariable["BIS_WL_funds",0]]call NeroWL_Design_fnc_cqQuote;
 if(!(_quote#0))exitWith{_result=[false,_quote#2,0];};
 private _valid=true;private _side=side group _unit;
 {
  private _class=_x;
  if(!isClass(configFile >> "CfgVehicles" >> _class) || {getNumber(configFile >> "CfgVehicles" >> _class >> "side")!=([east,west,resistance]find _side)})exitWith{_valid=false;};
 }forEach _classes;
 if(!_valid)exitWith{_result=[false,"Класс отсутствует в каталоге вашей стороны.",0];};
 if(diag_tickTime-(_unit getVariable["NeroWL_CQlastBuy",-100])<5)exitWith{_result=[false,"Подождите 5 секунд между заказами.",0];};
 private _completed=0;private _reason="";
 {
  private _item=[_unit,_x,"",true]call NeroWL_Design_fnc_cqPurchase;
  if(!(_item#0))exitWith{_reason=_item#1;};
  _completed=_completed+1;
 }forEach _classes;
 _result=[_completed==count _classes,if(_completed==count _classes)then{format["Заказ выполнен: %1. Техника — на базе, пехота — у командира.",_completed]}else{format["Выполнено %1 из %2. %3",_completed,count _classes,_reason]},_completed];
};
["END",_unit,_id,_result]call NeroWL_Design_fnc_cqRequest;
