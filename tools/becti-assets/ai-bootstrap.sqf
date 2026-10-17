/* Register each editor AI slot once. Never kill an AI to initialise its FSM,
   and never reparent a slot already claimed by a player. */
if (!isServer) exitWith {};
waitUntil {sleep 0.25;missionNamespace getVariable ["CTI_Init_Server",false]};
while {!(missionNamespace getVariable ["CTI_GameOver",false])} do {
    {
        private _unit=_x;private _team=group _unit;private _side=side _team;
        private _enabled=missionNamespace getVariable ["CTI_AI_TEAMS_ENABLED",0];
        if (alive _unit && {local _unit} && {!isPlayer _unit} && {_side in [west,east]} &&
            {_enabled==3 || {_side==west && {_enabled==1}} || {_side==east && {_enabled==2}}} &&
            {!(_unit getVariable ["WA_BECTI_slotRegistered",false])} &&
            {units _team findIf {isPlayer _x}<0}) then {
            private _logic=_side call CTI_CO_FNC_GetSideLogic;
            private _teams=_logic getVariable ["cti_teams",[]];
            if (_team in _teams || {{!isPlayer leader _x} count _teams<CTI_AI_TEAMS_NB}) then {
                _unit setVariable ["WA_BECTI_slotRegistered",true];
                [_team,_side] call CTI_SE_FNC_InitializeGroup;
                _unit enableFatigue false;_team allowFleeing 0;
                if (!(_team getVariable ["cti_aifsm_handled",false])) then {
                    _team setVariable ["cti_aifsm_handled",true];
                    [_team,_side] execFSM "Server\FSM\update_ai.fsm";
                };
                diag_log format ["[WA BECTI AI] REGISTER side=%1 group=%2 ready=%3",_side,_team,_team getVariable "cti_nextrespawn"];
            };
        };
    } forEach ((playableUnits+switchableUnits) arrayIntersect (playableUnits+switchableUnits));
    sleep 10;
};
