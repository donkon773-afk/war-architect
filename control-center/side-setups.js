'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),durable=require('./durable'),contract=require('./side-setup-client');
/* Saving is independent from the installed catalog and native class sides.
 * Launch-time compatibility stays in warlords-editor.validate(). */
function validate(value){
  if(!value||typeof value!=='object'||Array.isArray(value))throw Error('Некорректный сетап стороны.');
  contract.side(value.side);
  const className=id=>typeof id==='string'&&id.length<=128&&/^[A-Za-z0-9_]+$/.test(id);
  if(!className(value.faction))throw Error('Укажите корректный класс фракции.');
  if(!Array.isArray(value.assets)||value.assets.some(id=>!className(id)))throw Error('Техника: укажите корректные имена классов.');
  if(value.infantry!==null&&(!Array.isArray(value.infantry)||value.infantry.some(id=>!className(id))))throw Error('Пехота: укажите корректные имена классов или автоматический состав.');
  const costs=value.infantryCosts;
  if(!costs||typeof costs!=='object'||Array.isArray(costs)||Object.entries(costs).some(([id,cost])=>!className(id)||!Number.isInteger(cost)||cost<60||cost>50000))throw Error('Цена пехоты должна быть целым числом от 60 до 50000 CP.');
  return {side:value.side,faction:value.faction,assets:[...new Set(value.assets)],infantry:value.infantry===null?null:[...new Set(value.infantry)],infantryCosts:{...costs}};
}
function createStore(dir=path.join(__dirname,'data/side-setups')){
  function file(id){if(typeof id!=='string'||!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(id))throw Error('Некорректный ID сетапа.');return path.join(dir,id+'.json');}
  function get(id){const f=file(id);if(!fs.existsSync(f))throw Error('Сетап не найден. Обновите список.');return JSON.parse(fs.readFileSync(f,'utf8'));}
  function records(){return fs.existsSync(dir)?fs.readdirSync(dir).filter(f=>/^[0-9a-f-]{36}\.json$/.test(f)).map(f=>get(f.slice(0,-5))):[];}
  function summary(r){return {id:r.id,name:r.name,side:r.setup.side,faction:r.setup.faction,assets:r.setup.assets.length,infantry:r.setup.infantry===null?'auto':r.setup.infantry.length,revision:r.revision,updatedAt:r.updatedAt};}
  function list(){return records().map(summary).sort((a,b)=>b.updatedAt.localeCompare(a.updatedAt));}
  function save(value){
    if(typeof value.name!=='string'||!value.name.trim()||value.name.trim().length>80||/[\x00-\x1f]/.test(value.name))throw Error('Название сетапа: от 1 до 80 символов.');
    const setup=validate(value.setup),old=value.id?get(value.id):null,all=records(),name=value.name.trim();
    if(old&&value.revision!==old.revision)throw Error('Сетап изменён в другом окне. Откройте его заново.');
    if(all.some(r=>r.id!==old?.id&&r.setup.side===setup.side&&r.name.toLocaleLowerCase('ru')===name.toLocaleLowerCase('ru')))throw Error('Сетап с таким названием для этой стороны уже существует.');
    const now=new Date().toISOString(),record={version:1,id:old?.id||crypto.randomUUID(),name,setup,revision:(old?.revision||0)+1,createdAt:old?.createdAt||now,updatedAt:now};
    return {...durable.write(file(record.id),record),verified:true};
  }
  function remove(id,revision){const r=get(id);if(revision!==r.revision)throw Error('Сетап изменён в другом окне — удаление отменено.');const bin=path.join(dir,'deleted');fs.mkdirSync(bin,{recursive:true});fs.renameSync(file(id),path.join(bin,id+'-'+Date.now()+'.json'));return {deleted:true,id};}
  return {list,get,save,remove};
}
module.exports={validate,createStore,...createStore()};
