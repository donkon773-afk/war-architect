params ["_buyer","_request"];
if (!isServer || {isNull _buyer} || {!isPlayer _buyer} ||
    {isRemoteExecuted && {remoteExecutedOwner!=owner _buyer}} ||
    {!(_request isEqualType 0)} || {!finite _request}) exitWith {};
private _host=!isDedicated && {_buyer isEqualTo player};
private _allowed=_host || {admin (owner _buyer)>0};
private _result=[false,"Zeus доступен хосту или администратору сервера"];
if (_allowed && {alive _buyer}) then {
    private _logic=missionNamespace getVariable ["ADMIN_ZEUS",objNull];
    if (isNull _logic) then {_result=[false,"Модуль Zeus ещё подготавливается"];} else {
        private _assigned=getAssignedCuratorUnit _logic;
        if (!isNull _assigned && {_assigned!=_buyer} && {isPlayer _assigned}) then {_result=[false,"Zeus уже занят другим администратором"];} else {
            if (_assigned!=_buyer) then {unassignCurator _logic;_buyer assignCurator _logic;};
            _logic addCuratorEditableObjects [allUnits+vehicles,true];
            _result=[getAssignedCuratorUnit _logic==_buyer,"Zeus назначен"];
            diag_log format ["[WA BECTI ZEUS] assign owner=%1 success=%2",owner _buyer,_result#0];
        };
    };
};
_buyer setVariable ["WA_BECTI_zeusResult",[_request,_result#0,_result#1],true];
