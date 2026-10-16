/* Public territory contract: runs independently of AI/LLM and in standard mode.
 * The native selection FSM consumes its normal per-side reset flag. */
if (!isServer) exitWith {};
private _previous = createHashMap;
private _pending = createHashMap;
while {true} do {
    if (getNumber (missionConfigFile >> "NeroWL_threeSides") != 1 && {!isNil "BIS_WL_sectors"} && {!isNil "BIS_fnc_WLSectorListing"}
        && {!isNull (missionNamespace getVariable ["BIS_WL_base_WEST",objNull])} && {!isNull (missionNamespace getVariable ["BIS_WL_base_EAST",objNull])}) then {
        private _sectors = missionNamespace getVariable ["BIS_WL_sectors",[]];
        {
            private _owner = _x getVariable ["BIS_WL_sectorSide",sideUnknown];private _id = netId _x;
            private _old = _previous getOrDefault [_id,_owner];
            if (_owner in [west,east]) then {
                private _historyKey = format ["NeroWL_ownershipHistory_%1",_owner];
                private _history = missionNamespace getVariable [_historyKey,[]];_history pushBackUnique _x;
                missionNamespace setVariable [_historyKey,_history];
            };
            if (_old != _owner && {_old in [west,east]}) then {missionNamespace setVariable [format ["NeroWL_lastLost_%1",_old],_x];};
            _previous set [_id,_owner];
        } forEach _sectors;
        {
            private _side = _x;private _key = str _side;
            private _var = format ["BIS_WL_currentSector_%1",_side];
            private _cur = missionNamespace getVariable [_var,objNull];
            private _listing = [_side] call NeroAI_fnc_wlSnapshot;
            private _state = [if (isNull _cur) then {""} else {netId _cur},str (_cur getVariable ["BIS_WL_sectorSide",sideUnknown]),str _side,
                (_listing param [1,[]]) apply {netId _x},count _listing == 3] call NeroAI_fnc_wlTargetState;
            if (_state isEqualTo "RESET") then {
                private _wait = _pending getOrDefault [_key,[objNull,0]];
                if ((_wait # 0) != _cur) then {
                    _pending set [_key,[_cur,diag_tickTime+3]];
                    missionNamespace setVariable [format ["BIS_WL_sectorVotingResetName_%1",_side],"Линия снабжения прервана",true];
                    missionNamespace setVariable [format ["BIS_WL_sectorVotingReset_%1",_side],true,true];
                    missionNamespace setVariable [format ["BIS_WL_selectionTime_%1",_side],-1,true];
                    missionNamespace setVariable [format ["BIS_WL_leadingSector_%1",_side],objNull,true];
                    missionNamespace setVariable [format ["BIS_WL_disconnectedVotes_%1",_side],[],true];
                    missionNamespace setVariable [format ["NeroWL_rulesVote_%1",_side],objNull];
                    {if (side group _x isEqualTo _side) then {_x setVariable ["BIS_WL_selectedSector",objNull,true];};} forEach (missionNamespace getVariable ["BIS_WL_allWarlords",[]]);
                    _cur setVariable [format ["BIS_WL_timeoutCur_%1",_side],-1,true];
                    {
                        private _g = _y;
                        if (side _g isEqualTo _side && {[_g] call NeroAI_fnc_validateGroup}
                            && {!(_g getVariable ["NeroAI_playerHold",false])} && {diag_tickTime >= (_g getVariable ["NeroAI_manualOrderUntil",0])}
                            && {((_g getVariable ["NeroWL_rulesMission",[]]) param [0,""]) isEqualTo "ATTACK"}) then {
                            [_g] call NeroAI_fnc_tacticStop;[_g] call NeroAI_fnc_routeStop;
                            {if (local _x && {!isPlayer _x}) then {doStop _x;};} forEach units _g;
                            _g setVariable ["NeroWL_rulesPhase",nil];_g setVariable ["NeroWL_rulesLastOrder",nil];_g setVariable ["NeroAI_forcePlan",true,true];
                        };
                    } forEach NeroAI_activeGroups;
                    ["INFO",format ["FRONTLINE %1 target=%2 cancelled: no connected path from base",_side,netId _cur]] call NeroAI_fnc_log;
                } else {
                    /* Community FSM fallback: do not leave a dangling target.
                     * Native FSM normally clears it on its next transition. */
                    if (diag_tickTime >= (_wait # 1)) then {
                        missionNamespace setVariable [_var,objNull,true];
                        missionNamespace setVariable [format ["BIS_WL_sectorVotingReset_%1",_side],false,true];
                    };
                };
            } else {_pending deleteAt _key;};
        } forEach [west,east];
    };
    sleep 1;
};
