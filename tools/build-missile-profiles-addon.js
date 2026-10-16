'use strict';
// An opt-in, content-addressed config layer. Installed/Workshop files are read only.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),id=s=>{if(!/^[A-Za-z0-9_]+$/.test(s))throw Error('Invalid config identifier');return s;},q=JSON.stringify,arr=a=>'{'+a.map(q).join(',')+'}';
function orderOverrides(overrides){
 const rows=new Map(overrides.map(text=>{const m=text.match(/^class (\w+):(\w+) /);if(!m)throw Error('Invalid ammunition override');return [m[1].toLowerCase(),{text,parent:m[2].toLowerCase()}];})),visiting=new Set(),done=new Set(),ordered=[];
 function visit(name){if(done.has(name))return;if(visiting.has(name))throw Error('Cyclic ammunition inheritance: '+name);visiting.add(name);const row=rows.get(name);if(rows.has(row.parent))visit(row.parent);visiting.delete(name);done.add(name);ordered.push(row.text);}
 for(const name of rows.keys())visit(name);
 return ordered;
}
function profiles(file=path.join(root,'control-center/data/realistic-missiles.json')){
 const d=JSON.parse(fs.readFileSync(file,'utf8')),seen=new Set();if(d.version!==1||!Array.isArray(d.profiles))throw Error('Invalid missile profiles');
 for(const p of d.profiles){id(p.id);if(!['nativeCruise','nativeBallistic','aeroballistic'].includes(p.trajectory)||!Array.isArray(p.ammo)||!p.ammo.length)throw Error('Invalid missile trajectory');for(const a of p.ammo){id(a);if(seen.has(a)||/flamingo/i.test(a))throw Error('Duplicate or protected missile');seen.add(a);}for(const k of ['cruise','maximum','warheadKg','cep','signature','rangeKm'])if(!Number.isFinite(p[k])||p[k]<0||p[k]>10000)throw Error('Invalid missile '+k);if(p.maximum<p.cruise||p.maximum<100||p.maximum>4000||p.rangeKm<1||p.signature<=0||p.signature>5||p.cep>1000)throw Error('Invalid missile envelope');if(p.trajectory==='aeroballistic'&&(!Number.isFinite(p.boostSeconds)||p.boostSeconds<1||p.boostSeconds>120))throw Error('Invalid boost duration');}
 return d;
}
function prepare(modPaths){
 const d=profiles(),inventory=JSON.parse(fs.readFileSync(path.join(root,'docs/cruise-launchers-2026-10-16/inventory.json'),'utf8')),enabled=new Set(modPaths.map(p=>path.resolve(p).toLowerCase())),{decodeRap}=require('./read-world-config'),{readEntry}=require('./read-pbo-entry');
 const selected=inventory.rows.filter(r=>r.origin.mod==='Arma 3'||enabled.has(path.dirname(path.dirname(r.origin.pbo)).toLowerCase()));
 const byAmmo=new Map(selected.map(r=>[r.ammoClass,r])),required=new Set(['NeroStrategic']),overrides=[],definitions=[],proxyClasses=new Map(),parents=new Set(),cache=new Map();
 // Both original definitions and ACE compatibility must precede this patch.
 for(const p of d.profiles)for(const ammo of p.ammo){const r=byAmmo.get(ammo);if(!r)continue;
  for(const origin of r.definitions){const key=origin.pbo+'|'+origin.entry;let c=cache.get(key);if(!c){c=decodeRap(readEntry(origin.pbo,origin.entry));cache.set(key,c);}const patches=Object.entries(c.classes).find(([n])=>n.toLowerCase()==='cfgpatches')?.[1].classes||{};for(const n of Object.keys(patches))required.add(id(n));}
  parents.add(id(r.ammoParent));const missile=r.game.simulation==='shotMissile',range=p.rangeKm>=100?200000:p.rangeKm*1000;
  // Do not alter artillery initSpeed, submunition count, fuses or ACE/native artillery controllers.
  let values='NeroMS_profile='+q(p.id)+';NeroMS_wholeMap='+Number(p.rangeKm>=100)+';NeroMS_warheadKg='+p.warheadKg+';NeroMS_cep='+p.cep+';radarTarget=1;radarTargetSize='+p.signature+';';
  if(missile)values+='maxSpeed='+(p.trajectory==='nativeCruise'?p.cruise:p.maximum)+';typicalSpeed='+p.cruise+';timeToLive='+Math.max(300,Math.ceil(range/p.cruise)+60)+';missileLockMaxDistance='+range+';maxControlRange='+range+';';
  else values+='timeToLive=600;';
  if(p.trajectory==='nativeCruise')values+='thrustTime='+Math.ceil(range/p.cruise)+';';
  if(p.trajectory==='aeroballistic')values+='manualControl=1;thrust=0;thrustTime=0;maneuvrability=0;simulationStep=0.005;class ace_missileguidance {enabled=0;};';
  // TT cruise definitions explicitly have zero damage and no child warhead. Give these a conventional game effect.
  // This is a game scale anchored to TT's inherited hit=4000; kilograms are NEVER assigned to hit directly.
  if(ammo.startsWith('TT_')&&r.game.hit===0&&!r.game.submunitionammo&&p.warheadKg>0){const ratio=p.warheadKg/480;values+='hit='+Math.round(4000*ratio)+';indirectHit='+Math.round(1000*ratio)+';indirectHitRange='+Math.round(35*Math.cbrt(ratio))+';';}
  overrides.push('class '+id(ammo)+':'+id(r.ammoParent)+' {'+values+'};');
  for(const [side,parent] of [['W','NeroOP_CruiseTrack_W'],['E','NeroOP_CruiseTrack_E']]){const name='NeroMS_Track_'+side+'_'+p.id;proxyClasses.set(name,'class '+name+':'+parent+' {radarTargetSize='+p.signature+';};');}
  definitions.push('class '+id(ammo)+' {proxyWest='+q('NeroMS_Track_W_'+p.id)+';proxyEast='+q('NeroMS_Track_E_'+p.id)+';profile='+q(p.id)+';trajectory='+q(p.trajectory)+';cruise='+p.cruise+';maximum='+p.maximum+';boostSeconds='+(p.boostSeconds||0)+';cep='+p.cep+';range='+range+';};');
 }
 const overridden=new Set(overrides.map(x=>x.match(/^class (\w+)/)[1].toLowerCase()));
 const config='class CfgPatches {class NeroMissileProfiles {requiredVersion=2.18;requiredAddons[]='+arr([...required].sort())+';units[]='+arr([...proxyClasses.keys()])+';weapons[]={};};};class CfgNeroMissileProfiles {'+definitions.join('\n')+'};class CfgAmmo {'+[...parents].filter(x=>!overridden.has(x.toLowerCase())).map(x=>'class '+x+';').join('')+orderOverrides(overrides).join('\n')+'};class CfgVehicles {class NeroOP_CruiseTrack_W;class NeroOP_CruiseTrack_E;'+[...proxyClasses.values()].join('')+'};class CfgFunctions {class NeroMS {tag="NeroMS";class Flight {file="NeroMissileProfiles\\functions";class init {postInit=1;};class fired {};class kinzhal {};class curve {};};};};';
 require('./validate-mission').parseConfig(config,{rejectDuplicateDeclarations:true});
 const files=fs.readdirSync(path.join(root,'addons/NeroMissileProfiles/functions')).sort(),hash=crypto.createHash('sha256').update(config).update(JSON.stringify(d));for(const f of files)hash.update(f).update(fs.readFileSync(path.join(root,'addons/NeroMissileProfiles/functions',f)));const digest=hash.digest('hex').slice(0,12),mod=path.join(root,'dist/missile-profile-candidates','@NeroAI_Missiles_'+digest),source=path.join(mod,'source');fs.mkdirSync(path.join(source,'functions'),{recursive:true});fs.mkdirSync(path.join(mod,'addons'),{recursive:true});fs.writeFileSync(path.join(source,'config.cpp'),config);for(const f of files)fs.copyFileSync(path.join(root,'addons/NeroMissileProfiles/functions',f),path.join(source,'functions',f));fs.writeFileSync(path.join(source,'profiles.json'),JSON.stringify(d,null,2));
 return {source,mod,pbo:path.join(mod,'addons/NeroMissileProfiles.pbo'),prefix:'NeroMissileProfiles',hash:digest,classes:definitions.length,config};
}
module.exports={profiles,prepare,orderOverrides};
