/* Tank inheritance includes many tracked IFVs; passenger capacity and known
 * support chassis take precedence. Does not change class side or ownership. */
params ["_class"];
private _cfg=configFile >> "CfgVehicles" >> _class;
if (!isClass _cfg || {!(_class isKindOf "LandVehicle")} || {_class isKindOf "StaticWeapon"}) exitWith {""};
private _id=toLower _class;
if ((["tunguska","zsu","2s6","bm21","mlrs","nona","howitzer","m109","2s1","2s3","2s19"] findIf {_id find _x>=0}) >= 0) exitWith {""};
if (_class isKindOf "Wheeled_APC_F" || {_class isKindOf "Tracked_APC_F"}) exitWith {"APC"};
if (_class isKindOf "Tank") exitWith {
    private _mbt=(["m1a","m1_","t72","t_72","t80","t_80","t90","t_90","t14","t_14","merkava","challenger","leopard"] findIf {_id find _x>=0})>=0;
    if (!_mbt && {getNumber (_cfg >> "transportSoldier")>=4 || {(["bmp","bmd","bradley","m2a","m3a","warrior","fv510","mtlb"] findIf {_id find _x>=0})>=0}}) then {"APC"} else {"TANK"}
};
if (_class isKindOf "Car") exitWith {"CAR"};
""
