/* One server dispatcher, bounded FIFO. Never retry a started paid operation. */
if (!isServer) exitWith {};
private _now = diag_tickTime;
if (_now < (missionNamespace getVariable ["NeroWL_purchaseWorkerUntil",0])) exitWith {};
private _queue = +(missionNamespace getVariable ["NeroWL_purchaseQueue",[]]);
private _remove = [];private _dispatched = false;
{
    _x params ["_id","_group","_kind","_source","_token","_at","_until",["_state","QUEUED"]];
    private _valid = [_group] call NeroAI_fnc_validateGroup;
    private _wl = if (_valid) then {((units _group) select {_x in (missionNamespace getVariable ["BIS_WL_allWarlords",[]])}) param [0,objNull]} else {objNull};
    private _manual = _group getVariable ["NeroAI_playerHold",false] || {_now < (_group getVariable ["NeroAI_manualOrderUntil",0])};
    private _base = missionNamespace getVariable [format ["BIS_WL_base_%1",side _group],objNull];
    private _atBase = !isNull _base && {(_base getVariable ["BIS_WL_sectorSide",sideUnknown]) isEqualTo side _group} && {_wl distance2D _base <= ((_base getVariable ["Size",300])/2)};
    private _flight = missionNamespace getVariable [format ["NeroWL_dropFlight_%1",side _group],objNull];
    private _flightBusy = _kind == "INFANTRY" && {!_atBase} && {!isNull _flight} && {alive _flight};
    private _busy = _dispatched || {_group getVariable ["NeroWL_vehicleService",false]} || {_now < (_group getVariable ["NeroWL_logisticsUntil",0])}
        || {_now < (_group getVariable ["NeroAI_purchaseHoldUntil",0])} || {_wl getVariable ["BIS_WL_AI_airdropping",false]} || {_flightBusy};
    private _next = (missionNamespace getVariable ["NeroAI_purchaseSideNextAllowed",createHashMap]) getOrDefault [str side _group,0];
    private _action = [_now,_until,(_group getVariable ["NeroAI_opToken",0]) == _token,_valid && {!isNull _wl},_manual,_source in ["PLAYER","PLAYER_DEFERRED"],_busy,_next,_state == "RUNNING"] call NeroAI_fnc_logisticsQueueAction;
    if (_action != "WAIT") then {
        private _message = _action;
        if (_action == "DISPATCH") then {
            _dispatched = true;
            missionNamespace setVariable ["NeroWL_purchaseWorkerUntil",_now+30];
            private _live = missionNamespace getVariable ["NeroWL_purchaseQueue",[]];
            private _index = _live findIf {(_x # 0) == _id};
            if (_index >= 0) then {(_live # _index) set [7,"RUNNING"];missionNamespace setVariable ["NeroWL_purchaseQueue",_live];};
            private _result = [_group,_kind,_source,true,_token] call NeroAI_fnc_purchaseAsset;
            if (!isNil "_result" && {_result isEqualType []} && {count _result >= 2}) then {_action = if (_result # 0) then {if (isNull (_group getVariable ["NeroWL_supplyFlight",objNull])) then {"DELIVERED"} else {"IN_TRANSIT"}} else {"FAILED"};_message = _result # 1;} else {_action = "UNCERTAIN";_message = "Исполнитель не подтвердил результат; автоматического повтора нет.";};
            missionNamespace setVariable ["NeroWL_purchaseWorkerUntil",0];
        };
        _remove pushBack _id;
        if (!isNull _group) then {
            if (_action != "IN_TRANSIT" && {((_group getVariable ["NeroWL_pendingPurchase",[]]) param [0,""]) == _id}) then {_group setVariable ["NeroWL_pendingPurchase",nil,true];};
            if (_action == "UNCERTAIN") then {_group setVariable ["NeroWL_purchaseBlocked",true,true];};
            _group setVariable ["NeroWL_purchaseResult",[_id,_action,_message,diag_tickTime],true];
            ["INFO",format ["LOGISTICS %1 %2 %3: %4",_id,groupId _group,_action,_message]] call NeroAI_fnc_log;
        };
    };
} forEach _queue;
private _live = missionNamespace getVariable ["NeroWL_purchaseQueue",[]];
missionNamespace setVariable ["NeroWL_purchaseQueue",_live select {!((_x # 0) in _remove)}];
