"use strict";

// Port the local legacy Australia Port layout to native Arma 3 Warlords.
// The original JEZ mission and Workshop content are read only; this produces
// a small independent mission with native sector/base modules and AI slots.
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const profile = process.argv[2] ? JSON.parse(fs.readFileSync(process.argv[2],"utf8")) : null;
const sessionFile=path.join(root,"dist","launcher-mission-settings.json");
const session=profile?.missionSettings??(fs.existsSync(sessionFile)?JSON.parse(fs.readFileSync(sessionFile,"utf8")):{});
const dev=session.NeroWL_Dev!==0;
require("./adapt-garrison").write(root);
require("./adapt-vars-init").write(root);
require("./adapt-observer-init").write(root);
require("./adapt-purchase-availability").write(root);
require("./adapt-zone-restrictions").write(root);
require("./adapt-airdrop").write(root);
require("./adapt-frontline").write(root);
require("./adapt-purchase-items").write(root);
const editor=require("../control-center/warlords-editor");
const editorFile=path.join(root,"dist","warlords-editor-settings.json");
const edit=profile?.editorSettings??(fs.existsSync(editorFile)?JSON.parse(fs.readFileSync(editorFile,"utf8")):null);
const army=edit?editor.validate(edit.army):null;
const commanders=edit?.commanders??10;
if(![10,12,16].includes(commanders))throw new Error("Invalid commander count");
const world = profile?.world || "australia";
const missionName = profile?.name || "NeroAI_Warlords_Australia";
const title = (profile?.title || "NeroAI Warlords - Australia (Mac LLM)").replace("10v10",`${commanders}v${commanders}`);
if (!/^[A-Za-z0-9_]+$/.test(world) || !/^[A-Za-z0-9_]+$/.test(missionName)) throw new Error("Invalid mission output name");
const output = path.join(root, "missions", `${missionName}.${world}`);
fs.mkdirSync(output, { recursive: true });

const places = profile?.places || require("./australia-layout").places;
/* Historical initial port coordinates, retained in australia-layout.js:
  { id: 2, kind: "Base", name: "Darwin BLUFOR", side: 2, size: 250, funds: 10, position: [17151.758, 8.5, 33995.594] },
  { id: 3, kind: "Base", name: "South OPFOR", side: 1, size: 350, funds: 10, position: [35160.156, 14.281119, 12292.739] },
  { id: 4, kind: "Sector", name: "Darwin Port", side: 0, size: 100, funds: 30, position: [15677.396, 6.0816197, 33143.914] },
  { id: 5, kind: "Sector", name: "Alice Springs", side: 0, size: 350, funds: 30, position: [22119.721, 16.947033, 25610.58] },
  { id: 6, kind: "Sector", name: "Cairns", side: 0, size: 200, funds: 30, position: [32171.018, 5.2507868, 29826.059] },
  { id: 7, kind: "Sector", name: "Brisbane", side: 0, size: 250, funds: 30, position: [38162.809, 4.2315545, 19878.422] },
  { id: 8, kind: "Sector", name: "Adelaide", side: 0, size: 300, funds: 30, position: [24947.229, 7.4310384, 12915.924] },
  { id: 9, kind: "Sector", name: "Victoria", side: 0, size: 300, funds: 30, position: [31069.203, 4.5013757, 10640.909] },
]; */

const escape = value => String(value).replaceAll('"', '""');
const vec = p => `{${p.join(",")}}`;
function attribute(moduleType, name, value, type) {
  const encoded = type === "STRING" ? `"${escape(value)}"` : value;
  return `class Attribute${attribute.index++} { property="${moduleType}_${name}"; expression="_this setVariable ['${name}',_value,true];"; class Value { class data { class type { type[]={"${type}"}; }; value=${encoded}; }; }; };`;
}
function moduleItem(index, id, type, position, attributes) {
  attribute.index = 0;
  const body = attributes.map(([name, value, dataType]) => attribute(type, name, value, dataType)).join("\n");
  const prepare = type === "ModuleWLBase_F" && !profile?.designer ? `class Attribute${attributes.length} { property="NeroWL_prepareBase"; expression="_this call NeroWL_Mission_fnc_prepareBase;"; class Value { class data { class type { type[]={"SCALAR"}; }; value=1; }; }; };` : "";
  return `class Item${index} { dataType="Logic"; class PositionInfo { position[]=${vec(position)}; }; id=${id}; type="${type}"; class CustomAttributes { ${body} ${prepare} nAttributes=${attributes.length + (prepare ? 1 : 0)}; }; };`;
}
function warlord(index, id, side, type, position) {
  return `class Item${index} { dataType="Group"; side="${side}"; class Entities { items=1; class Item0 { dataType="Object"; class PositionInfo { position[]=${vec(position)}; }; side="${side}"; flags=7; class Attributes { isPlayable=1; ${(!profile?.observer && (profile?.playerSide === "EAST" ? id === 200 : id === 100)) ? "isPlayer=1; " : ""}init="this call NeroWL_Mission_fnc_placeCommander; this addEventHandler ['Respawn',{(_this # 0) call NeroWL_Mission_fnc_placeCommander;}];"; }; id=${id}; type="${type}"; }; }; class Attributes {}; id=${id + 1}; };`;
}

const entities = [];
entities.push(moduleItem(0, 1, "ModuleWLInit_F", places[0].position, [
  ["StartCP", 1500, "SCALAR"],
  ["MaxSubordinates", 9, "SCALAR"],
  ["FactionBLUFOR", army?.westFaction || profile?.westFaction || "rhs_faction_usarmy_d", "STRING"],
  ["FactionOPFOR", army?.eastFaction || profile?.eastFaction || "rhs_faction_msv", "STRING"],
  ["FactionIndep", profile?.greenFaction || "rhsgref_faction_cdf_ng", "STRING"],
  ["AssetList", "['NeroWL_RHSStart']", "STRING"],
  ["AIVoting", 1, "SCALAR"],
]));
for (const place of places) {
  const type = `ModuleWL${place.kind}_F`;
  entities.push(moduleItem(entities.length, place.id, type, place.position, [
    ["Name", place.name, "STRING"],
    ["Side", place.side, "SCALAR"],
    ["Size", place.size, "SCALAR"],
    ["Funds", place.funds, "SCALAR"],
    ["Border", 200, "SCALAR"],
    ...(place.designId ? [["NeroWL_designId",place.designId,"STRING"]] : []),
    ["Service_Runway", place.runway ? 1 : 0, "BOOL"],
    ["Service_Helipad", place.kind === "Base" || place.runway ? 1 : 0, "BOOL"],
    ["Service_Harbour", 0, "BOOL"],
  ]));
}
const west = places[0].position, east = places[1].position;
for (let i = 0; i < commanders; i++) {
  entities.push(warlord(entities.length, 100 + i * 2, "West", army?editor.commander(army,"west"):"rhsusf_army_ocp_squadleader", [west[0] + 12 + i * 4, west[1], west[2] + 8]));
  entities.push(warlord(entities.length, 200 + i * 2, "East", army?editor.commander(army,"east"):"rhs_msv_emr_sergeant", [east[0] + 12 + i * 4, east[1], east[2] + 8]));
}

if(profile?.observer)entities.push('class Item'+entities.length+' { dataType="Group"; side="Civilian"; id=900; class Attributes {}; class Entities {items=1; class Item0 {dataType="Object"; side="Civilian"; id=901; type="C_man_1"; flags=7; class PositionInfo {position[]={'+west.join(',')+'};}; class Attributes {isPlayable=1; isPlayer=1; description="NeroAI Observer / Zeus";};};};};');
// One connected graph: each army can reach the opposing base through sectors.
const edges = profile?.edges || require("./australia-layout").edges;
const links = edges.map(([a, b], i) => `class Item${i} { linkID=${i}; item0=${a}; item1=${b}; class CustomData { type="Sync"; }; };`).join("\n");
const mission = `version=54;
class EditorData { moveGridStep=1; angleGridStep=0.2617994; scaleGridStep=1; autoGroupingDist=10; class ItemIDProvider { nextID=300; }; class Camera { pos[]={22119.721,600,25610.58}; dir[]={0,-0.7,0.7}; up[]={0,0.7,0.7}; aside[]={1,0,0}; }; };
binarizationWanted=0;
sourceName="${missionName}";
randomSeed=531508;
addons[]={"A3_Modules_F_Warlords","A3_Characters_F","rhsusf_c_troops","rhs_c_troops","rhsgref_c_troops"${world.toLowerCase()==="australia"?',"australia"':""}};
class ScenarioData { author="NeroAI"; gameType="CTI"; respawn=3; respawnDelay=10; class Header { gameType="CTI"; minPlayers=1; maxPlayers=${commanders*2+(profile?.observer?1:0)}; }; };
class Mission {
  class Intel { briefingName="${escape(title)}"; overviewText="Native Warlords: paid combined arms and local LLM"; year=2035; month=6; day=24; hour=8; minute=0; startWeather=0.1; forecastWeather=0.1; };
  class Entities { items=${entities.length}; ${entities.join("\n")} };
  class Connections { class LinkIDProvider { nextID=${edges.length}; }; class Links { items=${edges.length}; ${links} }; };
};
`;
const description = `author = "NeroAI";
onLoadName = "${escape(title)}";
onLoadMission = "Native Warlords on ${escape(world)}. AI commanders, CP requisition and host Zeus.";
briefingName = "${escape(title)}";
class Header { gameType="CTI"; minPlayers=1; maxPlayers=${commanders*2+(profile?.observer?1:0)}; };
respawn = 3;
respawnDelay = 10;
respawnOnStart = -1;
disabledAI = 0;
joinUnassigned = 1;
enableDebugConsole = ${dev?2:1};
NeroWL_devMode = ${dev?1:0};
NeroWL_modShopEnabled = 1;
NeroWL_customCatalog = ${army?1:0};
NeroWL_personalScenario = 1;
corpseManagerMode = 1;
corpseLimit = 20;
corpseRemovalMinTime = 120;
corpseRemovalMaxTime = 300;
wreckManagerMode = 1;
wreckLimit = 8;
wreckRemovalMinTime = 300;
wreckRemovalMaxTime = 600;
`;
fs.writeFileSync(path.join(output, "mission.sqm"), mission);
fs.mkdirSync(path.join(output,"neroWL"),{recursive:true});
fs.copyFileSync(path.join(__dirname,"mission-assets","fn_waitReady.sqf"),path.join(output,"neroWL","fn_waitReady.sqf"));
let startPreset=army?editor.preset(army):fs.readFileSync(path.join(__dirname,"mission-assets","startPreset.hpp"),"utf8");
if(profile?.archivePreset&&!army){
  const archive=fs.readFileSync(path.join(output,"bfx","presets.hpp"),"utf8");
  const inner=archive.match(/class\s+CfgWLRequisitionPresets\s*\{([\s\S]*)\};\s*$/)?.[1];
  if(!inner)throw new Error("Archive preset root structure changed");
  startPreset=startPreset.replace(/\};\s*$/,inner+"\n};\n");
}
fs.writeFileSync(path.join(output,"neroWL","startPreset.hpp"),startPreset);
let lobby=fs.readFileSync(path.join(__dirname,"mission-assets","params.hpp"),"utf8");
const {parseConfig}=require("./validate-mission");
const options=parseConfig(lobby).classes.Params.classes;
for(const [id,value] of Object.entries(session)) {
  if(id==="NeroWL_Dev"||id==="NeroWL_Experiments")continue;
  if(!options[id]||!options[id].values.values.includes(value))throw new Error(`Invalid saved mission parameter ${id}`);
  const expression=new RegExp(`(class ${id} \\{[^\\n]*default=)[^;]+`);
  lobby=lobby.replace(expression,(_,prefix)=>prefix+value);
}
fs.writeFileSync(path.join(output,"neroWL","params.hpp"),lobby);
fs.copyFileSync(path.join(__dirname,"mission-assets","fn_applySettings.sqf"),path.join(output,"neroWL","fn_applySettings.sqf"));
for (const name of ["findOpenGround","prepareBase","placeCommander","configureNative"]) {
  fs.copyFileSync(path.join(__dirname,"mission-assets",`fn_${name}.sqf`),path.join(output,"neroWL",`fn_${name}.sqf`));
}
// Preserve the installed native purchase FSM and its CP/delivery/vehicle rules.
// Its three hard-coded four-man limits otherwise ignore a lobby setting of nine.
const purchases=require('./adapt-ai-purchases').adapt(fs.readFileSync(path.join(root,"research","native","Warlords","fn_WLAIPurchases.fsm"),"utf8"));
fs.writeFileSync(path.join(output,"neroWL","fn_aiPurchases.fsm"),purchases);
const nativeAddonDir=path.join(root,"addons","NeroAI3","functions","native");
fs.mkdirSync(nativeAddonDir,{recursive:true});
fs.writeFileSync(path.join(nativeAddonDir,"fn_WLAIPurchases.fsm"),purchases);
const extra = '#include "neroWL\\params.hpp"\n#include "neroWL\\startPreset.hpp"\n' + (profile?.archivePreset ? 'NeroWL_archivePreset="BFX_RHS_D";\n' : "") +
  'class CfgFunctions { class NeroWL_Mission { class Runtime { file="neroWL"; class findOpenGround {}; class prepareBase {}; class placeCommander {}; class aiPurchases { ext=".fsm"; }; class configureNative { preInit=1; }; class waitReady { postInit=1; }; }; '+(profile?.archivePreset?'class Catalog { file="neroWL"; class expandPreset { postInit=1; }; }; ':"")+'}; };\n';
fs.writeFileSync(path.join(output, "description.ext"), description + extra + require('../control-center/dev-mode').config({devMode:session.NeroWL_Experiments,parameters:session}));
fs.writeFileSync(path.join(output, "initServer.sqf"), `diag_log format ["[NeroWL Mission] ${missionName}: world=%1 multiplayer=%2 server=%3", worldName, isMultiplayer, isServer];\nNeroAI_maxEnemyArmyGroups=${commanders};\nNeroAI_maxEnemyGroups=3;\ncall compile preprocessFileLineNumbers "neroWL\\fn_applySettings.sqf";\n`);
console.log(`Native Australia Warlords mission: ${entities.length} entities, ${edges.length} sector links`);
