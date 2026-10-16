'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const worlds=require('./scenario-design'),editor=require('./warlords-editor'),durable=require('./durable');
const sides=['WEST','EAST'],numberSide={WEST:1,EAST:0};
function catalog(){return editor.inventory().assets.filter(a=>a.kind==='PLANE'&&!a.isUav&&[0,1].includes(a.side)).map(a=>({class:a.class,label:require("./asset-names").label(a),side:a.side===1?'WEST':'EAST',faction:a.faction,mod:a.mod,modPath:a.modPath}));}
function int(n,min,max,name){if(!Number.isInteger(n)||n<min||n>max)throw Error(`${name}: от ${min} до ${max}.`);return n;}
function finite(n,min,max,name){if(typeof n!=='number'||!Number.isFinite(n)||n<min||n>max)throw Error(`${name}: от ${min} до ${max}.`);return n;}
function point(p,w,name){if(!Array.isArray(p)||p.length!==2)throw Error(`${name}: нужны X и Y.`);return p.map(n=>finite(n,3500,w.size-3500,name));}
function validate(value){
 if(value?.type==='frontlineCampaign')return require('./campaign-operations').validate(value);
 if(value?.type==='assaultDefense')return require('./ground-operations').validate(value);
 if(!value||typeof value!=='object'||Array.isArray(value)||value.version!==1||value.type!=='airBattle')throw Error('Неизвестный тип операции.');
 const w=worlds.world(value.world),x=catalog();
 if(w.size<18000)throw Error('Для воздушного сражения нужна карта размером от 18 км.');
 if(typeof value.title!=='string'||!value.title.trim()||value.title.trim().length>100||/[\x00-\x1f]/.test(value.title))throw Error('Название операции: 1–100 символов.');
 if(!['pilot','observer'].includes(value.playerRole)||!sides.includes(value.playerSide))throw Error('Выберите роль и сторону игрока.');
 if(!Array.isArray(value.sides)||value.sides.length!==2||sides.some(s=>value.sides.filter(r=>r.side===s).length!==1))throw Error('Нужны синие и красные воздушные силы.');
 const armies=sides.map(side=>{
  const a=value.sides.find(a=>a.side===side);
  if(!Array.isArray(a.classes)||!a.classes.length||a.classes.some(id=>typeof id!=='string'||!/^[A-Za-z0-9_]+$/.test(id)||!x.some(c=>c.class===id&&c.side===side)))throw Error(`Авиация ${side}: выберите классы доступных пилотируемых самолётов своей стороны.`);
  return {side,classes:[...new Set(a.classes)],active:int(a.active,2,20,'Самолётов одновременно на сторону'),reserve:int(a.reserve,0,64,'Резерв на сторону'),entry:point(a.entry,w,'Точка входа авиации'),skill:finite(a.skill,.2,1,'Уровень AI')};
 });
 if(Math.hypot(armies[0].entry[0]-armies[1].entry[0],armies[0].entry[1]-armies[1].entry[1])<8000)throw Error('Разведите точки входа сторон минимум на 8 км.');
 const v={version:1,type:'airBattle',world:w.id,title:value.title.trim(),playerRole:value.playerRole,playerSide:value.playerSide,playerClass:value.playerClass,sides:armies,
  zone:{position:point(value.zone?.position,w,'Центр воздушного боя'),radius:int(value.zone?.radius,2000,Math.min(14000,Math.floor(w.size/2)),'Радиус зоны')},
  altitude:int(value.altitude,800,5000,'Высота входа над землёй'),duration:int(value.duration,5,120,'Длительность в минутах'),scoreTarget:int(value.scoreTarget,1,84,'Цель по сбитым самолётам'),reinforcementDelay:int(value.reinforcementDelay,15,180,'Интервал подкреплений'),pilotSlots:int(value.pilotSlots,1,20,'Слотов пилотов на сторону'),hour:int(value.hour,0,23,'Час начала'),overcast:finite(value.overcast,0,.8,'Облачность'),autoAirLoadout:value.autoAirLoadout,extraMods:require('./operation-mods').validate(value.extraMods)};
 if(v.pilotSlots>Math.min(...armies.map(a=>a.active)))throw Error('Слотов пилотов не должно быть больше активных самолётов на сторону.');
 if(typeof v.autoAirLoadout!=='boolean')throw Error('Настройка воздушного вооружения должна быть включена или выключена.');
 if(!armies.find(a=>a.side===v.playerSide).classes.includes(v.playerClass))throw Error('Самолёт игрока должен входить в состав выбранной стороны.');
 if(v.scoreTarget>Math.min(...armies.map(a=>a.active+a.reserve)))throw Error('Цель по сбитым самолётам превышает полный запас одной из сторон.');
 return v;
}
function defaults(world='Australia'){
 const w=worlds.world(world),x=catalog(),choose=(side,preferred)=>preferred.find(id=>x.some(a=>a.class===id&&a.side===side))||x.find(a=>a.side===side)?.class;
 const west=choose('WEST',['F16C_BLU','CUP_B_F35B_USMC']),east=choose('EAST',['JS_JC_SU35','CUP_O_SU34_RU']);
 return validate({version:1,type:'airBattle',world:w.id,title:'NeroAI — Australia: воздушное сражение',playerRole:'pilot',playerSide:'WEST',playerClass:west,
  sides:[{side:'WEST',classes:[west],active:12,reserve:24,entry:[Math.round(w.size*.28),Math.round(w.size*.62)],skill:.7},{side:'EAST',classes:[east],active:12,reserve:24,entry:[Math.round(w.size*.72),Math.round(w.size*.38)],skill:.7}],
  zone:{position:[Math.round(w.size/2),Math.round(w.size/2)],radius:6000},altitude:1800,duration:40,scoreTarget:24,reinforcementDelay:45,pilotSlots:2,hour:9,overcast:.15,autoAirLoadout:true});
}
function modPaths(v){v=validate(v);const x=editor.inventory(),wanted=new Set([worlds.world(v.world).modPath,...(v.extraMods||[]).filter(p=>{try{return fs.statSync(p).isDirectory();}catch{return false;}})]);
 for(const r of require('./operation-required-mods').resolve(v,x))if(!r.generated)wanted.add(r.id);
 const ace=x.mods.find(m=>m.name==='@ace'&&m.patches.includes('ace_main'))||x.mods.find(m=>m.patches.includes('ace_main')),cba=x.mods.find(m=>m.patches.includes('cba_main'));
 if(!ace||!cba)throw Error('Для операций нужны установленные ACE и CBA A3.');wanted.add(ace.path);wanted.add(cba.path);
 if(v.type==='frontlineCampaign'){for(const name of ['@FP-5 -Flamingo-','@RHSAFRF']){const m=x.mods.find(m=>m.name===name);if(!m)throw Error('Не установлен обязательный мод спецоружия: '+name);wanted.add(m.path);}wanted.add(require('node:path').resolve(__dirname,'../dist/strategic-compat/@NeroAI_Strategic'));}
 for(const side of v.sides)for(const id of [...side.classes,...(side.truckClass?[side.truckClass]:[]),...(side.shop||[]).map(r=>r.class)])wanted.add((x.assets.find(a=>a.class===id&&a.side===numberSide[side.side])||(v.type==='frontlineCampaign'?[...require('./campaign-equipment').assets(),...require('./campaign-equipment').infantryCatalog()].find(a=>a.class===id):null))?.modPath);
 if(v.type==='frontlineCampaign'){const gear=require('./campaign-equipment').gearCatalog();for(const side of v.sides)for(const row of side.gear||[])wanted.add(gear.find(g=>g.class===row.class&&g.kind===row.kind)?.modPath);}
 // The ACE inventory includes optional compatibility packages. Its installed
 // ace_main requires cba_main; optional integrations must not pull every mod.
 let changed=true;while(changed){changed=false;for(const m of x.mods.filter(m=>wanted.has(m.path)&&m.path!==ace.path))for(const name of m.requires||[]){const dep=x.mods.find(m=>m.patches.some(p=>p.toLowerCase()===name.toLowerCase()));if(dep&&!wanted.has(dep.path)){wanted.add(dep.path);changed=true;}}}
 return [...wanted].filter(Boolean);
}
function createStore(dir=path.join(__dirname,'data','operations')){
 const file=id=>{if(typeof id!=='string'||!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(id))throw Error('Некорректный ID операции.');return path.join(dir,id+'.json');};
 const get=id=>{const f=file(id);if(!fs.existsSync(f))throw Error('Операция не найдена.');return JSON.parse(fs.readFileSync(f,'utf8'));};
 const records=()=>fs.existsSync(dir)?fs.readdirSync(dir).filter(f=>/^[0-9a-f-]{36}\.json$/.test(f)).map(f=>get(f.slice(0,-5))):[];
 const list=()=>records().map(r=>({id:r.id,title:r.design.title,world:r.design.world,type:r.design.type,revision:r.revision,updatedAt:r.updatedAt,active:r.design.sides.reduce((n,a)=>n+a.active,0),role:r.design.playerRole})).sort((a,b)=>b.updatedAt.localeCompare(a.updatedAt));
 function save(value){let design=validate(value.design);const old=value.id?get(value.id):null;if(old&&old.revision!==value.revision)throw Error('Операция изменена в другом окне. Откройте её заново; ваш черновик сохранён в этом окне.');
  if(!old&&design.type==='frontlineCampaign'&&records().some(r=>r.design.type==='frontlineCampaign'&&r.design.campaignKey===design.campaignKey))design={...design,campaignKey:crypto.randomUUID()};
  const now=new Date().toISOString();return {...durable.write(file(old?.id||value.newId||crypto.randomUUID()),{version:1,id:old?.id||value.newId||null,design,revision:(old?.revision||0)+1,createdAt:old?.createdAt||now,updatedAt:now}),verified:true};
 }
 // Generate one ID before the durable write so filename and record always agree.
 const saveRecord=value=>{const id=value.id||crypto.randomUUID();return save({...value,newId:id});};
 return {get,list,save:saveRecord};
}
module.exports={validate,defaults,catalog,modPaths,createStore,...createStore()};
