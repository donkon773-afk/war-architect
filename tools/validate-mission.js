"use strict";
// Read-only parser for the generated text config subset. This is not an Arma
// interpreter; it catches structural defects before packaging and installation.
const fs=require("node:fs"),path=require("node:path");
function parseConfig(text,{rejectDuplicateDeclarations=false}={}) {
  const tokens=text.replace(/\/\*[\s\S]*?\*\//g,"").replace(/\/\/[^\n]*/g,"").replace(/^\s*#.*$/gm,"")
    .match(/"(?:""|[^"])*"|-?\d+(?:\.\d+)?(?:e[+-]?\d+)?(?![A-Za-z0-9_])|\d+[A-Za-z_][A-Za-z0-9_]*|[A-Za-z_][A-Za-z0-9_]*|[{}\[\]=;:,]/gi)||[];
  let index=0;
  function take(value){const token=tokens[index++];if(value&&token!==value)throw new Error(`Expected ${value}, got ${token}`);return token;}
  function value(){if(tokens[index]==="{"){take("{");const a=[];while(tokens[index]!=="}"){a.push(value());if(tokens[index]===",")take(",");else if(tokens[index]!=="}")throw new Error("Invalid array");}take("}");return a;}
    const v=take();return v?.startsWith('"')?v.slice(1,-1).replaceAll('""','"'):Number(v);}
  function body(end){const out={values:{},classes:{}};while(index<tokens.length&&tokens[index]!==end){
    if(tokens[index]==="class"){take("class");const name=take();let parent="";if(tokens[index]===":"){take(":");parent=take();}
      if(rejectDuplicateDeclarations && out.classes[name] && (tokens[index]===";" || !out.classes[name]._forward))throw new Error("Duplicate class declaration: "+name);
      if(tokens[index]===";"){take(";");out.classes[name]={values:{},classes:{},parent,...(rejectDuplicateDeclarations?{_forward:true}:{})};continue;}
      take("{");out.classes[name]=body("}");out.classes[name].parent=parent;take("}");take(";");}
    else if(tokens[index]==="import"){take("import");const type=take();take("as");const alias=take();take(";");(out.imports??=[]).push({type,alias});}
    else {const name=take();if(tokens[index]==="["){take("[");take("]");}take("=");out.values[name]=value();take(";");}}
    return out;}
  const result=body(null);if(index!==tokens.length)throw new Error("Trailing config tokens");return result;
}
function validateMission(sqm,description) {
  const root=parseConfig(sqm),mission=root.classes.Mission;
  if(!mission)throw new Error("Mission class absent");
  const entities=Object.values(mission.classes.Entities?.classes||{});
  if(mission.classes.Entities?.values.items!==entities.length)throw new Error("Entity count mismatch");
  const descCheck=parseConfig(description);
  if(descCheck.values.NeroWL_threeSides===1){
    if(entities.some(e=>e.values.type==='ModuleWLInit_F'))throw Error('Three-side mode cannot start native two-side initializer');
    const combat=entities.filter(e=>e.values.side!=="Civilian");if(![30,36,48].includes(combat.length))throw Error('Three-side slots required');
    for(const side of ['West','East','Independent'])if(entities.filter(e=>e.values.side===side).length!==combat.length/3)throw Error('Unbalanced three-side lobby');
    const cfg=descCheck.classes.CfgNeroDesign;if(Object.keys(cfg?.classes.Bases?.classes||{}).length!==3||!Object.keys(cfg?.classes.Garrisons?.classes||{}).length)throw Error('Three bases and capture sectors required');
    if(descCheck.classes.Header?.values.maxPlayers!==entities.length||descCheck.values.disabledAI!==0)throw Error('Lobby AI and slots inconsistent');
    const metadata=root.classes.ScenarioData,header=metadata?.classes.Header?.values;
    if(root.values.version!==54||root.values.binarizationWanted!==0||!root.values.sourceName||!root.classes.EditorData||metadata?.values.gameType!=='CTI'||header?.gameType!=='CTI'||header.minPlayers!==1||header.maxPlayers!==entities.length)throw Error('Three-side ScenarioData multiplayer metadata missing or inconsistent');
    const units=entities.flatMap(e=>Object.values(e.classes.Entities?.classes||{}));
    if(units.filter(u=>u.classes.Attributes?.values.isPlayer===1).length!==1)throw Error('Three-side mission must have exactly one default player');
    const observer=descCheck.values.NeroWL_observer===1;
    if(units.some(u=>u.classes.Attributes?.values.isPlayer===1&&u.classes.Attributes.values.isPlayable!==1)||units.some(u=>u.values.side!=='Civilian'&&u.classes.Attributes?.values.isPlayable!==(observer?0:1)))throw Error('Three-side playable slots inconsistent with player role');
    const ids=entities.flatMap(e=>[e.values.id,...Object.values(e.classes.Entities.classes).map(u=>u.values.id)]);if(new Set(ids).size!==ids.length)throw Error('Duplicate IDs');
    return {slots:entities.length,sectors:Object.keys(cfg.classes.Garrisons.classes).length,mode:'three'};
  }
  const modules=entities.filter(e=>e.values.dataType==="Logic");
  if(modules.filter(e=>e.values.type==="ModuleWLInit_F").length!==1)throw new Error("Exactly one native Warlords init required");
  const sectors=modules.filter(e=>/^ModuleWL(Base|Sector)_F$/.test(e.values.type));
  if(sectors.filter(e=>e.values.type==="ModuleWLBase_F").length!==2)throw new Error("Two bases required");
  for (const sector of sectors) {
    const attrs=Object.values(sector.classes.CustomAttributes?.classes||{});
    const border=attrs.find(a=>a.values.property===`${sector.values.type}_Border`);
    const data=border?.classes.Value?.classes.data;
    if(data?.classes.type?.values.type?.[0]!=="SCALAR" || !Number.isFinite(data?.values.value) || data.values.value < 0) throw new Error("Sector Border must be numeric meters (SCALAR), not BOOL");
  }
  const groupsAll=entities.filter(e=>e.values.dataType==="Group"),groups=groupsAll.filter(e=>e.values.side!=="Civilian");
  if(![20,24,32].includes(groups.length))throw new Error("Expected 10, 12 or 16 commander slots per side");
  const allIds=[];
  for(const e of entities){allIds.push(e.values.id);for(const u of Object.values(e.classes.Entities?.classes||{}))allIds.push(u.values.id);}
  if(allIds.some(id=>!Number.isInteger(id))||new Set(allIds).size!==allIds.length)throw new Error("Missing or duplicate entity ID");
  for(const side of ["West","East"]){const units=groups.filter(g=>g.values.side===side).flatMap(g=>Object.values(g.classes.Entities?.classes||{}));
    if(units.length!==groups.length/2||units.some(u=>u.classes.Attributes?.values.isPlayable!==1))throw new Error(`Ten playable ${side} slots required`);
    const expected=side==="West"?"rhsusf_army_ocp_squadleader":"rhs_msv_emr_sergeant";
    if(units.some(u=>!require("../control-center/warlords-editor").inventory().assets.some(a=>a.class===u.values.type&&a.kind==="INFANTRY"&&a.side===(side==="West"?1:0))))throw new Error(`Installed ${side} commander class required`);}
  const ids=new Set(sectors.map(s=>s.values.id)),links=Object.values(mission.classes.Connections?.classes.Links?.classes||{});
  if(mission.classes.Connections?.classes.Links?.values.items!==links.length)throw new Error("Link count mismatch");
  const seen=new Set([sectors[0].values.id]);let previous=-1;
  while(previous!==seen.size){previous=seen.size;for(const l of links){const {item0:a,item1:b}=l.values;
    if(!ids.has(a)||!ids.has(b)||l.classes.CustomData?.values.type!=="Sync")throw new Error("Invalid sector link");
    if(seen.has(a))seen.add(b);if(seen.has(b))seen.add(a);}}
  if(seen.size!==ids.size)throw new Error("Disconnected sector graph");
  const desc=parseConfig(description),header=desc.classes.Header?.values;
  if(header?.gameType!=="CTI"||header.minPlayers!==1||header.maxPlayers!==groupsAll.length)throw new Error("Multiplayer Header missing or inconsistent");
  if(desc.values.disabledAI!==0||![1,2].includes(desc.values.enableDebugConsole)||![0,1].includes(desc.values.NeroWL_devMode)||desc.values.NeroWL_personalScenario!==1)throw new Error("AI/debug/host setup disabled");
  if(/JEZ_Warlords/.test(sqm+description))throw new Error("Legacy JEZ dependency");
  return {slots:groupsAll.length,sectors:sectors.length-2,links:links.length};
}
function validateDirectory(dir){
  const source=fs.readFileSync(path.join(dir,"description.ext"),"utf8"),result=validateMission(fs.readFileSync(path.join(dir,"mission.sqm"),"utf8"),source);
  function expand(file,visited=new Set()){
    if(visited.has(file))throw new Error("Circular include");visited.add(file);
    const text=fs.readFileSync(file,"utf8").replace(/^\s*#include\s+"([^"]+)"\s*$/gm,(_,rel)=>{
      const child=path.resolve(path.dirname(file),rel.replaceAll("\\",path.sep));
      if(!child.startsWith(path.resolve(dir)+path.sep))throw new Error("Include escapes mission folder");return expand(child,new Set(visited));});
    return text;
  }
  const expanded=expand(path.join(dir,"description.ext")),full=parseConfig(expanded);
  if((expanded.match(/class\s+CfgWLRequisitionPresets\b/g)||[]).length!==1)throw new Error("Duplicate catalog root");
  if(!full.classes.CfgWLRequisitionPresets?.classes.NeroWL_RHSStart)throw new Error("Native RHS starter preset missing");
  if(!full.classes.Params?.classes.NeroWL_LLM)throw new Error("Lobby settings missing");
  if(result.mode==='three'&&full.values.NeroWL_cqInterface===2){
    const runtime=full.classes.CfgFunctions?.classes.NeroWL_Design?.classes.Runtime;
    if(runtime?.values.file!=='neroDesign'||runtime.classes.cqInit?.values.postInit!==1)throw Error('Three-side UI runtime registration missing');
    for(const fn of ['start','spawnAsset','observer',...require('./build-three-mission').runtimeFunctions]){
      if(!runtime.classes[fn]||!fs.existsSync(path.join(dir,'neroDesign','fn_'+fn+'.sqf')))throw Error('Three-side UI function missing: '+fn);
      const code=fs.readFileSync(path.join(dir,'neroDesign','fn_'+fn+'.sqf'),'utf8');
      for(const reference of code.matchAll(/NeroWL_Design_fnc_(\w+)/g))if(!runtime.classes[reference[1]])throw Error('Three-side UI callback unregistered: '+reference[1]);
    }
    const remote=full.classes.CfgRemoteExec?.classes.Functions;
    if(remote?.values.mode!==1||remote.values.jip!==0)throw Error('Three-side UI remote policy missing');
    for(const fn of ['cqBuy','cqTravel','cqVote'])if(remote.classes['NeroWL_Design_fnc_'+fn]?.values.allowedTargets!==2)throw Error('Three-side UI operation must target server: '+fn);
    for(const fn of ['cqPurchase','cqRequest','cqLedger'])if(remote.classes['NeroWL_Design_fnc_'+fn])throw Error('Internal purchase helpers cannot be remote-callable');
  }
  return result;
}
if(require.main===module)console.log(JSON.stringify(validateDirectory(process.argv[2]),null,2));
module.exports={parseConfig,validateMission,validateDirectory};
