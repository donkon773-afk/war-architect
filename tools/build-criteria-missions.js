"use strict";
const fs=require("node:fs"),path=require("node:path"),{execFileSync}=require("node:child_process");
const root=path.resolve(__dirname,"..");
const distance=(a,b)=>Math.hypot(a[0]-b[0],a[1]-b[1]);
function graph(places) {
  const seen=new Set([0]),edges=[];
  while(seen.size<places.length) {
    let pair,best=Infinity;
    for(const a of seen)for(let b=0;b<places.length;b++)if(!seen.has(b)){
      const d=distance([places[a].position[0],places[a].position[2]],[places[b].position[0],places[b].position[2]]);
      if(d<best){best=d;pair=[a,b];}
    }
    edges.push(pair.map(n=>places[n].id));seen.add(pair[1]);
  }
  return edges;
}
function surveyedPlaces(meta) {
  if(meta.airports.length<2)throw new Error("Two actual airports required");
  let pair,best=-1;
  for(const a of meta.airports)for(const b of meta.airports){const d=distance(a.position,b.position);if(d>best){best=d;pair=[a,b];}}
  const bases=pair.map((a,i)=>({id:i+2,kind:"Base",name:`${i===0?"BLUFOR":"OPFOR"} Airfield ${a.id}`,side:i===0?2:1,size:300,funds:10,position:[a.position[0],0,a.position[1]],runway:true}));
  const selected=[];
  const towns=meta.locations.filter(t=>/^Name(City|Village)/.test(t.type||"")&&pair.every(a=>distance(a.position,t.position)>1000));
  towns.sort((a,b)=>distance(a.position,pair[0].position)-distance(b.position,pair[0].position));
  for(const t of towns) {
    if(selected.length===8)break;
    if(selected.every(s=>distance(s.position,t.position)>Math.max(900,best/8)))selected.push(t);
  }
  if(selected.length<3)throw new Error("Not enough real towns");
  return [...bases,...selected.map((t,i)=>({id:i+4,kind:"Sector",name:t.name&&!t.name.startsWith("$")?t.name:t.id.replace(/^(?:city|vill)_/i,"").replaceAll("_"," "),side:0,size:250,funds:30,position:[t.position[0],0,t.position[1]],runway:false}))];
}
function australiaPlaces() {
  return require("./australia-layout").places.map(p=>({...p,position:[...p.position]}));
  /* Historical initial layout:
  return [
    ["Darwin BLUFOR",[17151.758,8.5,33995.594],2,false],
    ["South OPFOR",[35160.156,14.281119,12292.739],1,true],
    ["Darwin Port",[15677.396,6.0816197,33143.914],0,false],
    ["Alice Springs",[22119.721,16.947033,25610.58],0,false],
    ["Cairns",[32171.018,5.2507868,29826.059],0,false],
    ["Brisbane",[38162.809,4.2315545,19878.422],0,false],
    ["Adelaide",[24947.229,7.4310384,12915.924],0,true],
    ["Victoria",[31069.203,4.5013757,10640.909],0,true]
  ].map(([name,position,side,runway],i)=>({id:i+2,kind:i<2?"Base":"Sector",name,position,side,runway,size:i<2?300:250,funds:i<2?10:30})); */
}
function buildAll() {
  const result=[];
  const editorFile=path.join(root,"dist","warlords-editor-settings.json");
  const slots=2*(fs.existsSync(editorFile)?JSON.parse(fs.readFileSync(editorFile,"utf8")).commanders:10);
  for(const [title,world] of [["Australia","australia"],["Takistan","takistan"],["Altis","Altis"],["Chernarus","Chernarus"]]) {
    const original=path.join(root,"research","user-archives",`WL_RHS_Zeus_${title}.${world}`);
    const sqm=fs.readFileSync(path.join(original,"mission.sqm"),"utf8");
    if(/type\s*=\s*"(?:JEZ_)?ModuleWL/.test(sqm))throw new Error("Archive structure changed: audit before rebuild");
    const name=`NeroAI_WL_RHS_Zeus_${title}`;
    const places=world==="australia"?australiaPlaces():surveyedPlaces(JSON.parse(fs.readFileSync(path.join(root,"research","worlds",world.toLowerCase(),"metadata.json"),"utf8")));
    const edges=world==="australia"?require("./australia-layout").edges:graph(places);
    const profile={name,world,title:`NeroAI Warlords RHS + Zeus - ${title}`,archivePreset:"BFX_RHS_D",westFaction:"rhs_faction_usarmy_d",eastFaction:"rhs_faction_msv",places,edges};
    const output=path.join(root,"missions",`${name}.${world}`);
    fs.mkdirSync(path.join(output,"bfx"),{recursive:true});fs.mkdirSync(path.join(output,"neroWL"),{recursive:true});
    fs.copyFileSync(path.join(original,"bfx","presets.hpp"),path.join(output,"bfx","presets.hpp"));
    fs.copyFileSync(path.join(root,"tools","mission-assets","fn_expandPreset.sqf"),path.join(output,"neroWL","fn_expandPreset.sqf"));
    const profilePath=path.join(root,"dist",`${name}.layout.json`);fs.writeFileSync(profilePath,JSON.stringify(profile,null,2));
    execFileSync(process.execPath,[path.join(__dirname,"build-australia-mission.js"),profilePath],{stdio:"pipe"});
    fs.writeFileSync(path.join(output,"README.txt"),`${profile.title}\nLocal hosted multiplayer through NeroAI launcher. ${slots/2} commander slots per side; AI enabled; 9 subordinates + commander by default.\nNative AI fast travel; up to 5 AI aircraft per side, paid with CP. ACE is in launcher preset.\nHost Zeus: Y; debug console: Esc. Aircraft and vehicles cost CP.\nNative Warlords modules and connected sectors included; no Eden builder step needed.\nNumeric Border fixes client marker/HUD init; readiness requires native client HUD.\nRHS preset classes are validated against loaded public configs, not blindly enabled.\nBase/commander ground positions are validated at mission start, away from terrain buildings.\nCoordinates: ${world==="australia"?"installed Australia Names/ILS config":"installed map Names/ILS config"}.\nEngine acceptance is pending; no gameplay test is claimed.\n`);
    result.push({world,name,title:profile.title,output,sectors:places.length-2,commanderSlots:slots,edges,issuesFixed:["native Warlords modules absent","AI disabled by description","configurable commander slots","unvalidated RHS classes filtered"]});
    console.log(`${title}: ${places.length-2} sectors, ${slots} commander slots, native Warlords and validated RHS requisition`);
  }
  fs.writeFileSync(path.join(root,"dist","criteria-missions.json"),JSON.stringify(result,null,2));
  return result;
}
if(require.main===module)buildAll();
module.exports={graph,surveyedPlaces,australiaPlaces,buildAll};
