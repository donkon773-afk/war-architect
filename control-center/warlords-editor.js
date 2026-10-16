"use strict";
const fs=require('node:fs'),path=require('node:path');
const assetNames=require('./asset-names');
const root=path.resolve(__dirname,'..'),file=path.join(root,'dist','mod-assets.json');
const curated=[
 ['CUP_B_F35B_USMC','F-35B',8500,'JET_FIGHTER'],['F4E_BLU','F-4E Phantom II (HAFM)',7000,'JET_CAS'],['F16C_BLU','F-16C (HAFM)',8000,'JET_FIGHTER'],['F16_B52_BLU','F-16D Block 52+ (HAFM)',8500,'JET_CAS'],
 ['CUP_O_SU34_RU','Су-34',7500,'JET_CAS'],['JS_JC_SU35','Су-35',8500,'JET_FIGHTER'],
 ['rhs_t80bv','Т-80БВ',3500,'ARMOR'],['rhs_t72bd_tv','Т-72Б3',4200,'ARMOR'],['CUP_O_T90M_RU','Т-90М',5200,'ARMOR'],['rhs_t14_tv','Т-14',6500,'ARMOR'],
 ['rhsusf_m1a2sep1wd_usarmy','M1A2 SEP v1',4300,'ARMOR'],['rhsusf_m1a2sep2wd_usarmy','M1A2 SEP v2',4800,'ARMOR'],['CUP_B_M1A2C_TUSK_II_Woodland_US_Army','M1A2 SEP v3 TUSK II',5500,'ARMOR'],
 ['TT_Merkava_Mk4M','Merkava Mk.4M (TT)',5200,'ARMOR'],['CUP_B_Challenger2_Woodland_BAF','Challenger 2',4600,'ARMOR'],['CUP_B_Leopard_1A3_GER','Leopard 1A3',3200,'ARMOR'],['CUP_B_Leopard2A6_GER','Leopard 2A6',4800,'ARMOR'],['CUP_B_FV510_GB_W','Warrior',2500,'MECHANIZED'],
 ['RHS_CH_47F','CH-47F — транспорт',4200,'AIR_TRANSPORT'],['CUP_O_Mi8AMT_RU','Ми-8АМТ — транспорт',3200,'AIR_TRANSPORT'],['RHS_UH60M','UH-60M — транспорт',3200,'AIR_TRANSPORT'],['rhs_mi8mt_vdv','Ми-8 — транспорт',3000,'AIR_TRANSPORT'],['RHS_AH64D','AH-64D',5500,'AIR_CAS'],['rhs_mi24v_vdv','Ми-24В',4500,'AIR_CAS'],['rhs_mi28n_vvs','Ми-28Н',5500,'AIR_CAS'],
 ['CUP_B_LAV25_USMC','LAV-25',2200,'MECHANIZED'],['rhs_bmp2_msv','БМП-2',2200,'MECHANIZED'],['rhs_btr80a_msv','БТР-80А',1800,'MECHANIZED'],['rhs_zsu234_aa','ЗСУ-23-4',2700,'AIR_DEFENCE']
];
let cached,cacheStamp;
function inventory(){const stamp=fs.statSync(file).mtimeMs;if(cached&&cacheStamp===stamp)return cached;cacheStamp=stamp;const x=JSON.parse(fs.readFileSync(file,'utf8'));const alias=new Map(curated.map(r=>[r[0].toLowerCase(),r]));return cached={...x,assets:x.assets.map(a=>{const r=alias.get(a.class.toLowerCase());return {...a,label:assetNames.label(a,r?.[1]),price:r?.[2]||({INFANTRY:100,TANK:4000,APC:2200,CAR:800,SHIP:2500,STATIC:800,HELICOPTER:4000,PLANE:8000}[a.kind]||1000),role:r?.[3]||(/HELICOPTER/.test(a.kind)?a.cargo>=8?'AIR_TRANSPORT':'AIR_CAS':a.kind==='PLANE'?'JET_CAS':a.kind==='TANK'?'ARMOR':'MECHANIZED')};})};}
function defaults(){const x=inventory(),map=new Map(x.assets.map(a=>[a.class.toLowerCase(),a]));const ids=curated.map(r=>map.get(r[0].toLowerCase())).filter(Boolean);return {westFaction:'rhs_faction_usarmy_d',eastFaction:'rhs_faction_msv',westAssets:ids.filter(a=>a.side===1).map(a=>a.class),eastAssets:ids.filter(a=>a.side===0).map(a=>a.class),greenFaction:'rhsgref_faction_cdf_ng',greenAssets:ids.filter(a=>a.side===2).map(a=>a.class)};}
function validate(value,options={}){const catalog=options.catalog!==false,validClass=id=>typeof id==='string'&&id.length<=128&&/^[A-Za-z0-9_]+$/.test(id),x=inventory(),v={...defaults(),...value};for(const [prefix,side] of [['west',1],['east',0],['green',2]]){
 if(!validClass(v[prefix+'Faction'])||(catalog&&!x.assets.some(a=>a.kind==='INFANTRY'&&a.side===side&&a.faction===v[prefix+'Faction'])))throw new Error('Выберите установленную фракцию своей стороны.');
 const ids=v[prefix+'Assets'];if(!Array.isArray(ids)||ids.some(id=>!validClass(id)||(catalog&&!x.assets.some(a=>a.class===id&&a.side===side&&a.kind!=='INFANTRY'))))throw new Error('Каталог содержит недоступный класс или неверную сторону.');v[prefix+'Assets']=[...new Set(ids)];
 }
 for(const [prefix,side] of [['west',1],['east',0],['green',2]]){
  const key=prefix+'Infantry',costKey=prefix+'InfantryCosts',ids=v[key]??null,costs=v[costKey]??{};
  const valid=id=>validClass(id)&&(!catalog||x.assets.some(a=>a.class===id&&a.side===side&&a.kind==='INFANTRY'));
  // An explicit empty list means the player cleared the infantry catalog.
  if(ids!==null&&(!Array.isArray(ids)||ids.some(id=>!valid(id))))throw new Error('Покупка пехоты: выберите доступных бойцов своей стороны.');
  if(!costs||typeof costs!=='object'||Array.isArray(costs)||Object.entries(costs).some(([id,cost])=>!valid(id)||!Number.isInteger(cost)||cost<60||cost>50000))throw new Error('Цена пехоты должна быть целым числом от 60 до 50000 CP для доступного бойца своей стороны.');
  v[key]=ids===null?null:[...new Set(ids)];v[costKey]={...costs};
 }return v;}
function infantry(army,prefix,faction){
 const side={west:1,east:0,green:2}[prefix],assets=inventory().assets,ids=army[prefix+'Infantry'];
 const list=Array.isArray(ids)?ids.map(id=>assets.find(a=>a.class===id&&a.kind==='INFANTRY'&&a.side===side)):
 assets.filter(a=>a.kind==='INFANTRY'&&a.side===side&&a.faction===(faction||army[prefix+'Faction'])&&!/pilot|crew|officer|unarmed|diver/i.test(a.class)).sort((a,b)=>Number(/_arb_|_desert|_winter/i.test(a.class))-Number(/_arb_|_desert|_winter/i.test(b.class))||a.class.localeCompare(b.class)).slice(0,12);
 if(list.some(a=>!a))throw new Error('Недоступный класс пехоты.');
 return list.map(a=>({...a,price:army[prefix+'InfantryCosts']?.[a.class]??100}));
}
function commander(army,prefix){
 const side={west:1,east:0,green:2}[prefix],all=inventory().assets.filter(a=>a.kind==='INFANTRY'&&a.side===side&&a.faction===army[prefix+'Faction']);
 const ids=army[prefix+'Infantry'],selected=Array.isArray(ids)?all.filter(a=>ids.includes(a.class)):[];
 const list=selected.length?selected:all;
 return (list.find(a=>['rhsusf_army_ocp_squadleader','rhs_msv_emr_sergeant'].includes(a.class))||list.find(a=>/squadleader|sergeant|squad_leader|teamchief|teamleader|elementleader|commander|_sl$|_tl$/i.test(a.class))||list.find(a=>/rifleman/i.test(a.class))||list[0]).class;
}
function preset(army,prefixes=['west','east']){army=validate(army);const x=inventory();const sides=prefixes.map(prefix=>{
 const inf=infantry(army,prefix);
 const selected=army[prefix+'Assets'].map(id=>x.assets.find(a=>a.class===id));
 const row=(a,cost)=>{if(!/^[A-Za-z0-9_]+$/.test(a.class))throw new Error("Invalid config class");return `class ${a.class} { cost=${cost}; NeroWL_role="${a.role}"; requirements[]={${a.kind==='PLANE'?'"A"':a.kind==='HELICOPTER'?'"H"':a.kind==='SHIP'?'"W"':''}}; };`;};
 return `class ${prefix==='green'?'GUER':prefix.toUpperCase()} { class Infantry { ${inf.map(a=>row(a,a.price)).join('\n')} }; class Vehicles { ${selected.filter(a=>!['PLANE','HELICOPTER','SHIP','STATIC'].includes(a.kind)).map(a=>row(a,a.price)).join('\n')} }; class Aircraft { ${selected.filter(a=>['PLANE','HELICOPTER'].includes(a.kind)).map(a=>row(a,a.price)).join('\n')} }; class Defences { ${selected.filter(a=>a.kind==='STATIC').map(a=>row(a,a.price)).join("\n")} }; class Naval { ${selected.filter(a=>a.kind==='SHIP').map(a=>row(a,a.price)).join("\n")} }; };`;
 });return 'class CfgWLRequisitionPresets { class NeroWL_RHSStart { '+sides.join('\n')+' }; };\n';}
function mods(army){army=validate(army);const x=inventory(),infantryIds=new Set(['west','east','green'].flatMap(p=>army[p+'Infantry']||[])),selected=x.assets.filter(a=>army.westAssets.includes(a.class)||army.eastAssets.includes(a.class)||army.greenAssets.includes(a.class)||infantryIds.has(a.class)||[army.westFaction,army.eastFaction,army.greenFaction].includes(a.faction)&&a.kind==='INFANTRY');const paths=new Set(selected.map(a=>a.modPath).filter(Boolean));let changed=true;while(changed){changed=false;for(const m of x.mods.filter(m=>paths.has(m.path)))for(const req of m.requires){const dep=x.mods.find(d=>d.patches.some(p=>p.toLowerCase()===req.toLowerCase()));if(dep&&!paths.has(dep.path)){paths.add(dep.path);changed=true;}}}return [...paths];}
module.exports={inventory,defaults,validate,validateDraft:value=>validate(value,{catalog:false}),commander,preset,mods,infantry};
