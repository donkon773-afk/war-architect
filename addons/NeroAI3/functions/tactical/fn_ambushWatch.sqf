/* NeroAI 4.5.0 [Vanilla Command]
 * Server-side ambush detector. It reads the engine picture only: a sudden close
 * hostile contact with fresh losses or heavy suppression, when the group was NOT
 * in close contact moments ago. On a trigger it latches once per encounter,
 * shouts an in-character ambush report, records an AMBUSH event and forces an
 * immediate LLM replan. It never changes posture, moves units, deletes
 * waypoints or spawns anything — the response is the planner's decision. */
if (!isServer) exitWith {};
if (!(missionNamespace getVariable ["NeroAI_ambushEnabled", true])) exitWith {};

private _now = diag_tickTime;

{
    private _group = _y;
    if ([_group] call NeroAI_fnc_validateGroup) then {
        private _leader = leader _group;
        private _living = (units _group) select {alive _x};
        if !(_living isEqualTo []) then {
            private _friendlySide = side _leader;

            private _nearDist = 1e9;
            private _nearObj = objNull;
            private _bearings = [];
            {
                private _t = _x param [4, objNull];
                private _combat = !isNull _t && {
                    _t isKindOf "Man" || {_t isKindOf "LandVehicle"} || {_t isKindOf "Air"} ||
                    {_t isKindOf "Ship"} || {_t isKindOf "StaticWeapon"}
                };
                if (_combat && {alive _t} && {(_friendlySide getFriend (side _t)) < 0.6}) then {
                    private _d = _leader distance2D _t;
                    if (_d <= 300) then {
                        if (_d < _nearDist) then { _nearDist = _d; _nearObj = _t; };
                        if (_d <= 120) then { _bearings pushBackUnique (floor ((_leader getDir _t) / 45)); };
                    };
                };
            } forEach (_leader nearTargets 400);

            private _prevCloseAt = _group getVariable ["NeroAI_lastCloseContactAt", -999];
            private _hadContactRecently = (_now - _prevCloseAt) <= 15;

            /* When this firefight actually started. A group is normally already
             * "in contact" when it takes casualties, so also treat first blood
             * within ~10 s of first contact as an ambush. */
            private _wasEngaged = _group getVariable ["NeroAI_wasEngaged", false];
            private _engagedNow = _nearDist < 300;
            if (_engagedNow && {!_wasEngaged}) then { _group setVariable ["NeroAI_engagementStart", _now, true]; };
            if (!_engagedNow) then { _group setVariable ["NeroAI_engagementStart", -999, true]; };
            _group setVariable ["NeroAI_wasEngaged", _engagedNow, true];
            private _freshEngagement = (_now - (_group getVariable ["NeroAI_engagementStart", -999])) <= 10;

            /* Casualties in the last ~6 seconds. */
            private _window = _group getVariable ["NeroAI_ambushLossWindow", [_now, count _living]];
            if ((_now - (_window # 0)) > 6) then { _window = [_now, count _living]; };
            private _casualties = ((_window # 1) - (count _living)) max 0;
            _group setVariable ["NeroAI_ambushLossWindow", _window, false];

            private _suppressed = {(getSuppression _x) > 0.35} count _living;
            private _multiBearing = (count _bearings) >= 2;

            private _state = _group getVariable ["NeroAI_ambushState", []];
            private _lastAmbush = if (_state isEqualType [] && {count _state >= 4}) then {_state # 3} else {-999};
            private _onCooldown = (_now - _lastAmbush) < 45;

            private _triggered = (!_onCooldown) && {
                (
                    (_nearDist < 100) && {!_hadContactRecently} &&
                    {(_casualties >= 1) || {_suppressed >= 2} || {_multiBearing && {_suppressed >= 1}}}
                )
                || {(_nearDist < 150) && {_freshEngagement} && {_casualties >= 1}}
            };

            if (_triggered) then {
                private _bearing = round (_leader getDir _nearObj);
                private _dist = round _nearDist;
                _group setVariable ["NeroAI_ambushState", ["AMBUSHED", _bearing, _dist, _now], true];
                _group setVariable ["NeroAI_ambushPending", true, true];
                _group setVariable ["NeroAI_forcePlan", true, true];

                private _events = _group getVariable ["NeroAI_events", []];
                _events pushBack ["AMBUSH", _bearing, _dist, _casualties, _now];
                if ((count _events) > 4) then { _events = _events select [(count _events) - 4, 4]; };
                _group setVariable ["NeroAI_events", _events, true];

                /* 4.5.0: no scripted reflex — posture stays vanilla. The ambush is
                 * reported on the radio and handed to the planner as an event. */
                private _side = _group getVariable ["NeroAI_factionSide", _friendlySide];
                private _callsign = _group getVariable ["NeroAI_callsign", groupId _group];
                private _shout = switch (_side) do {
                    case resistance: { format ["%1: Засада, братья! Неверные в упор, азимут %2, %3 метров — огонь, огонь! Отходим!", _callsign, _bearing, _dist] };
                    case east: { format ["%1 всем — засада! Внезапный огонь, азимут %2, дистанция %3, есть потери. Подавить и закрепиться!", _callsign, _bearing, _dist] };
                    default { format ["%1 — контакт, засада! Азимут %2, %3 метров, накрыли с фланга, есть двухсотые. Дым, отход, нужна поддержка!", _callsign, _bearing, _dist] };
                };
                [_leader, _shout, "SIDE"] remoteExecCall ["NeroAI_fnc_clientSpeech", 0];
                ["WARN", format ["%1 AMBUSH detected: bearing=%2 dist=%3 casualties=%4 suppressed=%5.", _callsign, _bearing, _dist, _casualties, _suppressed]] call NeroAI_fnc_log;
            };

            if (_nearDist < 150) then { _group setVariable ["NeroAI_lastCloseContactAt", _now, true]; };

            /* Age out stale events so buildSnapshot only carries recent ones. */
            private _evts = _group getVariable ["NeroAI_events", []];
            if !(_evts isEqualTo []) then {
                private _fresh = _evts select {(_x isEqualType []) && {count _x >= 5} && {(_now - (_x # 4)) <= 45}};
                if !(_fresh isEqualTo _evts) then { _group setVariable ["NeroAI_events", _fresh, true]; };
            };
        };
    };
} forEach NeroAI_activeGroups;
