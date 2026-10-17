// Public RPC: all prices, classes, side and delivery location are server-owned.
params ["_buyer","_rows","_id"];
if (!isServer || {isNull _buyer} || {!isPlayer _buyer} || {!alive _buyer} || {isRemoteExecuted && {remoteExecutedOwner!=owner _buyer}}) exitWith {};
if (!(_id isEqualType 0) || {!finite _id} || {_id<0} || {!(_rows isEqualType [])} || {count _rows==0} || {_rows findIf {!(_x isEqualType []) || {count _x!=2} || {!((_x#0) isEqualType 0)} || {!((_x#1) isEqualType true)}}>=0}) exitWith {};
private _seen=_buyer getVariable ["WA_BECTI_orderSeen",[]];
if (_id in _seen) exitWith {};
if (group _buyer getVariable ["WA_BECTI_orderBusy",false]) exitWith {_buyer setVariable ["WA_BECTI_orderResult",[_id,[[false,"Предыдущий заказ ещё выполняется"]],true],true];};
_seen pushBack _id;if (count _seen>128) then {_seen deleteAt 0;};_buyer setVariable ["WA_BECTI_orderSeen",_seen];
private _group=group _buyer;_group setVariable ["WA_BECTI_orderBusy",true,true];
[_buyer,+_rows,_id,_group] spawn {
    params ["_buyer","_rows","_id","_group"];
    private _results=[];private _purchase=compile preprocessFileLineNumbers "warArchitect\shopPurchase.sqf";
    {
        private _result=if (isNull _buyer || {!alive _buyer} || {group _buyer!=_group}) then {[false,"Покупатель недоступен или сменил отряд"]} else {[_buyer,_x#0,_x#1] call _purchase};
        _results pushBack _result;
        _buyer setVariable ["WA_BECTI_orderResult",[_id,+_results,false],true];
        sleep 0.05;
    } forEach _rows;
    _group setVariable ["WA_BECTI_orderBusy",false,true];
    if (!isNull _buyer) then {_buyer setVariable ["WA_BECTI_orderResult",[_id,_results,true],true];};
};
