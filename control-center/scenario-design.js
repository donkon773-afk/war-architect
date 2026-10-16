"use strict";
const fs=require('node:fs'),path=require('node:path'),editor=require('./warlords-editor');
const dir=path.join(__dirname,'data/designs');
const sides=['WEST','EAST','GUER'];
function worlds(){const f=path.join(__dirname,'../dist/worlds.json');return fs.existsSync(f)?JSON.parse(fs.readFileSync(f,'utf8')).worlds:[];}
function world(id){const w=worlds().find(w=>w.id===id);if(!w)throw new Error('Карта не найдена среди установленных.');return w;}
function text(s,max){if(typeof s!=='string'||s.length>max||/[\u0000-\u0008]/.test(s))throw new Error('Некорректный текст настройки.');return s.trim();}
function integer(n,min,max){if(!Number.isInteger(n)||n<min||n>max)throw new Error(`Число должно быть от ${min} до ${max}.`);return n;}
function validate(value,nodes=[],options={}){
 const draft=options.draft===true,validClass=id=>typeof id==='string'&&id.length<=128&&/^[A-Za-z0-9_]+$/.test(id);
 const resourceCount=(n,name)=>{if(!Number.isSafeInteger(n)||n<1)throw Error(name+': укажите целое число не меньше 1.');return n;};
 const w=world(value.world),x=editor.inventory(),v=structuredClone(value);
 if(!['native','three'].includes(v.mode)||!['invader','defender'].includes(v.greenRole)||!sides.includes(v.playerSide)||typeof v.lethalZones!=='boolean')throw new Error('Некорректный режим сторон.');
 if(v.army){v.army=draft?editor.validateDraft(v.army):editor.validate(v.army);v.greenFaction=v.army.greenFaction;}
 v.title=text(v.title,100);v.playerRole=v.playerRole??"commander";if(!["commander","observer"].includes(v.playerRole))throw Error("Неизвестная роль игрока.");
 if(!draft&&v.mode==='native'&&v.playerSide==='GUER'&&v.playerRole!=='observer')throw new Error('Игра за зелёных требует трёхстороннего режима.');
 for(const list of ['bases','sectors','spawns']){
  if(!Array.isArray(v[list]))throw new Error('Некорректный список точек.');
  const ids=new Set();for(const p of v[list]){if(typeof p.id!=='string'||!/^[a-zA-Z0-9_-]{1,60}$/.test(p.id)||ids.has(p.id))throw new Error('ID точки должен быть уникальным.');ids.add(p.id);delete p.type;p.name=text(p.name,80);if(!sides.includes(p.side))throw new Error('Сторона точки неизвестна.');if(!Array.isArray(p.position)||p.position.length!==2||p.position.some(n=>!Number.isFinite(n)||n<0||n>w.size))throw new Error('Точка за пределами карты.');p.radius=integer(p.radius,30,1500);if(list==='sectors'){
   p.infantry=integer(p.infantry,0,60);p.vehicles=integer(p.vehicles,0,8);p.vehicleClasses=p.vehicleClasses||[];
   const side={WEST:1,EAST:0,GUER:2}[p.side];if(!Array.isArray(p.vehicleClasses)||p.vehicleClasses.some(id=>!validClass(id)||(!draft&&!x.assets.some(a=>a.class===id&&a.side===side&&['CAR','APC','TANK','STATIC'].includes(a.kind)))))throw new Error('Гарнизон: выберите наземную технику нужной стороны.');
  }}
 }
 const required=v.mode==='three'?sides:['WEST','EAST'];for(const side of required)if(!draft&&v.bases.filter(p=>p.side===side).length!==1)throw new Error(`Нужна одна главная база ${({WEST:'синих',EAST:'красных',GUER:'зелёных'})[side]} (${side}) — поставьте её инструментом «＋ База».`);
 if(!draft&&v.bases.length!==required.length)throw new Error('Количество главных баз должно совпадать с количеством сторон.');
 const pointIds=v.bases.concat(v.sectors,v.spawns).map(p=>p.id);if(new Set(pointIds).size!==pointIds.length)throw new Error('ID всех точек должны различаться.');
 v.maxNPCs=resourceCount(v.maxNPCs??160,'Общий лимит NPC');v.maxVehicles=resourceCount(v.maxVehicles??32,'Общий лимит техники');
 v.startCP=integer(v.startCP??6000,0,50000);v.income=integer(v.income??100,0,1000);
 v.greenFaction=text(v.greenFaction||'rhsgref_faction_cdf_ng',100);if(!validClass(v.greenFaction)||(!draft&&!x.assets.some(a=>a.kind==='INFANTRY'&&a.side===2&&a.faction===v.greenFaction)))throw new Error('Выберите установленную фракцию зелёной стороны.');
 if(!draft&&v.sectors.length<1)throw new Error('Добавьте хотя бы одну цель захвата.');
 v.startAssets=v.startAssets||[];if(!Array.isArray(v.startAssets))throw new Error('Некорректный список стартовой техники.');
 for(const a of v.startAssets){if(!sides.includes(a.side))throw new Error('Стартовая сторона неизвестна.');const n={WEST:1,EAST:0,GUER:2}[a.side];if(!validClass(a.class)||(!draft&&!x.assets.some(x=>x.class===a.class&&x.side===n&&x.kind!=='INFANTRY')))throw new Error('Стартовый класс недоступен этой стороне.');a.count=integer(a.count,1,5);}
 if(!draft&&v.startAssets.reduce((n,a)=>n+a.count,0)>v.maxVehicles)throw new Error('Стартовая техника превышает общий лимит машин.');
 if(!draft&&v.mode==='native'&&v.startAssets.some(a=>a.side==='GUER'))throw new Error('Для стартовой техники зелёных нужна третья главная база.');
 const g=v.garrisonLLM||{enabled:false,route:'shared',instructions:'',limit:4};if(typeof g.enabled!=='boolean'||!['shared','separate'].includes(g.route))throw new Error('Некорректное подключение гарнизонов.');g.instructions=text(g.instructions||'',2000);g.limit=integer(g.limit??4,1,8);if(!draft&&g.enabled&&g.route==='separate'&&(!nodes.some(n=>n.id===g.node)||!text(g.model||'',200)))throw new Error('Выберите узел и модель гарнизонов.');v.garrisonLLM=g;
 return v;
}
function blank(id){const w=world(id),size=w.size;return {version:1,world:id,title:'NeroAI — '+w.label,mode:'native',greenRole:'defender',playerSide:'WEST',lethalZones:false,bases:[{id:'west',name:'База синих',side:'WEST',position:[size*.2,size*.8],radius:200},{id:'east',name:'База красных',side:'EAST',position:[size*.8,size*.2],radius:200}],sectors:[],spawns:[],startAssets:[],garrisonLLM:{enabled:false,route:'shared',instructions:'',limit:4}};}
function load(id){world(id);const f=path.join(dir,id+'.json');return fs.existsSync(f)?JSON.parse(fs.readFileSync(f,'utf8')):blank(id);}
/* 8.10: durable write + read-back check; expectedSavedAt (from the page that
 * loaded the design) refuses to overwrite a newer save made in another window. */
function save(v,nodes,expectedSavedAt){v=validate(v,nodes,{draft:true});const f=path.join(dir,v.world+'.json');
 if(expectedSavedAt!==undefined&&fs.existsSync(f)){const onDisk=JSON.parse(fs.readFileSync(f,'utf8')).savedAt||'';if(onDisk!==(expectedSavedAt||''))throw new Error('Карта уже сохранена в другом окне. Обновите редактор, чтобы не перезаписать более новые изменения.');}
 v.savedAt=new Date().toISOString();return require('./durable').write(f,v);}
module.exports={worlds,world,validate,blank,load,save};
