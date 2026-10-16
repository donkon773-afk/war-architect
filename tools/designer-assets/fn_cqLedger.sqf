/* Pure request state transition, also executed in SQF-VM regression tests. */
params["_mode","_history","_highest","_id","_unitId",["_result",[]]];
_history=+_history;
private _unchanged=[false,_history,_highest,[]];
if(!(_id isEqualType "") || {count _id<1} || {count _id>80})exitWith{_unchanged};
private _index=_history findIf{(_x#0)==_id};
if(_mode=="BEGIN")exitWith{
 if(_index>=0)exitWith{
  private _entry=_history#_index;[false,_history,_highest,if(_entry#4)then{_entry select[0,4]}else{[]}]
 };
 private _parts=_id splitString ":";if(_parts isEqualTo [])exitWith{_unchanged};private _serial=parseNumber(_parts#(count _parts-1));
 if(_serial<1 || {_serial>1000000000} || {_serial!=floor _serial} || {_id!=format["%1:%2",_unitId,_serial]})exitWith{_unchanged};
 if(_serial<=_highest)exitWith{[false,_history,_highest,[_id,false,"Устаревший запрос не выполнен.",0]]};
 if(count _history>=32)then{_history deleteAt 0;};
 _history pushBack[_id,false,"",0,false];[true,_history,_serial,[]]
};
if(_mode!="END" || {_index<0} || {count _result!=3} || {!((_result#0)isEqualType true)} || {!((_result#1)isEqualType "")} || {!((_result#2)isEqualType 0)} || {(_result#2)<0} || {(_result#2)>8} || {(_result#2)!=floor(_result#2)})exitWith{_unchanged};
private _old=_history#_index;
if(_old#4)exitWith{[false,_history,_highest,_old select[0,4]]};
private _receipt=[_id,_result#0,_result#1,_result#2];_history set[_index,_receipt+[true]];
[true,_history,_highest,_receipt]
