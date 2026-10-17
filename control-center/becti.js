'use strict';
const fs=require('node:fs'),path=require('node:path'),campaign=require('./campaign-operations');
const upstream={url:'https://github.com/Kiyogitpy/becti_altis_1355.Altis',revision:'2a883f7ab7f827eea1f7e060b05bf19f4bb96959',date:'2026-04-05',license:'CC-BY-NC-SA-4.0',authors:'Benny; Zerty; HTom; Yoshi_E; Kiyogitpy'};
const source=path.resolve(__dirname,'../research/becti-latest');
function parameters(){
 const text=fs.readFileSync(path.join(source,'Rsc/Parameters.hpp'),'utf8'),xml=fs.readFileSync(path.join(source,'stringtable.xml'),'utf8'),labels=new Map();
 const decode=s=>s.replaceAll('&amp;','&').replaceAll('&lt;','<').replaceAll('&gt;','>').replaceAll('&quot;','"');
 for(const m of xml.matchAll(/<Key\s+ID="([^"]+)"[^>]*>([\s\S]*?)<\/Key>/gi)){const label=m[2].match(/<Russian>([\s\S]*?)<\/Russian>/i)||m[2].match(/<Original>([\s\S]*?)<\/Original>/i);if(label)labels.set(m[1].toUpperCase(),decode(label[1]));}
 const localize=s=>s.trim().startsWith('$')?(labels.get(s.trim().slice(1).toUpperCase())||s.trim().slice(1)):s.trim().replace(/^"|"$/g,'');
 return [...text.matchAll(/class\s+(\w+)\s*\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\};/g)].flatMap(m=>{
  const vals=m[2].match(/values\[\]\s*=\s*\{([^}]*)\}/),def=m[2].match(/default\s*=\s*(-?\d+(?:\.\d+)?)/),title=m[2].match(/title\s*=\s*([^;]+);/),texts=m[2].match(/texts\[\]\s*=\s*\{([^}]*)\}/);if(!vals||!def)return [];
  const values=vals[1].split(',').map(Number);if(values.some(v=>!Number.isFinite(v)))return [];
  return [{id:m[1],label:localize(title?.[1]||m[1]),values,labels:(texts?.[1].match(/"[^"]*"|\$\w+/g)||[]).map(localize),default:Number(def[1])}];
 });
}
function validate(value){
 if(value?.type!=='becti')throw Error('Неизвестный режим BECTI.');
 if(value.playerRole!=='commander')throw Error('BECTI использует слоты командиров сторон. Выберите роль командира.');
 const base=campaign.validate({...value,type:'frontlineCampaign'}),schema=parameters(),raw=value.bectiParameters||{},allowed=new Map(schema.map(p=>[p.id,p]));
 if(!raw||typeof raw!=='object'||Array.isArray(raw)||Object.keys(raw).some(k=>!allowed.has(k)))throw Error('Неизвестный параметр BECTI.');
 const selected=Object.fromEntries(schema.map(p=>{const v=raw[p.id]??p.default;if(!p.values.includes(v))throw Error('BECTI: недопустимое значение '+p.label);return [p.id,v];}));
 const sectors=base.sectors.map(s=>{const valueForTown=value.sectors.find(t=>t.id===s.id)?.bectiValue??150;if(!Number.isInteger(valueForTown)||valueForTown<1||valueForTown>1000)throw Error('Ценность города BECTI: от 1 до 1000.');return {...s,bectiValue:valueForTown};});
 const prices=new Map();for(const side of base.sides)for(const r of [...side.shop,...side.gear]){const key=r.class.toLowerCase();if(prices.has(key)&&prices.get(key)!==r.price)throw Error('BECTI использует общую цену класса для обеих сторон: '+r.class+'. Установите одинаковую цену.');prices.set(key,r.price);}
 return {...base,sectors,type:'becti',bectiParameters:selected,upstream};
}
function defaults(world='Altis'){const d=campaign.defaults(world);return validate({...d,type:'becti',title:'War Architect — BECTI: '+d.world,bectiParameters:{CTI_AI_TEAMS_ENABLED:3},devMode:{...d.devMode,radarNetwork:true,flamingoProfile:true,realisticMissiles:true,patriotBMD:true,coordinatedAI:true}});}
module.exports={upstream,source,parameters,validate,defaults};
