params [["_unit",objNull,[objNull]],["_plane",objNull,[objNull]]];
if (!isServer || {isNull _unit} || {!isPlayer _unit} || {!alive _unit} || {isNull _plane} || {!alive _plane}) exitWith {};
if (isRemoteExecuted && {remoteExecutedOwner!=owner _unit}) exitWith {};
if (_plane!=(_unit getVariable ["NeroOP_plane",objNull]) || {_unit!=driver _plane} || {!(_plane in NeroOP_planes)} || {NeroOP_finished}) exitWith {};
_plane enableSimulationGlobal true;_plane allowDamage true;
_plane setVariable ["NeroOP_launched",true,true];_plane setVariable ["NeroOP_pendingAt",-100];
_unit setCaptive false;_unit setVariable ["NeroOP_notice","",true];
diag_log format ["[NeroOP AIR] PILOT READY flight=%1 owner=%2",_plane getVariable ["NeroOP_flight",""],owner _unit];
