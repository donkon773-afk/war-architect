params ["_player", ["_groups", []]];
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {false};
if (isNull _player || {!isPlayer _player} || {!local _player}) exitWith {false};

{
    if (!isNull _x) then {
        private _oldCommander = hcLeader _x;
        if (!isNull _oldCommander && {!(_oldCommander isEqualTo _player)}) then {
            _oldCommander hcRemoveGroup _x;
        };
        _player hcSetGroup [_x];
    };
} forEach _groups;
hcShowBar true;
true
