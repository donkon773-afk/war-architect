"use strict";
/* 11.10: shareable demo copy of the Control Center.
 * Snapshot of the panel's GET data (no API keys, node addresses, disk paths or
 * Arma profile name) + the real index.html/designer.html with a fetch shim
 * instead of the local server. Opens by double click (file://), no Node needed.
 * Maps are copied in their original form (8K overview + every satellite detail
 * tile + street/building vectors), exactly what the panel serves; --width N
 * builds a light copy instead (downscaled overview, no detail tiles).
 * Only reads the project; writes into dist/share-demo/.
 *
 *   node tools/build-share-demo.js [--width 3072 [--quality 80]] [--no-vector] [--no-zip]
 */
const fs=require("node:fs"),path=require("node:path"),{execFileSync}=require("node:child_process");
const project=path.resolve(__dirname,".."),cc=path.join(project,"control-center"),here=path.join(__dirname,"share-demo");
const args=process.argv.slice(2),opt=(name,def)=>{const i=args.indexOf("--"+name);return i<0?def:Number(args[i+1]);};
const WIDTH=opt("width",0),QUALITY=opt("quality",80),ORIGINAL=!WIDTH,VECTOR=!args.includes("--no-vector"),ZIP=!args.includes("--no-zip");
const NAME="NeroAI-Control-Center-Demo",outRoot=path.join(project,"dist","share-demo"),out=path.join(outRoot,NAME);

const core=require(path.join(cc,"core")),editor=require(path.join(cc,"warlords-editor")),design=require(path.join(cc,"scenario-design"));
const background=require(path.join(cc,"map-background")),presets=require(path.join(cc,"map-presets")),factions=require(path.join(cc,"faction-names"));
const clone=v=>JSON.parse(JSON.stringify(v));

/* ---- snapshot ---- */
const state=core.publicState();
const DEMO_PROFILE="Player";
const nodeUrl=(n,i)=>{try{if(["127.0.0.1","localhost","::1"].includes(new URL(n.baseUrl).hostname))return "http://127.0.0.1:1234/v1";}catch{}return `http://llm-node-${i+1}.local:1234/v1`;};
const nodes=state.nodes.map((n,i)=>({id:n.id,label:n.label,baseUrl:nodeUrl(n,i),model:n.model||""}));
const anon=s=>s&&typeof s==="object"?{...s,profile:DEMO_PROFILE}:s;
const profile={version:state.version,nodes,selected:anon(clone(state.selected)),presets:Object.fromEntries(Object.entries(state.presets||{}).map(([k,v])=>[k,anon(clone(v))])),activePreset:state.activePreset||"",revision:state.revision||0};
const staticState={maps:state.maps,parameters:state.parameters,armyDefaults:state.armyDefaults,missionNames:state.missionNames};

const inv=editor.inventory();
const catalog={version:inv.version,scannedAt:inv.scannedAt,evidence:inv.evidence,assets:inv.assets.map(({modPath,...a})=>a),factions:inv.factions,mods:inv.mods.map(({path:_p,...m})=>m),errors:[],factionLabels:factions.labels(inv.factions)};

const worldsRaw=design.worlds(),vectorWorlds=[],imageJobs=[];
const worlds=worldsRaw.map(w=>{const {modPath,sourcePbo,preview,...rest}=w,m=background.metadata(w);let bg=null;
  if(m){const src=background.file(w);/* the same overview the panel serves: 8K when built */
    if(src&&fs.existsSync(src)){imageJobs.push([src,path.join(out,"maps",w.id+".jpg"),w]);
      const hasVector=VECTOR&&!!background.vectorFile(w);if(hasVector)vectorWorlds.push(w);
      bg={...m,vector:hasVector,...(ORIGINAL?{}:{overviewWidth:WIDTH})};}}
  return {...rest,background:bg,hasImage:false};});

const designs={},blank={};
for(const w of worldsRaw){blank[w.id]=design.blank(w.id);if(fs.existsSync(path.join(cc,"data","designs",w.id+".json")))designs[w.id]=design.load(w.id);}
const mapPresets={};for(const p of presets.list())mapPresets[p.id]=presets.get(p.id);

const models={};
const addModel=(node,model)=>{if(!node||typeof model!=="string"||!model.trim())return;(models[node]||(models[node]=[])).includes(model)||models[node].push(model);};
for(const n of nodes)addModel(n.id,n.model);
for(const s of [profile.selected,...Object.values(profile.presets)])for(const r of ["primary","secondary","ally"])addModel(s[r+"Node"],s[r+"Model"]);
for(const d of [...Object.values(designs),...Object.values(mapPresets).map(p=>p.design)])if(d.garrisonLLM?.node)addModel(d.garrisonLLM.node,d.garrisonLLM.model);

const snapshotDate=new Date().toLocaleDateString("ru-RU");
const data={snapshotDate,tiles:ORIGINAL,staticState,catalog,worlds,blank,models,mutable:{profile,designs,mapPresets}};

/* ---- privacy gate: refuse to build if anything personal slipped through ---- */
const text=JSON.stringify(data);
const forbidden={"IP-адрес":/\b(?:\d{1,3}\.){3}\d{1,3}\b/g,"путь к диску":/\b[A-Za-z]:\\\\/g,"папка пользователя":/Users\\\\/gi,"имя профиля":/donko/gi,"ключ API":/\bsk-[A-Za-z0-9]{8,}|Bearer\s+[A-Za-z0-9]/g};
const allowedIps=new Set(["127.0.0.1"]);
function privacyGate(where,s){for(const [what,re] of Object.entries(forbidden)){const hits=(s.match(re)||[]).filter(h=>!allowedIps.has(h));if(hits.length)throw Error(`${where}: найден ${what} (${hits.length}) — сборка остановлена.`);}}
privacyGate("Снимок данных",text);
for(const s of [profile.selected,...Object.values(profile.presets)])if(JSON.stringify(s).includes("apiKey"))throw Error("В снимке остался apiKey.");

/* ---- output ---- */
fs.rmSync(out,{recursive:true,force:true});
fs.mkdirSync(path.join(out,"demo","vector"),{recursive:true});fs.mkdirSync(path.join(out,"maps"),{recursive:true});
fs.writeFileSync(path.join(out,"demo","demo-data.js"),"window.NERO_DEMO_DATA="+text+";\n");
fs.copyFileSync(path.join(here,"demo-shim.js"),path.join(out,"demo","demo-shim.js"));

function patch(file,edits){let s=fs.readFileSync(path.join(cc,file),"utf8");for(const [from,to,count] of edits){const n=s.split(from).length-1;if(n!==count)throw Error(`${file}: ожидалось ${count} вхождений «${from}», найдено ${n} — панель изменилась, обновите build-share-demo.js.`);s=s.split(from).join(to);}privacyGate(file,s);return s;}
const head=['<meta charset="utf-8">','<meta charset="utf-8"><script src="demo/demo-data.js"></script><script src="demo/demo-shim.js"></script>',1];
const origin=["e.origin!==location.origin","!window.NERO_DEMO.originOk(e.origin)",1];
fs.writeFileSync(path.join(out,"NeroAI Control Center.html"),patch("index.html",[head,origin,
  ['"/designer?world=','"designer.html?world=',2],['<input id="profile" value="donko"',`<input id="profile" value="${DEMO_PROFILE}"`,1],["'/designer?embedded=1&world=","'designer.html?embedded=1&world=",1]]));
fs.writeFileSync(path.join(out,"designer.html"),patch("designer.html",[head,origin,
  ["'/map-background/'+encodeURIComponent(w.id)+'.jpg'","'maps/'+encodeURIComponent(w.id)+'.jpg'",1],
  ["if(view[2]<s*.5&&","if(window.NERO_DEMO.tiles&&view[2]<s*.5&&",1],
  ["'/map-tile/'+encodeURIComponent(w.id)+'/'+x+'/'+y+'.jpg'","'maps/'+encodeURIComponent(w.id)+'/tiles/'+x+'_'+y+'.jpg'",1],
  ["window.parent.postMessage({source:'nero-designer',...msg},location.origin)","window.parent.postMessage({source:'nero-designer',...msg},window.NERO_DEMO.target())",1]]));

for(const w of vectorWorlds){const raw=fs.readFileSync(background.vectorFile(w),"utf8");fs.writeFileSync(path.join(out,"demo","vector",w.id+".js"),"window.__neroVector("+JSON.stringify(w.id)+","+raw.trim()+");\n");}
let tileCount=0;
if(ORIGINAL)for(const [src,dst,w] of imageJobs){fs.copyFileSync(src,dst);const m=background.metadata(w);
  for(let y=0;y<m.rows;y++)for(let x=0;x<m.columns;x++){const f=background.file(w,x,y);if(!f||!fs.existsSync(f))continue;const d=path.join(out,"maps",w.id,"tiles",x+"_"+y+".jpg");fs.mkdirSync(path.dirname(d),{recursive:true});fs.copyFileSync(f,d);tileCount++;}}
else if(imageJobs.length)execFileSync("python",[path.join(here,"resize-overviews.py"),String(WIDTH),String(QUALITY),...imageJobs.flatMap(j=>j.slice(0,2))],{stdio:["ignore","ignore","inherit"],timeout:900000});

const mapsNote=ORIGINAL?`Карты в оригинальном виде, как в самой панели: ${imageJobs.length} обзорных снимков (8K),\n${tileCount} подробных спутниковых фрагментов — подгружаются при приближении,\nа меньше 8 км поверх рисуются улицы и здания из файлов карт.`:`Карты: ${imageJobs.length} обзорных снимков в уменьшенном размере (${WIDTH} px). При приближении\nменьше 8 км поверх рисуются улицы и здания из файлов карт. Подробные спутниковые\nфрагменты в облегчённую копию не включены.`;
fs.writeFileSync(path.join(out,"README_RU.txt"),"﻿"+fs.readFileSync(path.join(here,"README_RU.txt"),"utf8").replace("{{DATE}}",snapshotDate).replace("{{MAPS}}",mapsNote).replace(/\r?\n/g,"\r\n"));

const size=dir=>fs.readdirSync(dir,{withFileTypes:true}).reduce((n,e)=>n+(e.isDirectory()?size(path.join(dir,e.name)):fs.statSync(path.join(dir,e.name)).size),0);
const mb=n=>(n/1048576).toFixed(1)+" МБ";
console.log(`Папка: ${out} · ${mb(size(out))} · карт ${imageJobs.length} (${ORIGINAL?"оригинал, фрагментов "+tileCount:"уменьшены до "+WIDTH+" px"}) · векторных слоёв ${vectorWorlds.length} · пресетов запуска ${Object.keys(profile.presets).length} · пресетов карт ${Object.keys(mapPresets).length} · сценариев ${Object.keys(designs).length} · техники ${catalog.assets.length}`);
if(ZIP){const zip=path.join(outRoot,NAME+".zip");fs.rmSync(zip,{force:true});execFileSync("python",[path.join(here,"zip-dir.py"),out,zip],{stdio:"inherit",timeout:600000});console.log(`Архив: ${zip} · ${mb(fs.statSync(zip).size)}`);}
