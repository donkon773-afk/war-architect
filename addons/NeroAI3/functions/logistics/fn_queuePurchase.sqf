/* Called after a non-paying catalogue/price preflight. All jobs revalidate. */
params ["_group","_kind","_source"];
if (!isServer || {!([_group] call NeroAI_fnc_validateGroup)}) exitWith {[false,"Очередь: группа недоступна."]};
if ((_group getVariable ["NeroWL_pendingPurchase",[]]) isNotEqualTo []) exitWith {[false,"У группы уже есть ожидающий заказ или физическая доставка в пути."]};
private _result = [false,"Очередь недоступна."];
isNil {
    private _queue = missionNamespace getVariable ["NeroWL_purchaseQueue",[]];
    private _admission = [_queue apply {netId (_x # 1)},netId _group,64] call NeroAI_fnc_queueAdmission;
    if (_admission == "DUPLICATE") exitWith {_result = [false,"У группы уже есть заказ в очереди."];};
    if (_admission == "FULL") exitWith {_result = [false,"Очередь подкреплений заполнена; CP не списаны."];};
    private _seq = (missionNamespace getVariable ["NeroWL_purchaseSequence",0])+1;
    missionNamespace setVariable ["NeroWL_purchaseSequence",_seq];
    private _id = format ["BUY-%1",_seq];private _now = diag_tickTime;
    private _job = [_id,_group,_kind,_source,_group getVariable ["NeroAI_opToken",0],_now,_now+300,"QUEUED"];
    _queue pushBack _job;missionNamespace setVariable ["NeroWL_purchaseQueue",_queue];
    _group setVariable ["NeroWL_pendingPurchase",[_id,_now+300],true];
    _group setVariable ["NeroWL_purchaseResult",[_id,"QUEUED","CP ещё не списаны",_now],true];
    _result = [true,format ["Заказ %1 поставлен в очередь; перед выполнением повторно проверим условия. CP ещё не списаны.",_id]];
};
_result
