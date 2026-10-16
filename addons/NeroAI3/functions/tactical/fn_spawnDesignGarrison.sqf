/* Only a typed, saved designer sector; no model-generated classes or code. */
params ["_sector","_radX","_radY","_side"];
private _cfg=missionConfigFile >> "CfgNeroDesign" >> "Garrisons" >> (_sector getVariable ["NeroWL_designId",""]);
if (!isServer || {!isClass _cfg}) exitWith {false};
private _limit=getNumber (missionConfigFile >> "CfgNeroDesign" >> "maxNPCs");if (_limit<=0) then {_limit=160;};
private _vLimit=getNumber (missionConfigFile >> "CfgNeroDesign" >> "maxVehicles");if (_vLimit<=0) then {_vLimit=32;};
private _groups=[];
private _center=getPosATL _sector;
private _classes=getArray (_cfg >> "vehicleClasses");
private _vehicleCount=(getNumber (_cfg >> "vehicles")) min 8;
for "_i" from 1 to _vehicleCount do {
    if (count vehicles>=_vLimit || {count allUnits+4>_limit}) exitWith {};
    private _allowed=_classes select {isClass (configFile >> "CfgVehicles" >> _x) && {getNumber (configFile >> "CfgVehicles" >> _x >> "side") == ([east,west,resistance] find _side)} && {_x isKindOf "LandVehicle"} && {!(_x isKindOf "Man")}};
    if (_allowed isEqualTo []) exitWith {};
    private _class=selectRandom _allowed;
    private _pos=_center findEmptyPosition [15,_radX max 30,_class];
    if !(_pos isEqualTo []) then {private _v=createVehicle [_class,_pos,[],0,"NONE"];createVehicleCrew _v;if(count allUnits>_limit || {_side isEqualTo resistance && {([0] call NeroAI_fnc_greenRoom)<0}})then{{_v deleteVehicleCrew _x;}forEach crew _v;deleteVehicle _v;};private _g=group effectiveCommander _v;if(!isNull _g)then{_groups pushBackUnique _g;};_v setVariable ["NeroWL_garrisonSector",_sector,true];};
};
private _pool=(missionNamespace getVariable ["BIS_WL_unitsPool",[]]) param [[east,west,resistance] find _side,[]];
private _need=(getNumber (_cfg >> "infantry")) min 60;
while {_need>0 && {count allUnits<_limit} && {!(_pool isEqualTo [])} && {!(_side isEqualTo resistance) || {([0] call NeroAI_fnc_greenRoom)>0}}} do {
    private _g=createGroup [_side,true];
    for "_i" from 1 to (_need min 6) do {
        if(count allUnits>=_limit || {_side isEqualTo resistance && {([0] call NeroAI_fnc_greenRoom)<=0}})exitWith{};
        private _class=selectRandom _pool;private _pos=(_center getPos [random (_radX max 30),random 360]) findEmptyPosition [0,30,_class];
        if !(_pos isEqualTo []) then {_g createUnit [_class,_pos,[],0,"NONE"];};
        _need=_need-1;
    };
    if(count units _g>0)then{_groups pushBack _g;}else{deleteGroup _g;};
};
{
    _x setVariable ["NeroWL_garrison",true,true];_x setVariable ["NeroWL_garrisonSector",_sector,true];
    private _wp=_x addWaypoint [_center,30];_wp setWaypointType "HOLD";_wp setWaypointBehaviour "AWARE";
    if(getNumber(missionConfigFile >> "NeroWL_threeSides")!=1)then{
        {[_x,_sector] call BIS_fnc_WLremovalHandle;}forEach units _x;
        [_x,_sector] call BIS_fnc_WLGarrisonRetreat;
    };
}forEach _groups;
_sector setVariable ["NeroWL_garrisonGroups",_groups,true];
diag_log format ["[NeroWL Designer] garrison=%1 groups=%2",_sector getVariable ["Name",""],count _groups];
true
