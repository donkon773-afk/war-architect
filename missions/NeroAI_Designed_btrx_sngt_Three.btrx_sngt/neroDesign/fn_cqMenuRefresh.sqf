disableSerialization;
params["_d"];
if(isNull _d || {_d getVariable["NeroCQ_refreshing",false]})exitWith{};
private _unit=_d getVariable["NeroCQ_unit",objNull];private _side=_d getVariable["NeroCQ_side",sideUnknown];
if(isNull _unit || {_unit!=player} || {!alive _unit} || {side group _unit!=_side})exitWith{_d closeDisplay 1;};
_d setVariable["NeroCQ_refreshing",true];
private _pending=_unit getVariable["NeroWL_CQuiPending",[]];private _queue=+(_unit getVariable["NeroWL_CQuiQueue",[]]);
if(count _pending>0)then{
 private _receipt=_unit getVariable["NeroWL_CQreceipt",[]];
 if(count _receipt==4 && {(_receipt#0)==(_pending#0)})then{
  _d setVariable["NeroCQ_notice",_receipt#2];
  if((_pending#1)=="BUY" && {(_receipt#3)>0})then{_queue deleteRange[0,(_receipt#3)min count _queue];_unit setVariable["NeroWL_CQuiQueue",_queue];};
  _pending=[];_unit setVariable["NeroWL_CQuiPending",[]];
 };
};
private _busy=count _pending>0;private _retry=_busy && {diag_tickTime-(_pending#2)>=12};
private _category=_d getVariable["NeroCQ_category",0];private _isAsset=_category>=0;
private _query=toLower ctrlText(_d displayCtrl 115);private _catalog=missionNamespace getVariable["BIS_WL_purchasable"+str _side,[]];
private _catalogKey=str _catalog;private _all=_d getVariable["NeroCQ_flatCatalog",[]];
if(_catalogKey!=(_d getVariable["NeroCQ_catalogKey",""]))then{_all=[_catalog]call NeroWL_Design_fnc_cqCatalog;_d setVariable["NeroCQ_catalogKey",_catalogKey];_d setVariable["NeroCQ_flatCatalog",_all];};
private _rows=[];
if(_isAsset)then{
 {if((_x#0)==_category && {_query=="" || {(toLower((_x#4)+" "+(_x#1)))find _query>=0}})then{_rows pushBack["BUY",_x#1,_x#2,_x#3,_x#4];};}forEach _all;
}else{
 private _targets=if(_category==-1)then{[_side]call NeroWL_Design_fnc_cqTargets}else{(missionNamespace getVariable["BIS_WL_sectors",[]])select{(_x getVariable["BIS_WL_sectorSide",sideUnknown])==_side}};
 {private _name=_x getVariable["Name",""];if(_query=="" || {(toLower _name)find _query>=0})then{_rows pushBack[if(_category==-1)then{"TARGET"}else{"TRAVEL"},_x,_name];};}forEach _targets;
};
private _list=_d displayCtrl 101;private _oldRows=_d getVariable["NeroCQ_rows",[]];
private _oldIndex=lbCurSel _list;private _oldRow=if(_oldIndex<0)then{[]}else{_oldRows param[_oldIndex,[]]};
private _oldKey=if(count _oldRow>0)then{_oldRow#1}else{""};private _signature=[_category,_query,_rows];
if(_signature isNotEqualTo (_d getVariable["NeroCQ_listSignature",[]]))then{
 lbClear _list;
 {private _text=if(_isAsset)then{format["%1 · %2 CP",_x#4,_x#2]}else{_x#2};private _i=_list lbAdd _text;_list lbSetTooltip[_i,_text];}forEach _rows;
 _d setVariable["NeroCQ_rows",_rows];_d setVariable["NeroCQ_listSignature",_signature];
 private _selected=_rows findIf{(_x#1)isEqualTo _oldKey};if(count _rows>0)then{_list lbSetCurSel(0 max _selected);};
};
{_x ctrlShow _isAsset;}forEach(_d getVariable["NeroCQ_assetControls",[]]);
{_x ctrlShow(!_isAsset);}forEach(_d getVariable["NeroCQ_sectorControls",[]]);
(_d displayCtrl 9903)ctrlShow _isAsset;(_d displayCtrl 9904)ctrlShow _isAsset;
private _funds=_unit getVariable["BIS_WL_funds",0];private _income=getNumber(missionConfigFile >> "CfgNeroDesign" >> "income");
private _sectors=missionNamespace getVariable["BIS_WL_sectors",[]];private _owned={(_x getVariable["BIS_WL_sectorSide",sideUnknown])==_side}count _sectors;
private _sideName=switch(_side)do{case west:{"Синие"};case east:{"Красные"};default{"Зелёные"};};
(_d displayCtrl 106)ctrlSetStructuredText parseText format["<t size='1.2'>WARLORDS · %1</t><t align='right'>%2 CP · +%3 CP/мин</t>",_sideName,round _funds,_owned*_income];
private _selectedIndex=lbCurSel _list;private _row=if(_selectedIndex<0)then{[]}else{_rows param[_selectedIndex,[]]};
if(_isAsset)then{
 private _details="В этой категории нет выбранных позиций.";private _picture="";private _available=count _row>0;
 if(_available)then{
  private _class=_row#1;private _cfg=configFile >> "CfgVehicles" >> _class;_picture=getText(_cfg >> "picture");
  private _requirements=(_row#3)joinString ", ";if(_requirements=="")then{_requirements="Нет";};
  private _name=[_row#4]call NeroWL_Design_fnc_cqText;private _label=[_class]call NeroWL_Design_fnc_cqText;
  _details=format["<t size='1.2'>%1</t><br/><br/>Стоимость: %2 CP<br/>Требования: %3<br/><br/><t color='#aaaaaa'>%4</t>",_name,_row#2,[_requirements]call NeroWL_Design_fnc_cqText,_label];
  if(_class isKindOf "Air" && {!(missionNamespace getVariable["NeroAI_airEnabled",true]) || {(missionNamespace getVariable["NeroWL_airLimit",5])<=0}})then{_available=false;_details=_details+"<br/><br/><t color='#ff9999'>Авиация отключена настройками сценария.</t>";};
 };
 (_d displayCtrl 102)ctrlSetText _picture;(_d displayCtrl 103)ctrlSetStructuredText parseText _details;
 (_d displayCtrl 107)ctrlEnable(_available && {!_busy} && {count _queue<8});
};
private _queueCtrl=_d displayCtrl 109;private _total=0;private _queueSignature=[_queue,_all];
if(_queueSignature isNotEqualTo (_d getVariable["NeroCQ_queueSignature",[]]))then{
 private _selection=lbCurSel _queueCtrl;lbClear _queueCtrl;
 {private _class=_x;private _i=_all findIf{(_x#1)==_class};private _data=if(_i<0)then{[-1,_class,0,[],_class]}else{_all#_i};_queueCtrl lbAdd format["%1 · %2 CP",_data#4,_data#2];}forEach _queue;
 if(count _queue>0)then{_queueCtrl lbSetCurSel(0 max (_selection min(count _queue-1)));};
 _d setVariable["NeroCQ_queueSignature",_queueSignature];
};
{private _class=_x;private _i=_all findIf{(_x#1)==_class};if(_i>=0)then{_total=_total+((_all#_i)#2);};}forEach _queue;
(_d displayCtrl 108)ctrlSetStructuredText parseText format["%1/8 позиций · <t size='1.2'>%2 CP</t>",count _queue,_total];
(_d displayCtrl 110)ctrlEnable(!_busy && {lbCurSel _queueCtrl>=0});(_d displayCtrl 111)ctrlEnable(!_busy && {count _queue>0});
(_d displayCtrl 112)ctrlEnable(_retry || {!_busy && {count _queue>0} && {_total<=_funds}});
(_d displayCtrl 112)ctrlSetText(if(_retry)then{"Проверить заказ"}else{"Заказать"});
if(!_isAsset)then{
 private _target=if(count _row>0)then{_row#1}else{objNull};_d setVariable["NeroCQ_sector",_target];private _details="Нет доступных секторов.";
 if(!isNull _target)then{
  private _name=[_target getVariable["Name",""]]call NeroWL_Design_fnc_cqText;
  private _owner=_target getVariable["BIS_WL_sectorSide",sideUnknown];private _label=switch(_owner)do{case west:{"Синие"};case east:{"Красные"};default{"Зелёные"};};
  _details=format["<t size='1.1'>%1</t> · %2 · %3 CP/мин",_name,_label,_income];
  if(_target!=(_d getVariable["NeroCQ_mapFocus",objNull]))then{private _map=_d displayCtrl 114;_map ctrlMapAnimAdd[0.3,0.15,getPosATL _target];ctrlMapAnimCommit _map;_d setVariable["NeroCQ_mapFocus",_target];};
 };
 if(_category==-1)then{
  private _vote=missionNamespace getVariable[format["NeroWL_CQvote_%1",_side],[0,objNull,0,0]];
  if((_vote#0)>serverTime)then{_details=_details+format["<br/>Голосование: %1 с · %2 голосов",ceil((_vote#0)-serverTime),_vote#3];};
 }else{private _left=0 max ceil(60-(serverTime-(_unit getVariable["NeroWL_lastTravel",-100])));_details=_details+format["<br/>На ногах · вне ближнего боя · пауза %1 с",_left];};
 (_d displayCtrl 118)ctrlSetStructuredText parseText _details;
 (_d displayCtrl 117)ctrlSetText(if(_retry)then{"Проверить запрос"}else{if(_category==-1)then{"Голосовать"}else{"Переместиться"}});
 (_d displayCtrl 117)ctrlEnable(_retry || {!_busy && {!isNull _target}});
};
private _notice=_d getVariable["NeroCQ_notice",""];
if(_retry)then{_notice="Подтверждение задерживается. «Проверить запрос» повторит прежний запрос без новой покупки.";};
(_d displayCtrl 105)ctrlSetStructuredText parseText([_notice]call NeroWL_Design_fnc_cqText);
_d setVariable["NeroCQ_refreshing",false];
