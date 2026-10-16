params ["_plan"];
{if (!isNull _x) then {private _g=group driver _x;{deleteVehicle _x;} forEach crew _x;deleteVehicle _x;deleteGroup _g;};} forEach (_plan select [0,2]);
NeroOP_deliveryFlights=(missionNamespace getVariable ["NeroOP_deliveryFlights",[]]) select {(_x#0)!=(_plan#0)};
