'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),schema=require('./scenario-design'),durable=require('./durable');
/* 8.10: a saved preset is guaranteed on disk — temp file, fsync, rename, read-back
 * comparison (durable.write). Presets can be updated in place (revision guards
 * against an older window overwriting newer work), renamed and deleted into a
 * recoverable bin. "In game" = the world's current design equals the preset. */
const meta=d=>{const c=structuredClone(d||{});delete c.savedAt;return c;};
function createStore(dir=path.join(__dirname,'data/map-presets'),designs=schema){
 function file(id){if(typeof id!=='string'||! /^[0-9a-f-]{36}$/.test(id))throw Error('Некорректный ID пресета карты.');return path.join(dir,id+'.json');}
 function get(id){const f=file(id);if(!fs.existsSync(f))throw Error('Пресет карты не найден — возможно, он удалён в другом окне. Обновите список.');return JSON.parse(fs.readFileSync(f,'utf8'));}
 function inGame(p){try{return durable.hash(meta(designs.load(p.design.world)))===durable.hash(meta(p.design));}catch{return false;}}
 function summary(p){return {id:p.id,name:p.name,world:p.design.world,title:p.design.title,createdAt:p.createdAt||p.updatedAt,updatedAt:p.updatedAt,revision:p.revision||1,hash:durable.hash(meta(p.design)),inGame:inGame(p),sectors:p.design.sectors.length,bases:p.design.bases.length,spawns:p.design.spawns.length,mode:p.design.mode,playerRole:p.design.playerRole||'commander'};}
 function all(){return fs.existsSync(dir)?fs.readdirSync(dir).filter(n=>/^[0-9a-f-]{36}\.json$/.test(n)).map(n=>get(n.slice(0,-5))):[];}
 function list(){return all().map(summary).sort((a,b)=>b.updatedAt.localeCompare(a.updatedAt));}
 function checkName(name,world,exceptId){if(typeof name!=='string'||!name.trim()||name.trim().length>80||/[\x00-\x1f]/.test(name))throw Error('Введите название пресета карты до 80 символов.');const n=name.trim();if(all().some(p=>p.id!==exceptId&&p.design.world===world&&p.name.toLowerCase()===n.toLowerCase()))throw Error(`Пресет «${n}» для этой карты уже есть. Сохраните поверх него или выберите другое название.`);return n;}
 function write(p){fs.mkdirSync(dir,{recursive:true});durable.write(file(p.id),p);return {...summary(p),verified:true};}
 function save(name,value,nodes){const design=designs.validate(value,nodes,{draft:true}),now=new Date().toISOString();return write({id:crypto.randomUUID(),name:checkName(name,design.world),createdAt:now,updatedAt:now,revision:1,design:meta(design)});}
 function update(id,change,nodes){const p=get(id),wasInGame=inGame(p);if(change.revision!==undefined&&change.revision!==(p.revision||1))throw Error('Этот пресет уже изменён в другом окне. Откройте его заново, чтобы не потерять новые изменения.');
  if(change.design!==undefined){const d=designs.validate(change.design,nodes,{draft:true});if(d.world!==p.design.world)throw Error('Пресет относится к другой карте. Сохраните как новый пресет.');p.design=meta(d);}
  if(change.name!==undefined)p.name=checkName(change.name,p.design.world,p.id);
  p.revision=(p.revision||1)+1;p.updatedAt=new Date().toISOString();const result=write(p);
  /* the preset the game uses stays the game's map after an edit */
  if(wasInGame&&change.design!==undefined){designs.save(p.design,nodes);result.inGame=true;result.appliedToGame=true;}
  return result;}
 function remove(id,revision){const p=get(id);if(revision!==undefined&&revision!==(p.revision||1))throw Error('Пресет изменён в другом окне — удаление отменено. Обновите список.');const bin=path.join(dir,'deleted');fs.mkdirSync(bin,{recursive:true});fs.renameSync(file(id),path.join(bin,id+'-'+Date.now()+'.json'));return {deleted:true,id,name:p.name};}
 function current(){return designs.worlds().flatMap(w=>{const d=designs.load(w.id);return d.sectors.length?[{...summary({id:'current:'+w.id,name:d.title,updatedAt:d.savedAt||'',design:d}),current:true}]:[];});}
 function apply(id,nodes){const p=get(id),d=designs.validate(p.design,nodes,{draft:true});const old=designs.load(d.world);const backup=path.join(dir,'backups');fs.mkdirSync(backup,{recursive:true});fs.writeFileSync(path.join(backup,crypto.randomUUID()+'.json'),JSON.stringify(old,null,2));return designs.save(d,nodes);}
 return {list,get,save,update,remove,current,apply};
}
module.exports={createStore,...createStore()};
