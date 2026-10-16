params ["_player"];
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {false};
if (isNull _player || {!isPlayer _player} || {!local group _player}) exitWith {false};

group _player selectLeader _player;
true
