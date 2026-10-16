"use strict";
const fs=require("node:fs"),path=require("node:path");
function adapt(source){
 source=source.replaceAll("\r\n","\n");
 const anchor='_class = _assetDetails # 0;';
 const defaultCase='\t\tdefault {\n\t\t\t_vehiclesCnt';
 if(!source.includes(anchor)||!source.includes(defaultCase))throw new Error("Native purchase availability source changed");
 // 7.10: fall back to the player's own catalog row when the listbox data lost a field.
 return source.replace(anchor,anchor+'\nprivate _category = _assetDetails param [5,"",[""]];\nif !(_category in ["Infantry","Vehicles","Gear","Defences","Aircraft","Naval","Gear_custom"]) then {{private _neroRows = _x select {(_x # 0) isEqualTo _class}; if (_neroRows isNotEqualTo []) exitWith {_category = (_neroRows # 0) param [6,"",[""]];};} forEach (player getVariable ["BIS_WL_purchasable",[]]);};')
 .replace(defaultCase,'\t\tdefault {\n            if !(_category in ["Infantry","Vehicles","Gear","Defences","Aircraft","Naval","Gear_custom"]) exitWith {_ret=FALSE;_tooltip="Категория покупки не готова. Выберите категорию заново.";};\n\t\t\t_vehiclesCnt');
}
function write(root=path.resolve(__dirname,"..")){
 const out=path.join(root,"addons/NeroAI3/functions/native/fn_WLSubroutine_purchaseMenuAssetAvailability.sqf");
 fs.writeFileSync(out,adapt(fs.readFileSync(path.join(root,"research/native/Warlords/fn_WLSubroutine_purchaseMenuAssetAvailability.sqf"),"utf8")));return out;
}
if(require.main===module)console.log(write());module.exports={adapt,write};
