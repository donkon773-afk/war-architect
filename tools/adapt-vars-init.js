"use strict";
const fs=require("node:fs"),path=require("node:path");
function adapt(source){
 source=source.replaceAll("\r\n","\n");
 // 9.10: the observer host skips the client block, but native sound messages and the
 // sector-scan reveal still run on a machine with a UI — give them inert defaults.
 // NeroWL_localObserver is set by the adapted WLInit (Civilian observer only).
 const observer='(missionNamespace getVariable ["NeroWL_localObserver", getNumber (missionConfigFile >> "NeroWL_observer") == 1])';
 source=source.replace("if !(isDedicated) then {", "if (!isDedicated && {"+observer+"}) then {BIS_WL_revealArr = []; BIS_WL_voice = 0; BIS_WL_music = 0;};\nif (!isDedicated && {!"+observer+"}) then {");
 const before='BIS_WL_factionAppropriateUniforms = "getNumber (_x >> \'scope\') == 2" configClasses BIS_WL_cfgWpns;';
 if(!source.includes(before))throw new Error("Native WLVarsInit uniform scan changed");
 return 'diag_log "[NeroWL Init] native variables started";\n'+source.replace(before,
 `// Only uniforms support isUniformAllowed. Weapons and compatibility stubs
 // produce thousands of missing-entry warnings and delay host initialization.
 BIS_WL_factionAppropriateUniforms = "getNumber (_x >> 'scope') == 2 && {getNumber (_x >> 'ItemInfo' >> 'type') == 801} && {getText (_x >> 'ItemInfo' >> 'uniformClass') != ''}" configClasses BIS_WL_cfgWpns;
 diag_log format ["[NeroWL Init] uniform candidates=%1",count BIS_WL_factionAppropriateUniforms];`)+ '\ndiag_log "[NeroWL Init] native variables finished";\n';
}
function write(root=path.resolve(__dirname,"..")){
 const output=path.join(root,"addons/NeroAI3/functions/native/fn_WLVarsInit.sqf");
 fs.writeFileSync(output,adapt(fs.readFileSync(path.join(root,"research/native/Warlords/fn_WLVarsInit.sqf"),"utf8")));return output;
}
if(require.main===module)console.log(write());module.exports={adapt,write};
