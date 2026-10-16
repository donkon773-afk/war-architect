"use strict";
const fs=require("node:fs"),path=require("node:path");
function adapt(source){
 source=source.replaceAll("\r\n","\n");
 const replace=(before,after)=>{if(!source.includes(before))throw new Error("Native garrison source changed: "+before);source=source.replace(before,after);};
 replace('_sentriesTotal = 60 * _trgSizeIndex;','_sentriesTotal = 60 * _trgSizeIndex;');
 source='if (isServer && {getNumber (missionConfigFile >> "NeroWL_useDesigner") == 1}) exitWith {_this call NeroAI_fnc_spawnDesignGarrison};\n'+source;
 replace('_side = _this # 3;',`_side = _this # 3;
private _neroIndex=[east,west,resistance] find _side;
private _neroCap=-1;
if (getNumber (missionConfigFile >> "NeroWL_personalScenario") == 1 && {_neroIndex>=0}) then {_neroCap=(missionNamespace getVariable ["NeroWL_garrisonCaps",[-1,-1,-1]]) param [_neroIndex,-1];};
private _neroUsed=0;
// Lobby-wide GREEN cap: reserve this sector's share now, release once spawned.
private _greenGrant=-1;
if (_side isEqualTo resistance && {getNumber (missionConfigFile >> "NeroWL_personalScenario") == 1} && {(missionNamespace getVariable ["NeroWL_greenTotalCap",-1]) >= 0}) then {
    _greenGrant=[if (_neroCap<0) then {1000} else {_neroCap}] call NeroAI_fnc_greenRoom;
    _neroCap=_greenGrant;
};`);
 replace('if (side (_x # 3) == _side) then {','if (side (_x # 3) == _side && {_neroCap<0 || {_neroUsed<_neroCap}}) then {');
 replace('createVehicleCrew _veh;',`createVehicleCrew _veh;
        private _neroCrew=count crew _veh;
        private _neroFits=_neroCap<0 || {_neroUsed+_neroCrew<=_neroCap};
        if (!_neroFits) then {private _neroCrewGroup=group effectiveCommander _veh;{_veh deleteVehicleCrew _x;} forEach crew _veh;deleteVehicle _veh;if (!isNull _neroCrewGroup) then {deleteGroup _neroCrewGroup;};} else {
        _neroUsed=_neroUsed+_neroCrew;`);
 replace('[_grp, _sector] call BIS_fnc_WLGarrisonRetreat;\n\t};','[_grp, _sector] call BIS_fnc_WLGarrisonRetreat;\n        };\n\t};');
 // A configured fixed defender cap also suppresses native GREEN reinforcements.
 replace('if (_side == RESISTANCE) then {','if (_side == RESISTANCE && {_neroCap<0}) then {');
 replace('_j = 0;',`if (_neroCap>=0) then {_sentriesTotal=_sentriesTotal min ceil (((_neroCap-_neroUsed) max 0)/3);};
diag_log format ["[NeroWL Garrison] sector=%1 side=%2 cap=%3 crew=%4 sentryGroups=%5",_sector getVariable ["BIS_WL_sectorName",str _sector],_side,_neroCap,_neroUsed,_sentriesTotal];
_j = 0;`);
 replace('while {count units _newGrp < 3} do {','while {count units _newGrp < (if (_neroCap<0) then {3} else {3 min (_neroCap-_neroUsed)})} do {');
 replace('\t\t_newGrp = createGroup [_side, TRUE];\n\t\twhile {count units _newGrp < (','\t\t_newGrp = createGroup [_side, TRUE];\n\t\twhile {count units _newGrp < (');
 replace('\t\t{\n\t\t\t_x spawn {','\t\t_neroUsed=_neroUsed+count units _newGrp;\n\t\t{\n\t\t\t_x spawn {');
 source=source.replace(/\s*$/,"")+"\nif (_greenGrant>0) then {[-_greenGrant] call NeroAI_fnc_greenRoom;};\n";
 return source;
}
function write(root=path.resolve(__dirname,"..")){
 const source=fs.readFileSync(path.join(root,"research/native/Warlords/fn_WLSectorPopulate.sqf"),"utf8");
 const output=path.join(root,"addons/NeroAI3/functions/native/fn_WLSectorPopulate.sqf");
 fs.writeFileSync(output,adapt(source));return output;
}
if(require.main===module)console.log(write());module.exports={adapt,write};
