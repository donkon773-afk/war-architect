/* Local server helper only. Replies cannot grant funds or spawn anything. */
params["_mode","_unit","_id",["_result",[]]];
if(!isServer || {isNull _unit} || {!(_id isEqualType "")} || {count _id<1} || {count _id>80})exitWith{false};
// New requests run unscheduled; a monotonic serial also rejects evicted old IDs.
private _next=[_mode,_unit getVariable["NeroWL_CQrequests",[]],_unit getVariable["NeroWL_CQrequestSerial",0],_id,netId _unit,_result]call NeroWL_Design_fnc_cqLedger;
_unit setVariable["NeroWL_CQrequests",_next#1];_unit setVariable["NeroWL_CQrequestSerial",_next#2];
if(count(_next#3)==4)then{_unit setVariable["NeroWL_CQreceipt",_next#3,true];};
if(_mode=="END" && {_next#0})then{diag_log format["[NeroWL CQ] REQUEST id=%1 side=%2 ok=%3 completed=%4 message=%5",_id,side group _unit,_result#0,_result#2,_result#1];};
_next#0
