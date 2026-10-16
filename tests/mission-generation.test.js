"use strict";
const test=require("node:test"),assert=require("node:assert/strict"),fs=require("node:fs"),path=require("node:path");
const {validateDirectory,validateMission}=require("../tools/validate-mission");
const root=path.resolve(__dirname,"..");
test("generated missions include playable opponents and a connected native Warlords graph",()=>{
  const missions=JSON.parse(fs.readFileSync(path.join(root,"dist","criteria-missions.json"),"utf8"));
  assert.equal(missions.length,4);
  for(const m of missions){const v=validateDirectory(m.output);assert.equal(v.slots,m.commanderSlots);assert.ok(v.sectors>=6);}
});
test("validator rejects missing red slots, an empty graph, and disabled bots",()=>{
  const dir=path.join(root,"missions","NeroAI_Warlords_Australia.australia");
  const sqm=fs.readFileSync(path.join(dir,"mission.sqm"),"utf8"),desc=fs.readFileSync(path.join(dir,"description.ext"),"utf8");
  assert.throws(()=>validateMission(sqm.replaceAll('side="East"','side="West"'),desc),/West|East/);
  assert.throws(()=>validateMission(sqm.replace('type="Sync"','type="None"'),desc),/Invalid sector link/);
  assert.throws(()=>validateMission(sqm,desc.replace('disabledAI = 0','disabledAI = 1')),/disabled/);
  assert.throws(()=>validateMission(sqm,desc.replace(/class Header[^\n]+\n/,"")),/Header/);
});
test("Australia uses the five requested locations from the installed map config",()=>{
  const layout=require("../tools/australia-layout");
  const expected={Perth:[5445,18695],Willcania:[31302,16764],Toowoomba:[30955,19997],"Coober Pedy":[22300,19289],"Pine Gap":[19764,24355]};
  const config=fs.readFileSync(path.join(root,"research","worlds","australia","config-data.bin"),"utf8");
  for(const [name,position] of Object.entries(expected)){
    const town=layout.places.find(p=>p.name===name);assert(town);
    assert.deepEqual([town.position[0],town.position[2]],position);
    const at=config.indexOf(`name = "${name}"`);assert(at>=0);
    assert(config.slice(at,at+110).includes(`position[] = {${position.join(",")}}`));
    assert(layout.edges.filter(e=>e.includes(town.id)).length>=2,`${name} must have two connected approaches`);
  }
});
test("lobby options resolve to native Warlords parameters and bounded server controls",()=>{
  const {parseConfig}=require("../tools/validate-mission");
  const params=parseConfig(fs.readFileSync(path.join(root,"tools","mission-assets","params.hpp"),"utf8")).classes.Params.classes;
  for(const name of ["BIS_WLStartCP","BIS_WLCPMultiplier","BIS_WLMaxSubordinates","BIS_WLStartingDaytime","BIS_WLFTEnabled"]){assert(params[name]);const key=name.replace("BIS_WL","");assert(fs.readFileSync(path.join(root,"research","native","Warlords","fn_WLInit.sqf"),"utf8").includes(`"${key}"`));}
  for(const entry of Object.values(params)){assert(entry.values.values.includes(entry.values.default));assert.equal(entry.values.values.length,entry.values.texts.length);}
  const settings=fs.readFileSync(path.join(root,"tools","mission-assets","fn_applySettings.sqf"),"utf8");
  assert(settings.includes('if !(_value in _allowed)'));assert(settings.includes('!isPlayer _x'));
});
test("mission workers have balanced SQF delimiters and no model-code execution",()=>{
  for(const name of fs.readdirSync(path.join(root,"tools","mission-assets")).filter(n=>n.endsWith(".sqf"))){
    const source=fs.readFileSync(path.join(root,"tools","mission-assets",name),"utf8");
    const code=source.replace(/\/\*[\s\S]*?\*\//g,"").replace(/\/\/[^\n]*/g,"").replace(/"(?:""|[^"])*"/g,'""');
    assert.doesNotMatch(code,/\bcompile\b|\bexecVM\b|\bpreprocessFile/i);
    const stack=[],matching={")":"(","]":"[","}":"{"};
    for(const c of code){if("([{ ".includes(c)&&c!==" ")stack.push(c);if(matching[c])assert.equal(stack.pop(),matching[c],name);}
    assert.equal(stack.length,0,name);
  }
});
test("sector Border rejects the boolean type that aborted native client initialization",()=>{
  const dir=path.join(root,"missions","NeroAI_Warlords_Australia_RHS20.australia");
  const sqm=fs.readFileSync(path.join(dir,"mission.sqm"),"utf8"),desc=fs.readFileSync(path.join(dir,"description.ext"),"utf8");
  const wrong=sqm.replace(/(property="ModuleWLBase_F_Border"[\s\S]*?type\[\]=\{)"SCALAR"/, '$1"BOOL"');
  assert.notEqual(wrong,sqm);assert.throws(()=>validateMission(wrong,desc),/Border must be numeric/);
  const ready=fs.readFileSync(path.join(root,"tools","mission-assets","fn_waitReady.sqf"),"utf8");
  assert(ready.includes('displayCtrl 9989999'));assert(ready.includes('BIS_WL_selectionFSM'));assert(ready.includes('markerShape "BIS_WL_sectorMrkr_0"'));
});
test("AI purchases preserve native delivery and fast travel while respecting squad limits and air budgets ",()=>{
  const dir=path.join(root,"missions","NeroAI_Warlords_Australia_RHS20.australia","neroWL");
  const original=fs.readFileSync(path.join(root,"research","native","Warlords","fn_WLAIPurchases.fsm"),"utf8");
  const modified=fs.readFileSync(path.join(root,"addons","NeroAI3","functions","native","fn_WLAIPurchases.fsm"),"utf8");
  const seats='_maxCrew = (_veh emptyPositions ""Commander"") + (_veh emptyPositions ""Driver"") + (_veh emptyPositions ""Gunner"") + (_veh emptyPositions ""Cargo"");';
  assert.equal(modified,require('../tools/adapt-ai-purchases').adapt(original));
  const {parseConfig}=require("../tools/validate-mission");
  const params=parseConfig(fs.readFileSync(path.join(dir,"params.hpp"),"utf8")).classes.Params.classes;
  assert([9,12].includes(params.BIS_WLMaxSubordinates.values.default));assert(params.BIS_WLMaxSubordinates.values.values.every(n=>n>=9));
  assert([0,1,2,3,4].includes(params.BIS_WLFTEnabled.values.default));assert(params.NeroWL_Air.values.values.includes(params.NeroWL_Air.values.default));
  const configure=fs.readFileSync(path.join(dir,"fn_configureNative.sqf"),"utf8");assert(!configure.includes('BIS_fnc_WLAICore ='));
});
test("native purchase adaptation resolves before final compilation instead of assigning a final function",()=>{
  const {parseConfig}=require("../tools/validate-mission");
  const cfg=parseConfig(fs.readFileSync(path.join(root,"addons","NeroAI3","functions","CfgFunctions.hpp"),"utf8"));
  const fn=cfg.classes.CfgFunctions.classes.A3_Warlords.classes.Warlords.classes.WLAIPurchases.values;
  assert.equal(fn.file,'\\NeroWL\\functions\\native\\fn_WLAIPurchases.fsm');assert.equal(fn.ext,'.fsm');
  const addon=fs.readFileSync(path.join(root,"addons","NeroAI3","functions","native","fn_WLAIPurchases.fsm"),"utf8");
  const original=fs.readFileSync(path.join(root,"research","native","Warlords","fn_WLAIPurchases.fsm"),"utf8");assert.equal(addon,require('../tools/adapt-ai-purchases').adapt(original));
  const preInit=fs.readFileSync(path.join(root,"tools","mission-assets","fn_configureNative.sqf"),"utf8");assert(!preInit.includes('BIS_fnc_WLAIPurchases ='));assert(preInit.includes('purchase FSM configured=%1'));
  assert(fs.readFileSync(path.join(root,"addons","NeroAI3","config.cpp"),"utf8").includes('"A3_Functions_F_Warlords"'));
});
