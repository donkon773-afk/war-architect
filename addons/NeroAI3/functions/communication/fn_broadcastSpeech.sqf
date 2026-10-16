params ["_groups", "_player", "_channel", "_speech"];
if (_speech isEqualTo "" || {_groups isEqualTo []}) exitWith {};
private _leader = leader (_groups # 0);
private _group = _groups # 0;
private _isEnemy = _group getVariable ["NeroAI_isEnemy", false];

if (!_isEnemy) then {
    switch (_channel) do {
        case "SIDE": {[_leader, _speech, "SIDE"] remoteExecCall ["NeroAI_fnc_clientSpeech", 0];};
        case "AUTONOMY": {[_leader, _speech, "SIDE"] remoteExecCall ["NeroAI_fnc_clientSpeech", 0];};
        case "INTERGROUP": {[_leader, _speech, "SIDE"] remoteExecCall ["NeroAI_fnc_clientSpeech", 0];};
        case "COMMAND": {[_leader, _speech, "COMMAND"] remoteExecCall ["NeroAI_fnc_clientSpeech", 0];};
        default {[_leader, _speech, "GROUP"] remoteExecCall ["NeroAI_fnc_clientSpeech", 0];};
    };
    if (!isNull _player) then {
        private _callsigns = (_groups apply {_x getVariable ["NeroAI_callsign", groupId _x]}) joinString ", ";
        [format ["%1: %2", _callsigns, _speech]] remoteExecCall ["NeroAI_fnc_clientNotice", owner _player];
    };
} else {
    // Enemy group: broadcast strictly on enemy sideChat
    [_leader, _speech, "SIDE"] remoteExecCall ["NeroAI_fnc_clientSpeech", 0];

    // Close combat atmospheric shouts: if player is within 55m, shout in directChat!
    private _nearbyPlayers = (allPlayers select {alive _x}) select {(_x distance _leader) <= 55};
    if !(_nearbyPlayers isEqualTo []) then {
        [_leader, _speech, "DIRECT"] remoteExecCall ["NeroAI_fnc_clientSpeech", 0];
    };
};