params ["_vehicle","_grant",["_ammoOnly",false]];
if (isRemoteExecuted && {remoteExecutedOwner!=2}) exitWith {};
if (isNull _vehicle || {_vehicle getVariable ["NeroOP_serviceGrant",-1]!=_grant} || {diag_tickTime<(_vehicle getVariable ["NeroOP_serviceLocalAt",-100])+2}) exitWith {};
/* setVehicleAmmo fills local turrets only, so the server grants the same paid service to all owners. */
_vehicle setVehicleAmmo 1;
if (local _vehicle && {!_ammoOnly}) then {_vehicle setFuel 1;_vehicle setDamage 0;};
_vehicle setVariable ["NeroOP_serviceLocalAt",diag_tickTime];
