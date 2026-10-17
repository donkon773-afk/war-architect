/* One authenticated sequential order per player. Prices and availability stay server-owned.
   Partial fulfillment is explicit: failed rows are retained by the client for review. */
params [["_unit",objNull,[objNull]],["_rows",[],[[]]],["_request",-1,[0]]];
if (!isServer || {isNull _unit} || {!isPlayer _unit} || {!alive _unit} || {isRemoteExecuted && {remoteExecutedOwner!=owner _unit}} || {_unit getVariable ["NeroOP_cartBusy",false]} || {!NeroOP_campReady} || {NeroOP_campFinished}) exitWith {};
if (_request<0 || {floor _request!=_request} || {_request==(_unit getVariable ["NeroOP_cartLastId",-1])}) exitWith {};
if (count _rows==0 || {_rows findIf {!(_x isEqualType []) || {count _x!=2} || {!((_x#0) isEqualType "")} || {!((_x#1) isEqualType 0)} || {floor (_x#1)!=(_x#1)} || {(_x#1)<0} || {!((_x#0) in ["BUY","BUY_EMPTY","GEAR","RECRUIT","TRUCK","REINFORCE"])}}>=0}) exitWith {};
_unit setVariable ["NeroOP_cartLastId",_request];
_unit setVariable ["NeroOP_cartBusy",true,true];
_unit setVariable ["NeroOP_cartResult",[[],0,count _rows,false,_request],true];
[_unit,+_rows,_request] spawn {
 params ["_unit","_rows","_request"];private _results=[];
 {
  if (isNull _unit || {!alive _unit} || {!isPlayer _unit} || {NeroOP_campFinished}) exitWith {};
  private _wait=3.1-(serverTime-(_unit getVariable ["NeroOP_equipmentAt",-100]));if (_wait>0) then {sleep _wait;};
  private _before=_unit getVariable ["NeroOP_receiptSeq",0];
  [_unit,_x#0,_x#1] call NeroOP_fnc_campaignEquipmentAction;
  private _r=_unit getVariable ["NeroOP_shopReceipt",[0,false,"Заказ не выполнен: состояние игрока или миссии изменилось."]];
  if ((_r#0)<=_before) then {_r=[0,false,"Заказ не выполнен: состояние игрока или миссии изменилось."];};
  _results pushBack [_r#1,_r#2];
  _unit setVariable ["NeroOP_cartResult",[+_results,count _results,count _rows,false,_request],true];
 } forEach _rows;
 if (!isNull _unit) then {_unit setVariable ["NeroOP_cartResult",[+_results,count _results,count _rows,true,_request],true];_unit setVariable ["NeroOP_cartBusy",false,true];};
};
