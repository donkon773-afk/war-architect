/* Warlords purchase-menu structure adapted to three sides.
   Stock Arma controls; all operations use the server CQ runtime. */
if(!hasInterface || {isNull player} || {!alive player} || {!(side group player in [west,east,resistance])})exitWith{};
disableSerialization;
private _existing=uiNamespace getVariable["NeroWL_CQmenu",displayNull];
if(!isNull _existing)exitWith{_existing closeDisplay 1;};
if(dialog || {isNull findDisplay 46})exitWith{};
private _d=(findDisplay 46)createDisplay "RscDisplayEmpty";
uiNamespace setVariable["NeroWL_CQmenu",_d];
_d setVariable["NeroCQ_unit",player];_d setVariable["NeroCQ_side",side group player];
_d setVariable["NeroCQ_category",0];_d setVariable["NeroCQ_notice","Добавьте технику или бойцов в заказ. Покупка выполняется после подтверждения."];
private _make={
 params["_class","_id","_box",["_text",""]];
 private _c=_d ctrlCreate[_class,_id];
 _c ctrlSetPosition[safeZoneX+safeZoneW*(_box#0),safeZoneY+safeZoneH*(_box#1),safeZoneW*(_box#2),safeZoneH*(_box#3)];
 if(_class=="RscStructuredText")then{_c ctrlSetStructuredText parseText _text;}else{if(_text!="")then{_c ctrlSetText _text;};};
 _c ctrlCommit 0;_c
};
private _bg=["RscText",-1,[0.01,0.135,0.98,0.735]]call _make;
_bg ctrlSetBackgroundColor[0,0,0,0.82];_bg ctrlEnable false;
private _title=["RscStructuredText",106,[0.01,0.135,0.98,0.045],"<t size='1.3'>WARLORDS · три стороны</t>"]call _make;
_title ctrlSetBackgroundColor[0.12,0.12,0.12,0.9];
{private _c=["RscStructuredText",9901+_forEachIndex,_x#0,_x#1]call _make;_c ctrlSetBackgroundColor[0,0,0,0.7];}forEach[
 [[0.02,0.185,0.16,0.04],"КАТЕГОРИИ"],[[0.19,0.185,0.23,0.04],"ЗАПРОСЫ"],[[0.43,0.185,0.27,0.04],"СВЕДЕНИЯ"],[[0.72,0.185,0.26,0.04],"ЗАКАЗ И ДОСТАВКА"]
];
private _categories=["RscListbox",100,[0.02,0.235,0.16,0.46]]call _make;
private _catalog=missionNamespace getVariable["BIS_WL_purchasable"+str side group player,[]];
{private _bucket=_forEachIndex;if(_bucket in [0,1,3,4,5] || {count(_catalog param[_bucket,[]])>0})then{private _i=_categories lbAdd _x;_categories lbSetValue[_i,_bucket];_categories lbSetTooltip[_i,_x];};}forEach["Пехота","Наземная техника","Снаряжение","Оборона","Авиация","Флот","Личное снаряжение","Поддержка"];
private _i=_categories lbAdd "Голосование";_categories lbSetValue[_i,-1];_categories lbSetTooltip[_i,"Голосование за следующую цель своей стороны"];
_i=_categories lbAdd "Перемещение";_categories lbSetValue[_i,-2];_categories lbSetTooltip[_i,"Быстрое перемещение в свой сектор"];
private _search=["RscEdit",115,[0.19,0.235,0.23,0.04]]call _make;
_search ctrlSetTooltip "Поиск по названию или классу. Для карты — по названию сектора.";
private _items=["RscListbox",101,[0.19,0.285,0.23,0.41]]call _make;
private _picture=["RscPicture",102,[0.43,0.235,0.27,0.19]]call _make;
private _details=["RscStructuredText",103,[0.43,0.435,0.27,0.29]]call _make;
private _add=["RscButtonMenu",107,[0.43,0.735,0.27,0.045],"Добавить в заказ"]call _make;
private _total=["RscStructuredText",108,[0.72,0.235,0.26,0.055]]call _make;
private _queue=["RscListbox",109,[0.72,0.30,0.26,0.24]]call _make;
private _remove=["RscButtonMenu",110,[0.72,0.55,0.125,0.045],"Убрать"]call _make;
private _clear=["RscButtonMenu",111,[0.855,0.55,0.125,0.045],"Очистить"]call _make;
private _delivery=["RscStructuredText",116,[0.72,0.61,0.26,0.10],"Техника поступает на свою базу.<br/>Пехота присоединяется к вашей группе.<br/>До 8 позиций в одном заказе."]call _make;
private _order=["RscButtonMenu",112,[0.72,0.735,0.26,0.045],"Заказать"]call _make;
private _map=["RscMapControl",114,[0.43,0.235,0.55,0.46]]call _make;
_map ctrlMapSetPosition [];
private _sectorDetails=["RscStructuredText",118,[0.43,0.705,0.38,0.075]]call _make;
private _sectorAction=["RscButtonMenu",117,[0.82,0.735,0.16,0.045],"Голосовать"]call _make;
private _status=["RscStructuredText",105,[0.02,0.79,0.80,0.065]]call _make;
private _close=["RscButtonMenu",113,[0.84,0.805,0.14,0.045],"Закрыть"]call _make;
_d setVariable["NeroCQ_assetControls",[_picture,_details,_add,_total,_queue,_remove,_clear,_delivery,_order]];
_d setVariable["NeroCQ_sectorControls",[_map,_sectorDetails,_sectorAction]];
_categories ctrlAddEventHandler["LBSelChanged",{
 params["_c","_i"];private _d=ctrlParent _c;
 _d setVariable["NeroCQ_category",_c lbValue _i];_d setVariable["NeroCQ_listSignature",[]];
 [_d]call NeroWL_Design_fnc_cqMenuRefresh;
}];
_items ctrlAddEventHandler["LBSelChanged",{[ctrlParent(_this#0)]call NeroWL_Design_fnc_cqMenuRefresh;}];
_items ctrlAddEventHandler["LBDblClick",{[ctrlParent(_this#0),"ADD"]call NeroWL_Design_fnc_cqMenuAction;}];
_queue ctrlAddEventHandler["LBSelChanged",{[ctrlParent(_this#0)]call NeroWL_Design_fnc_cqMenuRefresh;}];
_search ctrlAddEventHandler["KeyUp",{[ctrlParent(_this#0)]call NeroWL_Design_fnc_cqMenuRefresh;}];
_search ctrlAddEventHandler["SetFocus",{(ctrlParent(_this#0))setVariable["NeroCQ_searchFocus",true];}];
_search ctrlAddEventHandler["KillFocus",{(ctrlParent(_this#0))setVariable["NeroCQ_searchFocus",false];}];
{(_d displayCtrl(_x#0))ctrlAddEventHandler["ButtonClick",_x#1];}forEach[
 [107,{[ctrlParent(_this#0),"ADD"]call NeroWL_Design_fnc_cqMenuAction;}],
 [110,{[ctrlParent(_this#0),"REMOVE"]call NeroWL_Design_fnc_cqMenuAction;}],
 [111,{[ctrlParent(_this#0),"CLEAR"]call NeroWL_Design_fnc_cqMenuAction;}],
 [112,{[ctrlParent(_this#0),"ORDER"]call NeroWL_Design_fnc_cqMenuAction;}],
 [117,{[ctrlParent(_this#0),"SECTOR"]call NeroWL_Design_fnc_cqMenuAction;}],
 [113,{(ctrlParent(_this#0))closeDisplay 1;}]
];
_map ctrlAddEventHandler["MouseButtonDown",{
 params["_map","_button","_mx","_my"];if(_button!=0)exitWith{false};
 private _d=ctrlParent _map;private _best=0.035;private _choice=-1;
 {private _screen=_map ctrlMapWorldToScreen getPosATL(_x#1);private _distance=_screen distance2D[_mx,_my];if(_distance<_best)then{_best=_distance;_choice=_forEachIndex;};}forEach(_d getVariable["NeroCQ_rows",[]]);
 if(_choice>=0)then{(_d displayCtrl 101)lbSetCurSel _choice;};false
}];
_map ctrlAddEventHandler["Draw",{
 private _map=_this#0;private _chosen=(ctrlParent _map)getVariable["NeroCQ_sector",objNull];
 {
  private _side=_x getVariable["BIS_WL_sectorSide",sideUnknown];
  private _color=switch(_side)do{case west:{[0.25,0.55,1,1]};case east:{[1,0.3,0.3,1]};default{[0.25,0.8,0.35,1]};};
  private _radius=_x getVariable["Size",200];private _pos=getPosATL _x;
  _map drawEllipse[_pos,_radius,_radius,0,_color,""];
  _map drawIcon["",_color,_pos,0,0,0,_x getVariable["Name",""],1,0.032,"RobotoCondensed"];
  if(_x==_chosen)then{_map drawEllipse[_pos,_radius*1.2,_radius*1.2,0,[1,1,1,1],""];};
 }forEach(missionNamespace getVariable["BIS_WL_sectors",[]]);
 _map drawIcon["\a3\ui_f\data\Map\VehicleIcons\iconMan_ca.paa",[1,1,1,1],getPosATL player,14,14,getDir player,"Вы",1,0.03,"RobotoCondensed"];
}];
_d displayAddEventHandler["KeyDown",{params["_d","_key"];if(_key in actionKeys "Gear" && {!(_d getVariable["NeroCQ_searchFocus",false])})exitWith{if(!(missionNamespace getVariable["NeroWL_CQgearHeld",false]))then{_d closeDisplay 1;};true};false}];
_d displayAddEventHandler["KeyUp",{if((_this#1)in actionKeys "Gear")then{missionNamespace setVariable["NeroWL_CQgearHeld",false];};false}];
_d displayAddEventHandler["Unload",{uiNamespace setVariable["NeroWL_CQmenu",displayNull];missionNamespace setVariable["NeroWL_CQgearHeld",false];}];
_categories lbSetCurSel 0;
[_d]call NeroWL_Design_fnc_cqMenuRefresh;
[_d]spawn{disableSerialization;params["_display"];while{!isNull _display}do{[_display]call NeroWL_Design_fnc_cqMenuRefresh;uiSleep 0.5;};};
diag_log format["[NeroWL CQ] MENU OPEN side=%1 interface=2",side group player];
