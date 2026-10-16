/* NeroAI 4.5.0 [Vanilla Command]: scenario-side tuning — Warlords starting
 * Command Points and UAV terminals.
 *
 * CP handling is written against the vanilla Warlords sources
 * (functions_f_warlords, fn_WLInit / fn_WLClientInit / fn_WLVarsInit):
 *   - BIS_WL_startCP        global SCALAR from the init module ("StartCP");
 *                           late-joining players are funded from it;
 *   - BIS_WL_funds          per-WARLORD unit variable (players and the AI
 *                           commanders listed in BIS_WL_allWarlords), what the
 *                           purchase code and the vanilla AI FSM actually spend;
 *   - BIS_WL_maxCP          global cap (10e10 when the module says -1).
 * So the top-up sets the global AND every warlord's own purse once, to at
 * least the target — never below what a warlord already has, never above the
 * cap. The vanilla AI commanders then spend it through their own FSM, and
 * NeroAI groups through fn_purchaseAsset (BUY). */
if (!isServer) exitWith {};

private _target = missionNamespace getVariable ["NeroAI_warlordsStartFunds", 15000];

if (!(missionNamespace getVariable ["NeroAI_fundsApplied", false]) && {!isNil "BIS_WL_allWarlords"}) then {
    private _cap = missionNamespace getVariable ["BIS_WL_maxCP", 10e10];
    if !(_cap isEqualType 0) then { _cap = 10e10; };
    private _amount = _target min _cap;
    private _warlords = missionNamespace getVariable ["BIS_WL_allWarlords", []];
    if !(_warlords isEqualType []) then { _warlords = []; };
    private _topped = 0;
    {
        if (!isNull _x) then {
            private _have = _x getVariable ["BIS_WL_funds", 0];
            if !(_have isEqualType 0) then { _have = 0; };
            if (_have < _amount) then {
                _x setVariable ["BIS_WL_funds", _amount, true];
                _x setVariable ["BIS_WL_funds_backup", _amount];
                _topped = _topped + 1;
            };
        };
    } forEach _warlords;
    missionNamespace setVariable ["BIS_WL_startCP", _amount, true];
    ["INFO", format ["Стартовые CP: %1 выставлены как BIS_WL_startCP; пополнено кошельков командиров: %2 из %3.", _amount, _topped, count _warlords]] call NeroAI_fnc_log;
    missionNamespace setVariable ["NeroAI_fundsApplied", true, true];
};

/* --- UAV terminals ------------------------------------------------------- */
if (!(missionNamespace getVariable ["NeroAI_uavTerminalsEnabled", true])) exitWith {};

private _fnc_terminalFor = {
    params ["_side"];
    private _candidates = switch (_side) do {
        case east: {["O_UavTerminal", "I_UavTerminal", "B_UavTerminal"]};
        case resistance: {["I_UavTerminal", "O_UavTerminal", "B_UavTerminal"]};
        default {["B_UavTerminal", "I_UavTerminal", "O_UavTerminal"]};
    };
    private _pick = "";
    { if (isClass (configFile >> "CfgWeapons" >> _x)) exitWith { _pick = _x; }; } forEach _candidates;
    _pick
};

private _given = 0;
{
    private _unit = _x;
    if (alive _unit && {!(_unit getVariable ["NeroAI_terminalGiven", false])}) then {
        private _term = [side (group _unit)] call _fnc_terminalFor;
        if !(_term isEqualTo "") then {
            if !(_term in (assignedItems _unit)) then {
                _unit linkItem _term;
            };
            _unit setVariable ["NeroAI_terminalGiven", true, true];
            _given = _given + 1;
        };
    };
} forEach ((allPlayers select {alive _x}) + (allUnits select {
    alive _x && {!(isPlayer _x)} && {(group _x) getVariable ["NeroAI_active", false]}
}));

if (_given > 0) then {
    ["INFO", format ["Выдано терминалов БПЛА: %1.", _given]] call NeroAI_fnc_log;
};
