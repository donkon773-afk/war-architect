/* A malformed or obsolete purchase must never block a whole factory.
   The original eight-field queue and completion callback are preserved. */
private _factory=_this;
if (!isServer || {isNull _factory} || {_factory getVariable ["cti_inuse",false]}) exitWith {};
_factory setVariable ["cti_inuse",true,true];
while {alive _factory} do {
    private _list=_factory getVariable ["cti_queue_processing",[]];
    if (count _list==0) exitWith {};
    private _request=_list#0;
    if (_request isEqualType []) then {_request=+_request;};
    private _valid=_request isEqualType [] && {count _request==8} &&
        {!isNil {_request#0}} && {(_request#0) isEqualType 0} &&
        {!isNil {_request#1}} && {(_request#1) isEqualType ""} &&
        {!isNil {_request#2}} && {(_request#2) isEqualType 0} && {finite (_request#2)} && {(_request#2)>=0} &&
        {!isNil {_request#3}} && {!isNil {_request#4}} &&
        {!isNil {_request#5}} && {(_request#5) isEqualType true} &&
        {!isNil {_request#6}} && {(_request#6) isEqualType []} &&
        {!isNil {_request#7}} && {(_request#7) in [west,east]};
    if (!_valid) then {
        diag_log format ["[WA BECTI QUEUE] DROP malformed factory=%1 request=%2",_factory,_request];
        _list deleteAt 0;_factory setVariable ["cti_queue_processing",_list];
    } else {
        _request params ["_seed","_class","_duration","_buyer","_target","_toAI","_infos","_side"];
        private _deadline=time+_duration+60;
        if (missionNamespace getVariable ["CTI_Debug",false]) then {_deadline=time+15;};
        if (_toAI) then {
            [_seed,_class,_buyer,_target,_factory,_side] spawn CTI_SE_FNC_HandleAIPurchase;
        } else {
            if (!(_target isEqualType west)) then {
                [["CLIENT",_buyer],"Client_OnPurchaseOrderReceived",[_seed,_class,_buyer,_factory,_infos]] call CTI_CO_FNC_NetSend;
            };
        };
        waitUntil {
            sleep 0.25;
            !alive _factory || {time>_deadline} ||
            {(_factory getVariable ["cti_queue_processing",[]]) findIf {count _x>1 && {(_x#0) isEqualTo _seed} && {(_x#1) isEqualTo _class}}<0}
        };
        // Remove the matching request only: completion may already have advanced the queue.
        isNil {
            private _pending=_factory getVariable ["cti_queue_processing",[]];
            private _index=_pending findIf {count _x>1 && {(_x#0) isEqualTo _seed} && {(_x#1) isEqualTo _class}};
            if (_index>=0) then {
                diag_log format ["[WA BECTI QUEUE] TIMEOUT class=%1 factory=%2",_class,_factory];
                _pending deleteAt _index;_factory setVariable ["cti_queue_processing",_pending];
            };
        };
    };
    _factory setVariable ["cti_queue_processing_count",count (_factory getVariable ["cti_queue_processing",[]])];
};
// Atomic release prevents a concurrent enqueue from being lost at shutdown.
isNil {
    _factory setVariable ["cti_inuse",nil,true];
    if (alive _factory && {count (_factory getVariable ["cti_queue_processing",[]])>0}) then {
        _factory spawn CTI_SE_FNC_StartFactoryQueue;
    } else {
        _factory setVariable ["cti_queue_processing",nil];
        _factory setVariable ["cti_queue_processing_count",nil];
    };
};
