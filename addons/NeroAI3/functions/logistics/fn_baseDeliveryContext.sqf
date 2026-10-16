params ["_buyer","_anchor","_cart"];
if (isNull _buyer || {!(_anchor isEqualType objNull)} || {isNull _anchor}) exitWith {[false,objNull,0]};
private _side = side group _buyer;
private _base = missionNamespace getVariable [format ["BIS_WL_base_%1",_side],objNull];
if (isNull _base) exitWith {[false,objNull,0]};
private _radius = ((_base getVariable ["Size",300])/2) max 30;
private _supported = _cart isNotEqualTo [] && {(_cart findIf {!isClass (configFile >> "CfgVehicles" >> _x) || {!(_x isKindOf "Man" || {_x isKindOf "LandVehicle"})}}) < 0};
private _mode = [_anchor distance2D _base <= _radius,(_base getVariable ["BIS_WL_sectorSide",sideUnknown]) isEqualTo _side,_supported] call NeroAI_fnc_baseDeliveryRule;
[_mode isEqualTo "GROUND",_base,_radius]
