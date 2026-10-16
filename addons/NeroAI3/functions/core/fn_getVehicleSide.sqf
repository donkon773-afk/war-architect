/* side returns civilian for an empty vehicle. Resolve empty assets from an
 * explicit mission ownership override or from their CfgVehicles side. */
params ["_vehicle"];
if (isNull _vehicle) exitWith {sideUnknown};
if !((crew _vehicle) isEqualTo []) exitWith {side _vehicle};

private _declared = _vehicle getVariable ["NeroAI_ownerSide", sideUnknown];
if !(_declared isEqualTo sideUnknown) exitWith {_declared};
private _configSide = getNumber (configFile >> "CfgVehicles" >> typeOf _vehicle >> "side");
[east, west, independent, civilian] param [_configSide, civilian]
