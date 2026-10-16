"use strict";
const fs=require('node:fs'),path=require('node:path'),{readEntry,indexEntries}=require('./read-pbo-entry'),{decodeRap}=require('./read-world-config');
const root=path.resolve(__dirname,'..');
function scan(){
 const launch=JSON.parse(fs.readFileSync(path.join(root,'tools/warlords-launch.json'),'utf8').replace(/^\uFEFF/,'')),mods=require('../dist/mod-assets.json').mods;
 const game=launch.armaRoot,dirs=[{dir:path.join(game,'Addons'),mod:'Arma 3',modPath:''},...fs.readdirSync(game,{withFileTypes:true}).filter(d=>d.isDirectory()&&fs.existsSync(path.join(game,d.name,'addons'))).map(d=>({dir:path.join(game,d.name,'addons'),mod:d.name,modPath:''})),...mods.map(m=>({dir:path.join(m.path,'addons'),mod:m.name,modPath:m.path}))];
 const worlds=new Map(),wrps=new Set(),terrainSizes=new Map();
 for(const source of dirs){if(!fs.existsSync(source.dir))continue;for(const f of fs.readdirSync(source.dir).filter(f=>f.endsWith('.pbo'))){
  try{for(const e of indexEntries(path.join(source.dir,f)))if(/\.wrp$/i.test(e.name)){wrps.add(e.virtual);if(e.size>100000){let fd;try{fd=fs.openSync(path.join(source.dir,f),'r');const h=require('./extract-map-background').prefix(fd,e);if(h.toString('ascii',0,4)==='OPRW'&&h.readUInt32LE(4)===25){const n=h.readUInt32LE(12)*h.readFloatLE(28);if(Number.isFinite(n)&&n>=1000&&n<=100000)terrainSizes.set(e.virtual,n);}}catch(error){}finally{if(fd!==undefined)fs.closeSync(fd);}}}const cfg=decodeRap(readEntry(path.join(source.dir,f),'config.bin'));for(const [id,n] of Object.entries(cfg.classes.CfgWorlds?.classes||{})){
   const old=worlds.get(id.toLowerCase());if(!n.values.worldName&&!old)continue;
   worlds.set(id.toLowerCase(),{...old,id,parent:n.parent,values:{...old?.values,...n.values},classes:{...old?.classes,...n.classes},mod:old?.mod||source.mod,modPath:old?.modPath??source.modPath,sourcePbo:old?.sourcePbo||path.join(source.dir,f)});
  }}catch(e){}
 }}
 const list=[];for(const w of worlds.values()){
  const v=w.values,size=Number(v.worldSize||v.mapSize);if(!/^[A-Za-z0-9_]{1,80}$/.test(w.id)||!/\.wrp$/i.test(v.worldName||'')||!Number.isFinite(size)||size<1000||!wrps.has(v.worldName.replaceAll('\\','/').replace(/^\/+/,'').toLowerCase()))continue;
  const title=require("../control-center/asset-names").label({label:String(v.description||w.id),class:w.id}),id=({altis:'Altis',takistan:'Takistan',chernarus:'Chernarus',australia:'Australia'})[w.id.toLowerCase()]||w.id;
  list.push({id,world:w.id,label:title,mod:w.mod,modPath:w.modPath,size,preview:v.pictureMap||'',sourcePbo:w.sourcePbo,locations:Object.values(w.classes.Names?.classes||{}).map(n=>({name:require('../control-center/asset-names').label({label:String(n.values.name||''),class:n.values.name||''}),position:n.values.position,type:n.values.type})).filter(n=>n.name&&Array.isArray(n.position)),airports:[v,...Object.values(w.classes.SecondaryAirports?.classes||{}).map(n=>n.values)].map((v,i)=>({id:i,position:v.ilsPosition,direction:v.ilsDirection})).filter(v=>Array.isArray(v.position))});
 }
 // Australia's legacy text/include configuration isn't RAP. Preserve the
 // known installed scenario's coordinates, clearly without inventing imagery.
 if(!list.some(w=>w.id==='Australia')){const mod=mods.find(m=>m.name==='@Australia FIXED')||mods.find(m=>m.name==='@@Australia');if(mod)list.push({id:'Australia',world:'australia',label:'Australia',mod:mod.name,modPath:mod.path,size:40960,preview:'',locations:require('./australia-layout').places.map(p=>({name:p.name,position:[p.position[0],p.position[2]]})),airports:[],metadataFallback:true});}
 for(const [id,name] of [['Takistan','takistan'],['Chernarus','chernarus']])if(!list.some(w=>w.id===id)){const file=path.join(root,'research/worlds',name,'metadata.json'),mod=mods.find(m=>m.name==='@CUP Terrains - Maps');if(mod&&fs.existsSync(file)){const m=JSON.parse(fs.readFileSync(file,'utf8'));list.push({id,world:name,label:id,mod:mod.name,modPath:mod.path,size:terrainSizes.get('ca/'+name+'/'+name+'.wrp')||m.size,preview:'',locations:m.locations.map(n=>({name:n.name||n.id,position:n.position,type:n.type})),airports:m.airports||[],metadataFallback:true});}}
 for(const w of list){const key=[...terrainSizes.keys()].find(k=>k.endsWith('/'+w.world.toLowerCase()+'.wrp'));if(key){w.size=terrainSizes.get(key);w.sizeSource='WRP header';}}
 list.sort((a,b)=>a.label.localeCompare(b.label,'ru'));fs.writeFileSync(path.join(root,'dist/worlds.json'),JSON.stringify({scannedAt:new Date().toISOString(),worlds:list},null,2));console.log(JSON.stringify({worlds:list.length}));return list;
}
if(require.main===module)scan();module.exports={scan};
