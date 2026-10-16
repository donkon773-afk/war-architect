params [["_selected", grpNull]];
if (!hasInterface || {isNull player}) exitWith {};
if (missionNamespace getVariable ["NeroAI_vanillaMode", false]) exitWith {systemChat "[NeroAI] Ботами командует штатный ИИ Arma — NeroAI выключен в настройках запуска.";};

if (isNull _selected) exitWith {
    private _groups = allGroups select {
        !isNull (leader _x) && {alive (leader _x)} && {!isPlayer (leader _x)} && {side _x isEqualTo side group player} && {_x != group player}
    };
    NeroAI4_AvailableGroups = _groups;
    NeroAI4_CommandMenu = [["NeroAI 4.3.0: Управление отрядами", true]];

    private _enemyAiActive = missionNamespace getVariable ["NeroAI_enemyAIEnabled", true];
    private _enemyToggleText = if (_enemyAiActive) then {"[ИИ противников (Красные/Зеленые): ВКЛ]"} else {"[ИИ противников: ВЫКЛ]"};
    NeroAI4_CommandMenu pushBack [
        _enemyToggleText,
        [2],
        "",
        -5,
        [["expression", "
            private _newState = !(missionNamespace getVariable ['NeroAI_enemyAIEnabled', true]);
            missionNamespace setVariable ['NeroAI_enemyAIEnabled', _newState, true];
            private _fn = missionNamespace getVariable ['NeroAI_factionNames', createHashMap];
            systemChat format ['[NeroAI] ИИ противников (%1 / %2): %3', _fn getOrDefault ['GREEN', 'сопротивление'], _fn getOrDefault ['RED', 'армия'], if (_newState) then {'ВКЛЮЧЁН'} else {'ВЫКЛЮЧЕН'}];
        "]],
        "1",
        "1"
    ];

    private _index = 3;
    {
        private _group = _x;
        private _status = if (_group getVariable ["NeroAI_active", false]) then {"в управлении"} else {"не подключён"};
        NeroAI4_CommandMenu pushBack [
            format ["%1 — %2", _group getVariable ["NeroAI_callsign", groupId _group], _status],
            [_index],
            "",
            -5,
            [["expression", format ["[NeroAI4_AvailableGroups select %1] spawn { uiSleep 0.05; _this call NeroAI_fnc_openControlMenu; };", _forEachIndex]]],
            "1",
            "1"
        ];
        _index = _index + 1;
    } forEach _groups;
    if (_groups isEqualTo []) then {
        NeroAI4_CommandMenu pushBack ["Нет доступных дружественных отрядов", [_index], "", -5, [["expression", ""]], "1", "0"];
    };
    showCommandingMenu "#USER:NeroAI4_CommandMenu";
};

NeroAI4_SelectedGroup = _selected;
private _activeLabel = if (_selected getVariable ["NeroAI_active", false]) then {"Снять управление NeroAI"} else {"Передать управление NeroAI"};
NeroAI4_GroupMenu = [
    [format ["%1: NeroAI 4.3.0", _selected getVariable ["NeroAI_callsign", groupId _selected]], true],
    [_activeLabel, [2], "", -5, [["expression", "[player, 'TOGGLE', NeroAI4_SelectedGroup] remoteExecCall ['NeroAI_fnc_receiveClientCommand', 2];"]], "1", "1"]
];
showCommandingMenu "#USER:NeroAI4_GroupMenu";