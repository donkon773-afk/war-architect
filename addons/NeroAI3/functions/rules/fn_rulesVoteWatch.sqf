/* 11.10 Tactical AI without LLM — sector vote of the AI commanders.
 * Spawned once by fn_serverLoop in the tactical mode; checks every second.
 *
 * Native Warlords: while BIS_WL_currentSector_<side> is objNull the side votes;
 * every warlord's BIS_WL_selectedSector counts (fn_WLMostVotedSector) when the
 * BIS_WLVotingTimeout runs out. The native AI (WLAICore "vote") picks a RANDOM
 * available sector, or the enemy HQ whenever it is reachable. Here the AI
 * commanders vote the strategist's choice instead:
 *   - only AI warlords are touched, never a player;
 *   - the native rule stands: AI votes only with BIS_WL_AICanVote == 1 or when
 *     no player of that side is in the game;
 *   - a player's own vote leads: the AI commanders back the player's sector;
 *   - the choice is recomputed at the moment voting opens (the sector just
 *     captured is no longer available). */
if (!isServer) exitWith {};
if (getNumber (missionConfigFile >> "NeroWL_threeSides") == 1) exitWith {
    ["INFO", "RULES: three-side mission — sector voting stays with its own runtime."] call NeroAI_fnc_log;
};
private _announced = createHashMap;
while {true} do {
    if (missionNamespace getVariable ["NeroAI_rulesMode", false]) then {
        {
            private _side = _x;
            private _cur = missionNamespace getVariable [format ["BIS_WL_currentSector_%1", _side], objNull];
            if (isNull _cur) then {
                private _wls = (missionNamespace getVariable ["BIS_WL_allWarlords", []]) select {alive _x && {(side group _x) isEqualTo _side}};
                private _ai = _wls select {!isPlayer _x};
                private _humans = _wls select {isPlayer _x};
                private _aiCanVote = ((missionNamespace getVariable ["BIS_WL_AICanVote", 1]) isEqualTo 1) || {_humans isEqualTo []};
                private _available = ([_side] call NeroAI_fnc_wlSnapshot) param [1, []];
                if (_aiCanVote && {_ai isNotEqualTo []} && {_available isEqualType []} && {_available isNotEqualTo []}) then {
                    private _choice = objNull;
                    private _source = "стратег";
                    {
                        private _v = _x getVariable ["BIS_WL_selectedSector", objNull];
                        if (!isNull _v && {_v in _available}) exitWith {_choice = _v; _source = "голос игрока";};
                    } forEach _humans;
                    if (isNull _choice) then {
                        _choice = missionNamespace getVariable [format ["NeroWL_rulesVote_%1", _side], objNull];
                        if (isNull _choice || {!(_choice in _available)}) then {
                            [[_side], true] call NeroAI_fnc_rulesCommander;
                            _choice = missionNamespace getVariable [format ["NeroWL_rulesVote_%1", _side], objNull];
                        };
                    };
                    if (!isNull _choice && {_choice in _available}) then {
                        { if !((_x getVariable ["BIS_WL_selectedSector", objNull]) isEqualTo _choice) then {_x setVariable ["BIS_WL_selectedSector", _choice, true];}; } forEach _ai;
                        private _key = str _side;
                        if !((_announced getOrDefault [_key, objNull]) isEqualTo _choice) then {
                            _announced set [_key, _choice];
                            private _name = _choice getVariable ["Name", ""];
                            if (!(_name isEqualType "") || {_name isEqualTo ""}) then {_name = mapGridPosition _choice;};
                            if ((toUpper _name) select [0, 4] isEqualTo "STR_") then {_name = localize _name;};
                            ["INFO", format ["RULES %1 vote: %2 AI commander(s) vote %3 (%4).", _side, count _ai, _name, _source]] call NeroAI_fnc_log;
                        };
                    };
                };
            } else {
                _announced deleteAt (str _side);
            };
        } forEach [west, east];
    };
    uiSleep 1;
};
