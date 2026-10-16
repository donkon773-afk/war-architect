/* PURE finite flight gate, reused at the moment of actual ejection. */
params ["_alive","_local","_playerCrew","_safeSector","_enemyDistance","_aaDistance","_height","_distance","_elapsed",["_dropRadius",250]];
if (!_alive) exitWith {"LOSS"};
if (!_local || {_playerCrew}) exitWith {"RELEASE"};
if (!_safeSector || {_enemyDistance < 700} || {_aaDistance < 3000} || {_elapsed >= 240}) exitWith {"ABORT"};
if (_distance <= _dropRadius && {_height >= 150} && {_height <= 650}) exitWith {"DROP"};
"APPROACH"
