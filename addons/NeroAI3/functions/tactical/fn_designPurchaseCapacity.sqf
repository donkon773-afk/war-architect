/* Global designer limits also apply to native/custom requisition, not only
 * to start assets and garrisons. A non-designer mission keeps native limits. */
params [["_kind","VEHICLE"]];
private _cfg=missionConfigFile >> "CfgNeroDesign";
if (!isClass _cfg) exitWith {1000000};
private _infantry=_kind isEqualTo "INFANTRY";
private _limit=getNumber (_cfg >> (if (_infantry) then {"maxNPCs"} else {"maxVehicles"}));
if (_limit<=0) exitWith {1000000};
private _used=if (_infantry) then {
    count (allUnits select {alive _x && {!isPlayer _x}})
} else {
    count (vehicles select {alive _x && {_x isKindOf "LandVehicle" || {_x isKindOf "Air"} || {_x isKindOf "Ship"} || {_x isKindOf "StaticWeapon"}}})
};
(_limit-_used) max 0
