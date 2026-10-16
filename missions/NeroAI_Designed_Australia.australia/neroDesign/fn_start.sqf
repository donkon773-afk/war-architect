if(!isServer)exitWith{};
waitUntil{sleep 1;!isNil "BIS_WL_sectors" && {count BIS_WL_sectors>=3}};
private _cfg=missionConfigFile >> "CfgNeroDesign";
{private _s=[east,west,resistance]#(["EAST","WEST","GUER"]find getText(_x >> "side"));private _pos=getArray(_x >> "position");private _id=[_s,_pos,getText(_x >> "name")]call BIS_fnc_addRespawnPosition;diag_log format["[NeroWL Designer] respawn %1",_id];}forEach("true"configClasses(_cfg >> "Spawns"));
{
 private _s=[east,west,resistance]#(["EAST","WEST","GUER"]find getText(_x >> "side"));private _base=missionNamespace getVariable[format["BIS_WL_base_%1",_s],objNull];
 if(!isNull _base)then{for "_i" from 1 to getNumber(_x >> "count")do{[_s,getText(_x >> "vehicle"),getPosATL _base]call NeroWL_Design_fnc_spawnAsset;};};
}forEach("true"configClasses(_cfg >> "StartAssets"));
