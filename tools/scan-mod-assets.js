"use strict";
const fs=require('node:fs'),path=require('node:path');
const {readEntry}=require('./read-pbo-entry'),{decodeRap}=require('./read-world-config');
const root=path.resolve(__dirname,'..'),launch=JSON.parse(fs.readFileSync(path.join(__dirname,'warlords-launch.json'),'utf8').replace(/^\uFEFF/,''));
const workshop=path.join(launch.armaRoot,'!Workshop');
const wanted=/^@(CUP (Vehicles|Units)|RHSUSAF|RHSAFRF|RHSGREF|RHSSAF|Hellenic|3CB BAF|TMT|QAV|TT (Merkava|Leopard)|T80BVM|T-80BVM|SU-35|FA-18|JCA - Land)/i;
function scan(){
 const classes=new Map(),patches=new Map(),mods=[],errors=[];
 const vanilla=path.join(launch.armaRoot,'Addons');
 for(const name of ['characters_f.pbo','characters_f_beta.pbo','characters_f_gamma.pbo','air_f.pbo','air_f_beta.pbo','air_f_gamma.pbo','air_f_epb.pbo','air_f_epc.pbo','soft_f.pbo','soft_f_beta.pbo','soft_f_gamma.pbo','armor_f.pbo','armor_f_beta.pbo','armor_f_gamma.pbo','boat_f.pbo','boat_f_beta.pbo','boat_f_gamma.pbo','static_f.pbo','static_f_beta.pbo','static_f_gamma.pbo','weapons_f.pbo']){
  const c=decodeRap(readEntry(path.join(vanilla,name),'config.bin'));
  for(const [id,node] of Object.entries(c.classes.CfgVehicles?.classes||{}))classes.set(id.toLowerCase(),{id,parent:node.parent,values:node.values,mod:'Arma 3',modPath:''});
 }
 for(const dir of fs.readdirSync(workshop,{withFileTypes:true}).filter(d=>d.name.startsWith('@')&&fs.statSync(path.join(workshop,d.name)).isDirectory())){
  const modPath=path.join(workshop,dir.name),addonDir=path.join(modPath,'addons');if(!fs.existsSync(addonDir))continue;
  const mod={name:dir.name,path:modPath,patches:[],requires:[]};mods.push(mod);
  for(const pbo of fs.readdirSync(addonDir).filter(n=>n.toLowerCase().endsWith('.pbo'))){
   try{
    const c=decodeRap(readEntry(path.join(addonDir,pbo),'config.bin'));
    for(const [id,node] of Object.entries(c.classes.CfgPatches?.classes||{})){patches.set(id,modPath);mod.patches.push(id);mod.requires.push(...(node.values.requiredAddons||[]));}
    for(const [id,node] of Object.entries(c.classes.CfgVehicles?.classes||{})){
     const key=id.toLowerCase(),old=classes.get(key);classes.set(key,{id,parent:node.parent||old?.parent||'',values:{...old?.values,...node.values},mod:old?.modPath&&!Object.hasOwn(node.values,'scope')&&!Object.hasOwn(node.values,'displayName')?old.mod:dir.name,modPath:old?.modPath&&!Object.hasOwn(node.values,'scope')&&!Object.hasOwn(node.values,'displayName')?old.modPath:modPath});
    }
   }catch(e){if(!/Entry missing/.test(e.message))errors.push({mod:dir.name,pbo,error:e.message});}
  }
 }
 function value(c,k,visited=new Set()){if(!c||visited.has(c.id.toLowerCase()))return undefined;visited.add(c.id.toLowerCase());return c.values[k]??value(classes.get(c.parent.toLowerCase()),k,visited);}
 function ancestor(c,name,seen=new Set()){if(!c||seen.has(c.id.toLowerCase()))return false;seen.add(c.id.toLowerCase());return c.id.toLowerCase()===name.toLowerCase()||c.parent.toLowerCase()===name.toLowerCase()||ancestor(classes.get(c.parent.toLowerCase()),name,seen);}
 function kind(c){const sim=String(value(c,'simulation')||'').toLowerCase();if(ancestor(c,'Man'))return 'INFANTRY';if(ancestor(c,'Plane')||sim.includes('airplane'))return 'PLANE';if(ancestor(c,'Helicopter')||sim.includes('helicopter'))return 'HELICOPTER';if(ancestor(c,'StaticWeapon'))return 'STATIC';if(sim.includes('tank'))return /merkava|m1a|m1_|t_?72|t_?80|t_?90|t_?14|leopard|challenger/i.test(c.id)?'TANK':Number(value(c,'transportSoldier'))>=4||/bmp|bmd|bradley|m2a|m3a|warrior|fv510|mtlb/i.test(c.id)?'APC':'TANK';if(ancestor(c,'Ship')||sim.includes('ship'))return 'SHIP';if(ancestor(c,'StaticWeapon')||/static|weapon/.test(sim)&&ancestor(c,'AllVehicles')&&!ancestor(c,'Man'))return 'STATIC';if(ancestor(c,'LandVehicle')&&sim.includes('car'))return Number(value(c,'transportSoldier'))>5?'APC':'CAR';return '';}
 const assets=[];
 for(const c of classes.values()){
  const scope=value(c,'scope'),side=value(c,'side'),k=kind(c);if(scope!==2||!k||![0,1,2].includes(side))continue;
  assets.push({class:c.id,label:String(value(c,'displayName')||c.id),kind:k,side,faction:String(value(c,'faction')||''),cargo:Number(value(c,'transportSoldier'))||0,isUav:Number(value(c,'isUav'))===1,mod:c.mod,modPath:c.modPath});
 }
 const factions=[...new Set(assets.filter(a=>a.kind==='INFANTRY').map(a=>a.faction).filter(Boolean))].sort();
 const result={version:1,scannedAt:new Date().toISOString(),evidence:'installed_config_not_engine',assets:assets.sort((a,b)=>a.mod.localeCompare(b.mod)||a.class.localeCompare(b.class)),factions,mods:mods.map(m=>({...m,patches:[...new Set(m.patches)],requires:[...new Set(m.requires)]})),errors};
 fs.mkdirSync(path.join(root,'dist'),{recursive:true});fs.writeFileSync(path.join(root,'dist','mod-assets.json'),JSON.stringify(result,null,2));
 console.log(JSON.stringify({mods:mods.length,assets:assets.length,factions:factions.length,errors:errors.length}));return result;
}
if(require.main===module)scan();module.exports={scan};
