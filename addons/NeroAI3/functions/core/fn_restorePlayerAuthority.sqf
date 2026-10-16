params ["_player"];
if (!isServer || {isNull _player} || {!isPlayer _player}) exitWith {false};

/* A remote client may request restoration only for the object it owns.  The
   actual privileges come exclusively from the server's pre-death snapshot. */
if (isRemoteExecuted && {remoteExecutedOwner != 0} && {remoteExecutedOwner != owner _player}) exitWith {
    ["WARN", format ["Respawn authority request rejected for owner %1.", remoteExecutedOwner]] call NeroAI_fnc_log;
    false
};

private _uid = getPlayerUID _player;
if (_uid isEqualTo "") exitWith {false};
private _snapshot = NeroAI_playerAuthority getOrDefault [_uid, []];
if (_snapshot isEqualTo [] || {!(_snapshot param [5, false])}) exitWith {false};

private _curator = _snapshot param [0, objNull];
private _wasLeader = _snapshot param [1, false];
private _highCommandGroups = (_snapshot param [2, []]) select {!isNull _x};
private _oldPlayer = _snapshot param [3, objNull];
private _restored = [];

if (!isNull _curator) then {
    private _assigned = getAssignedCuratorUnit _curator;
    if (isNull _assigned || {_assigned isEqualTo _oldPlayer} || {!alive _assigned}) then {
        unassignCurator _curator;
        _player assignCurator _curator;
        _restored pushBack "ZEUS";
    } else {
        ["WARN", format ["Curator restore skipped for UID %1: module is assigned to another living player.", _uid]] call NeroAI_fnc_log;
    };
};

if (_wasLeader && {!isNull group _player}) then {
    [_player] remoteExecCall ["NeroAI_fnc_restoreGroupLeaderLocal", groupOwner group _player];
    _restored pushBack "GROUP_LEADER";
};

if !(_highCommandGroups isEqualTo []) then {
    [_player, _highCommandGroups] remoteExecCall ["NeroAI_fnc_restoreHighCommandLocal", owner _player];
    _restored pushBack "HIGH_COMMAND";
};

NeroAI_playerAuthority set [_uid, [
    _curator,
    _wasLeader,
    _highCommandGroups,
    _player,
    diag_tickTime,
    false
]];
_player setVariable ["NeroAI_wasGroupLeader", _wasLeader];
_player setVariable ["NeroAI_highCommandGroups", _highCommandGroups];

["INFO", format [
    "Respawn authority restored for UID %1: %2.",
    _uid,
    if (_restored isEqualTo []) then {"no elevated authority in snapshot"} else {_restored joinString ", "}
]] call NeroAI_fnc_log;
true
