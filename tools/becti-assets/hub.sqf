params [["_mode","OPEN"]];
if (!hasInterface || {isRemoteExecuted}) exitWith {};
disableSerialization;
if (_mode=="OPEN") exitWith {if (!dialog) then {createDialog "WarArchitectBectiHub";};};
if (_mode=="INIT") exitWith {
    private _display=findDisplay 88200;
    while {!isNull _display} do {
        private _commander=CTI_P_SideJoined call CTI_CO_FNC_GetSideCommander;
        private _name=if (isNull _commander) then {"не назначен"} else {if (isPlayer leader _commander) then {name leader _commander} else {"ИИ"}};
        (_display displayCtrl 88201) ctrlSetStructuredText parseText format ["Сторона: %1 · Командир: %2<br/>Средства BECTI: %3 · Штаб: %4",CTI_P_SideJoined,_name,call CTI_CL_FNC_GetPlayerFunds,if (alive (CTI_P_SideJoined call CTI_CO_FNC_GetSideHQ)) then {"действует"} else {"уничтожен"}];
        uiSleep 0.5;
    };
};
if (_mode=="SHOP") exitWith {closeDialog 0;["OPEN"] call NeroOP_fnc_bectiShopUI;};
if (_mode=="ZEUS") exitWith {[] spawn WA_BECTI_openZeus;};
private _error="";private _target="";
switch (_mode) do {
    case "BUILD":{_target="CTI_RscBuildMenu_Tablet";if (!(call CTI_CL_FNC_IsPlayerCommander)) then {_error="Сначала примите командование стороной";} else {if (!(missionNamespace getVariable ["CTI_Base_HQInRange",false]) || {vehicle player!=player}) then {_error="Для строительства подойдите пешком к своему мобильному штабу";};};};
    case "TEAMS":{_target="CTI_RscTeamsMenu";};
    case "MAP":{_target="CTI_RscMapCommandMenu";};
    case "UPGRADES":{_target="CTI_RscTabletUpgradeMenu";};
    case "WORKERS":{_target="CTI_RscTabletWorkersMenu";if (!(call CTI_CL_FNC_IsPlayerCommander)) then {_error="Рабочими управляет командир стороны";};};
    case "SERVICE":{_target="CTI_RscTabletServiceMenu";};
    case "FUNDS":{_target="CTI_RscTabletTransferResourcesMenu";};
    case "OPTIONS":{_target="CTI_RscTablet_main";};
};
if (_mode in ["TEAMS","MAP","UPGRADES"]) then {
    if (!(call CTI_CL_FNC_IsPlayerCommander)) then {_error="Сначала примите командование стороной";} else {
        if (!(missionNamespace getVariable ["CTI_Base_ControlCenterInRange",false])) then {_error="Нужен центр управления: постройте его на базе и подойдите ближе";};
    };
};
if (_error!="") exitWith {private _display=findDisplay 88200;if (!isNull _display) then {(_display displayCtrl 88202) ctrlSetText _error;};systemChat _error;};
if (_target!="") then {closeDialog 0;createDialog _target;};
