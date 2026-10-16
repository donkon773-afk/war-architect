disableSerialization;
params["_d","_action"];
if(isNull _d)exitWith{};
private _unit=_d getVariable["NeroCQ_unit",objNull];
if(isNull _unit || {_unit!=player} || {!alive _unit} || {side group _unit!=(_d getVariable["NeroCQ_side",sideUnknown])})exitWith{_d closeDisplay 1;};
private _queue=+(_unit getVariable["NeroWL_CQuiQueue",[]]);private _pending=_unit getVariable["NeroWL_CQuiPending",[]];
private _rows=_d getVariable["NeroCQ_rows",[]];private _index=lbCurSel(_d displayCtrl 101);
private _row=if(_index<0)then{[]}else{_rows param[_index,[]]};
if(_pending isNotEqualTo [] && {_action in ["ORDER","SECTOR"]})exitWith{
 if(diag_tickTime-(_pending#2)>=12)then{
  switch(_pending#1)do{
   case "BUY":{(_pending#3)remoteExecCall["NeroWL_Design_fnc_cqBuy",2];};
   case "VOTE":{(_pending#3)remoteExecCall["NeroWL_Design_fnc_cqVote",2];};
   case "TRAVEL":{(_pending#3)remoteExecCall["NeroWL_Design_fnc_cqTravel",2];};
  };
  _pending set[2,diag_tickTime];_unit setVariable["NeroWL_CQuiPending",_pending];
  _d setVariable["NeroCQ_notice","Проверяем прежний запрос. Повторного списания CP не будет."];
 };
 [_d]call NeroWL_Design_fnc_cqMenuRefresh;
};
if(_pending isNotEqualTo [])exitWith{};
switch(_action)do{
 case "ADD":{
  if(count _row==0 || {(_row#0)!="BUY"})exitWith{};
  if(!ctrlEnabled(_d displayCtrl 107))exitWith{};
  if(count _queue>=8)exitWith{_d setVariable["NeroCQ_notice","В одном заказе может быть не больше 8 позиций."];};
  _queue pushBack(_row#1);_unit setVariable["NeroWL_CQuiQueue",_queue];
 };
 case "REMOVE":{private _i=lbCurSel(_d displayCtrl 109);if(_i>=0 && {_i<count _queue})then{_queue deleteAt _i;_unit setVariable["NeroWL_CQuiQueue",_queue];};};
 case "CLEAR":{_unit setVariable["NeroWL_CQuiQueue",[]];};
 case "ORDER";
 case "SECTOR":{
  private _mode="BUY";private _packet=[];
  private _serial=(missionNamespace getVariable["NeroWL_CQuiSerial",0])+1;
  missionNamespace setVariable["NeroWL_CQuiSerial",_serial];private _id=format["%1:%2",netId _unit,_serial];
  if(_action=="ORDER")then{
   if(count _queue>0)then{_packet=[_unit,+_queue,_id];};
  }else{
   if(count _row>0 && {(_row#0)in ["TARGET","TRAVEL"]})then{
    _mode=if((_row#0)=="TARGET")then{"VOTE"}else{"TRAVEL"};
    _packet=if(_mode=="VOTE")then{[_unit,_row#1,_id]}else{[_unit,_row#1,"TRAVEL",_id]};
   };
  };
  if(_packet isEqualTo [])exitWith{};
  _unit setVariable["NeroWL_CQuiPending",[_id,_mode,diag_tickTime,_packet]];
  _d setVariable["NeroCQ_notice","Ожидаем подтверждение сервера…"];
  switch(_mode)do{
   case "BUY":{_packet remoteExecCall["NeroWL_Design_fnc_cqBuy",2];};
   case "VOTE":{_packet remoteExecCall["NeroWL_Design_fnc_cqVote",2];};
   case "TRAVEL":{_packet remoteExecCall["NeroWL_Design_fnc_cqTravel",2];};
  };
 };
};
[_d]call NeroWL_Design_fnc_cqMenuRefresh;
