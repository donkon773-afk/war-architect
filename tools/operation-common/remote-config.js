'use strict';
const fs=require('node:fs'),path=require('node:path'),{readEntry,indexEntries}=require('../read-pbo-entry'),{decodeRap}=require('../read-world-config');
// Inherit ACE/CBA permissions, while keeping NeroOP's guarded entry points.
// Required native effects plus the admin console used by full Zeus attributes.
const native=[...new Set([...require('../../dist/curator-functions.json').functions,'BIS_fnc_effectKilledAirDestruction','BIS_fnc_effectKilledSecondaries','BIS_fnc_fire','BIS_fnc_objectVar','BIS_fnc_setCustomSoundController','BIS_fnc_debugConsoleExec','BIS_fnc_advHint','BIS_fnc_showNotification','BIS_fnc_endMission','BIS_fnc_bleedTickets','BIS_fnc_moduleRespawnVehicle','BIS_fnc_callScriptedEventHandler','BIS_fnc_moduleHideTerrainObjects','BIS_fnc_moduleSector','BIS_fnc_addScore','BIS_fnc_HC_Local'])];
const functionPolicies=new Map();
function modFunctionInheritance(modPaths=[]){
 return modPaths.some(folder=>{
  if(functionPolicies.has(folder))return functionPolicies.get(folder);
  const addons=path.join(folder,'addons');let found=false;
  if(fs.existsSync(addons))for(const name of fs.readdirSync(addons).filter(n=>/\.pbo$/i.test(n))){
   const file=path.join(addons,name);
   for(const entry of indexEntries(file).filter(e=>/(^|[\\/])config\.bin$/i.test(e.name))){
    if(decodeRap(readEntry(file,entry.name)).classes.CfgRemoteExec?.classes.Functions){found=true;break;}
   }
   if(found)break;
  }
  functionPolicies.set(folder,found);return found;
 });
}
function extend(text,modPaths=[]){
 // Vanilla's imported CfgRemoteExec contains only obsolete Server/Client classes.
 // A nested Functions replacement must explicitly inherit when a loaded mod
 // defines that class (e.g. RHS smoke/grenade effects); otherwise no base exists.
 const functions='class Functions'+(modFunctionInheritance(modPaths)?':Functions':'')+' {mode=1;jip=0;';
 return text.replace('class CfgRemoteExec {','import CfgRemoteExec as CfgRemoteExecMod;class CfgRemoteExec:CfgRemoteExecMod {').replace('class Functions {mode=1;jip=0;',functions+native.map(fn=>'class '+fn+' {allowedTargets=0;jip='+(fn==='BIS_fnc_debugConsoleExec'?0:1)+';};').join(''));
}
function parseable(text){if(!text.includes('import CfgRemoteExec as CfgRemoteExecMod;'))throw Error('Native mod remote permissions are not inherited');return text.replace('import CfgRemoteExec as CfgRemoteExecMod;','');}
function verifyInheritance(config,modPaths){
 const remote=config.classes.CfgRemoteExec;
 if(remote?.parent!=='CfgRemoteExecMod'||remote.classes.Functions?.parent!==(modFunctionInheritance(modPaths)?'Functions':''))throw Error('Native remote function inheritance differs from selected mods');
 const functions=remote.classes.Functions;
 if(functions.values.jip!==0||native.some(fn=>functions.classes[fn]?.values.allowedTargets!==0||functions.classes[fn]?.values.jip!==(fn==='BIS_fnc_debugConsoleExec'?0:1)))throw Error('Native Zeus effect persistence policy differs');
 if(Object.entries(functions.classes).some(([fn,c])=>fn.startsWith('NeroOP_')&&(c.values.jip??0)!==0))throw Error('NeroOP requests must not persist for joining players');
}
module.exports={native,extend,parseable,modFunctionInheritance,verifyInheritance};
