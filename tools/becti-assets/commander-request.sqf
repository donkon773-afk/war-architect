params ["_buyer","_request"];
if (!isServer || {isNull _buyer} || {!isPlayer _buyer} || {isRemoteExecuted && {remoteExecutedOwner!=owner _buyer}} || {!(_request isEqualType 0)} || {!finite _request}) exitWith {};
private _result=[false,"Не удалось принять командование"];
// This RPC is unscheduled: two clients cannot both claim an empty seat.
private _group=group _buyer;private _side=side _group;
if (alive _buyer && {_side in [west,east]} && {leader _group==_buyer}) then {
    private _logic=_side call CTI_CO_FNC_GetSideLogic;private _hq=_side call CTI_CO_FNC_GetSideHQ;
    private _commander=_side call CTI_CO_FNC_GetSideCommander;
    private _blacklist=(_logic getVariable ["CTI_COM_BLACKLIST",[]])+(_logic getVariable ["CTI_COM_BLACKLIST_GLOBAL",[]]);
    if (getPlayerUID _buyer in _blacklist) then {_result=[false,"Назначение ограничено штатным голосованием BECTI"];} else {
        if (_commander==_group) then {_result=[true,"Вы уже командир стороны"];} else {
            if (!isNull _commander && {isPlayer leader _commander}) then {_result=[false,"Командование занято другим игроком"];} else {
                if (!alive _hq || {_buyer distance2D _hq>400}) then {_result=[false,"Примите командование на основной базе возле HQ"];} else {
                    _logic setVariable ["cti_commander",_group,true];_logic setVariable ["CTI_COM_VOTES",[],true];
                    _result=[true,"Командование принято"];
                    diag_log format ["[WarArchitect BECTI COMMAND] assigned side=%1 uid=%2 group=%3",_side,getPlayerUID _buyer,_group];
                };
            };
        };
    };
} else {_result=[false,"Нужно быть живым командиром своего отряда"]};
_buyer setVariable ["WA_BECTI_commandResult",[_request,_result#0,_result#1],true];
