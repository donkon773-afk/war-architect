params ["_unit"];
if (!hasInterface || {isNull _unit} || {!local _unit} || {_unit getVariable ["NeroAI_actionsInstalled", false]}) exitWith {};

_unit addAction [
    "<t color='#ff9d00'>[NeroAI 4.3.0] Управление отрядами</t>",
    { [] call NeroAI_fnc_openControlMenu; },
    nil,
    -10,
    false,
    true,
    "",
    "alive _this && {!(missionNamespace getVariable ['NeroAI_vanillaMode', false])}"
];
_unit addAction [
    "<t color='#00d0ff'>[NeroAI 4.3.0] Автономные группы</t>",
    { [] call NeroAI_fnc_listGroups; },
    nil,
    -11,
    false,
    true,
    "",
    "alive _this && {!(missionNamespace getVariable ['NeroAI_vanillaMode', false])}"
];
_unit setVariable ["NeroAI_actionsInstalled", true];
