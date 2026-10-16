params ["_unit","_side"];
if (!isServer || {isNull _unit} || {!isPlayer _unit} || {_unit getVariable ["ACE_isUnconscious",false]} || {vehicle _unit!=_unit}) exitWith {false};
private _source=[_unit,_side,getNumber(missionConfigFile >> "CfgNeroOperation" >> "reinforcementCost")] call NeroOP_fnc_campaignWarehouse;
if (_source<0 || {getPlayerUID _unit==""}) exitWith {false};
private _group=[_side,_source,[],[],false,false,-1,getPlayerUID _unit,_source] call NeroOP_fnc_campaignSpawn;
if (isNull _group) exitWith {false};
if !(_group getVariable ["NeroOP_dropBusy",false]) then {[_unit,_group] call NeroOP_fnc_campaignAttachHC;};true
