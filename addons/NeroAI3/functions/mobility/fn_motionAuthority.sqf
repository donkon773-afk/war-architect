/* PURE generation/locality/driver authority gate for every owned manoeuvre. */
params ["_currentEpoch","_epoch","_ownerMatches","_local","_alive","_driverAlive","_playerDriver","_driverInGroup"];
_currentEpoch == _epoch && {_ownerMatches} && {_local} && {_alive} && {_driverAlive} && {!_playerDriver} && {_driverInGroup}
