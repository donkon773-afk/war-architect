if (!hasInterface) exitWith {};
waitUntil {uiSleep 0.2;missionNamespace getVariable ["CTI_Init_Client",false] && {!isNull player} && {!isNil "CTI_COM_SET_CLIENT"}};
waitUntil {uiSleep 0.2;!isNil {group player getVariable "cti_order"}};
WA_BECTI_openZeus={
    if (isRemoteExecuted) exitWith {};
    private _unit=player;private _request=floor random 1000000000;
    [_unit,_request] remoteExecCall ["NeroOP_fnc_bectiZeus",2];
    private _deadline=diag_tickTime+15;
    waitUntil {uiSleep 0.1;((_unit getVariable ["WA_BECTI_zeusResult",[-1]])#0)==_request || {diag_tickTime>_deadline} || {player!=_unit}};
    if (player!=_unit) exitWith {};
    private _result=_unit getVariable ["WA_BECTI_zeusResult",[-1,false,"Нет ответа сервера на запрос Zeus"]];
    if ((_result#0)!=_request || {!(_result#1)}) exitWith {systemChat (_result#2);};
    waitUntil {uiSleep 0.1;!isNull getAssignedCuratorLogic _unit || {diag_tickTime>_deadline}};
    if (isNull getAssignedCuratorLogic _unit) exitWith {systemChat "Назначение Zeus ещё не получено клиентом. Повторите вход.";};
    closeDialog 0;openCuratorInterface;
};
WA_BECTI_takeCommand={
    if (isRemoteExecuted) exitWith {};
    if (leader group player!=player) exitWith {systemChat "Нужно быть командиром своего отряда.";};
    if (call CTI_CL_FNC_IsPlayerCommander) exitWith {["OPEN"] call NeroOP_fnc_bectiHub;};
    private _request=floor random 1000000000;private _unit=player;
    [_unit,_request] remoteExecCall ["NeroOP_fnc_bectiCommander",2];
    private _deadline=diag_tickTime+15;
    waitUntil {uiSleep 0.1;((_unit getVariable ["WA_BECTI_commandResult",[-1]])#0)==_request || {diag_tickTime>_deadline} || {player!=_unit}};
    if (player!=_unit) exitWith {};
    private _result=_unit getVariable ["WA_BECTI_commandResult",[-1,false,"Нет ответа сервера на назначение командира"]];
    if ((_result#0)!=_request || {!(_result#1)}) exitWith {systemChat (_result#2);};
    if ((CTI_P_SideJoined call CTI_CO_FNC_GetSideCommander)!=group player) exitWith {systemChat "Должность командира изменилась; откройте планшет ещё раз.";};
    0 call CTI_COM_SET_CLIENT;
    systemChat "War Architect: командование принято. Управление войсками и строительство — в планшете.";
    ["OPEN"] call NeroOP_fnc_bectiHub;
};
private _last=objNull;
while {!(missionNamespace getVariable ["CTI_GameOver",false])} do {
    if (!isNull player && {player!=_last}) then {
        _last=player;
        player addAction ["<t color='#c6ce9b'>War Architect · Арсенал / заказ</t>",{["OPEN"] call NeroOP_fnc_bectiShopUI;},nil,2,false,true,"","alive _target"];
        player addAction ["<t color='#c6ce9b'>War Architect · Принять командование</t>",{[] spawn WA_BECTI_takeCommand;},nil,1.9,false,true,"","alive _target"];
        player addAction ["<t color='#c6ce9b'>War Architect · Планшет управления</t>",{["OPEN"] spawn NeroOP_fnc_bectiHub;},nil,1.8,false,true,"","alive _target"];
    };
    uiSleep 1;
};
