/* Isolate legacy BECTI/mod init code from transaction-local variables.
   SQF call inherits its caller's local scope. Some unit init scripts use
   generic names without private; spawn gives them an independent scope. */
params ["_waMode","_waArguments"];
if (!isServer || {!canSuspend}) exitWith {objNull};
private _waResult=[];
private _waThread=[_waMode,_waArguments,_waResult] spawn {
    params ["_waMode","_waArguments","_waResult"];
    private _waObject=switch (_waMode) do {
        case "UNIT":{_waArguments call CTI_CO_FNC_CreateUnit};
        case "VEHICLE":{_waArguments call CTI_CO_FNC_CreateVehicle};
        default {objNull};
    };
    _waResult pushBack _waObject;
};
waitUntil {sleep 0.01;scriptDone _waThread};
_waResult param [0,objNull]
