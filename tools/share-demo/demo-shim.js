/* NeroAI Control Center — демо-копия для просмотра без сервера.
 * Подменяет fetch('/api/…') ответами из снимка demo-data.js. Изменения живут
 * в sessionStorage этой вкладки (панель и встроенный редактор видят одно и то же)
 * и пропадают при закрытии вкладки. Arma, мост и LLM здесь не вызываются. */
(function(){
"use strict";
const D=window.NERO_DEMO_DATA;if(!D)throw Error('demo-data.js не загружен');
const KEY='neroai-demo-state-v1',FILE=location.protocol==='file:';
const clone=v=>JSON.parse(JSON.stringify(v));
const canon=v=>{const st=x=>Array.isArray(x)?x.map(st):x&&typeof x==='object'?Object.fromEntries(Object.keys(x).sort().map(k=>[k,st(x[k])])):x;return JSON.stringify(st(v));};
const uuid=()=>(window.crypto?.randomUUID?crypto.randomUUID():'xxxxxxxx-xxxx-4xxx-8xxx-xxxxxxxxxxxx'.replace(/x/g,()=>(Math.random()*16|0).toString(16)));
if(window.crypto&&!crypto.randomUUID)crypto.randomUUID=uuid;
let memory=null;
function read(){try{const s=sessionStorage.getItem(KEY);if(s)return JSON.parse(s);}catch{}return memory||clone(D.mutable);}
function write(m){memory=m;try{sessionStorage.setItem(KEY,JSON.stringify(m));}catch{}}
const demoError=what=>Error('В демо-копии недоступно: '+what+'. Это просмотр интерфейса NeroAI Control Center без Arma, моста и LLM.');

function presetName(p){if(p.activePreset&&p.presets[p.activePreset]&&canon(p.presets[p.activePreset])===canon(p.selected))return p.activePreset;return Object.keys(p.presets).find(k=>canon(p.presets[k])===canon(p.selected))||'';}
function publicState(p){return {...p,...D.staticState,nodes:p.nodes};}
function checkRevision(p,r){if(r!==undefined&&r!==(p.revision||0))throw Error('Настройки уже изменены в другом окне. Обновите страницу (F5) — иначе старые значения перезаписали бы новые.');}
const meta=d=>{const c=clone(d||{});delete c.savedAt;for(const l of ['bases','sectors','spawns'])for(const x of c[l]||[])delete x.type;return c;};
function design(m,world){if(!D.blank[world])throw Error('Карта не найдена среди установленных.');return m.designs[world]||D.blank[world];}
function inGame(m,p){try{return canon(meta(design(m,p.design.world)))===canon(meta(p.design));}catch{return false;}}
function summary(m,p){return {id:p.id,name:p.name,world:p.design.world,title:p.design.title,createdAt:p.createdAt||p.updatedAt,updatedAt:p.updatedAt,revision:p.revision||1,inGame:inGame(m,p),sectors:p.design.sectors.length,bases:p.design.bases.length,spawns:p.design.spawns.length,mode:p.design.mode,playerRole:p.design.playerRole||'commander'};}
function getPreset(m,id){const p=m.mapPresets[id];if(!p)throw Error('Пресет карты не найден — возможно, он удалён в другом окне. Обновите список.');return p;}
function checkName(m,name,world,exceptId){if(typeof name!=='string'||!name.trim()||name.trim().length>80)throw Error('Введите название пресета карты до 80 символов.');const n=name.trim();if(Object.values(m.mapPresets).some(p=>p.id!==exceptId&&p.design.world===world&&p.name.toLowerCase()===n.toLowerCase()))throw Error(`Пресет «${n}» для этой карты уже есть. Сохраните поверх него или выберите другое название.`);return n;}
function saveDesign(m,d){const v=clone(d);for(const l of ['bases','sectors','spawns'])for(const x of v[l]||[])delete x.type;if(!(v.sectors||[]).length)throw Error('Добавьте хотя бы одну цель захвата.');v.savedAt=new Date().toISOString();m.designs[v.world]=v;return v;}

const GET={
 '/api/state':()=>({...publicState(read().profile),job:{status:'idle',message:'Демо-копия: запуск игры отключён.',startedAt:null},running:false,updateInstalled:true}),
 '/api/catalog':()=>D.catalog,
 '/api/worlds':()=>D.worlds,
 '/api/background-job':()=>({status:'idle',world:null,message:''}),
 '/api/design':q=>design(read(),q.get('world')),
 '/api/design-defaults':q=>{const b=D.blank[q.get('world')];if(!b)throw Error('Карта не найдена среди установленных.');return b;},
 '/api/map-presets':()=>{const m=read();return {presets:Object.values(m.mapPresets).map(p=>summary(m,p)).sort((a,b)=>b.updatedAt.localeCompare(a.updatedAt)),current:D.worlds.flatMap(w=>{const d=design(m,w.id);return d.sectors.length?[{...summary(m,{id:'current:'+w.id,name:d.title,updatedAt:d.savedAt||'',design:d}),current:true}]:[];})};},
 '/api/map-preset':q=>getPreset(read(),q.get('id')),
 '/api/journal':()=>({bridgeFile:'Демо-копия',bridge:'Журнал моста NeroAI появляется на ПК с запущенной игрой и LLM. В этой копии он не подключён.',rptFile:'Демо-копия',engine:'Журнал Arma 3 (RPT) в этой копии не подключён.'})
};
const POST={
 '/api/save':b=>{const m=read(),p=m.profile;checkRevision(p,b.revision);p.selected=clone(b.selected);if(b.name!==undefined){if(typeof b.name!=='string'||b.name.length>60||!b.name.trim())throw Error('Введите название пресета до 60 символов.');p.presets[b.name]=clone(b.selected);p.activePreset=b.name;}else p.activePreset=presetName({...p,activePreset:''});p.revision=(p.revision||0)+1;write(m);return publicState(p);},
 '/api/preset-delete':b=>{const m=read(),p=m.profile;checkRevision(p,b.revision);if(!Object.hasOwn(p.presets,b.name))throw Error('Пресет не найден — возможно, он уже удалён.');delete p.presets[b.name];if(p.activePreset===b.name)p.activePreset='';p.revision=(p.revision||0)+1;write(m);return publicState(p);},
 '/api/nodes':b=>{const m=read(),p=m.profile;if(typeof b.label!=='string'||!b.label.trim()||b.label.length>60)throw Error('Введите короткое название узла.');let u;try{u=new URL(b.baseUrl);}catch{throw Error('Нужен HTTP-адрес API модели без пароля и параметров.');}if(!['http:','https:'].includes(u.protocol))throw Error('Нужен HTTP-адрес API модели без пароля и параметров.');p.nodes.push({id:uuid(),label:b.label,baseUrl:u.href.replace(/\/+$/,''),model:''});write(m);return publicState(p);},
 '/api/check':b=>{const started=performance.now(),node=read().profile.nodes.find(n=>n.id===b.id);if(!node)throw Error('Узел не найден.');return {id:node.id,models:(D.models[node.id]||[]).map(id=>({id,vision:false})),ms:Math.round(performance.now()-started),modelAdvertisementOnly:true,demo:true};},
 '/api/launch':()=>{throw demoError('запуск Arma и LLM');},
 '/api/console':()=>{throw demoError('окно журнала');},
 '/api/build-background':()=>{throw demoError('сборка спутниковой карты из файлов игры');},
 '/api/import-survey':()=>{throw demoError('импорт съёмки карты из игры');},
 '/api/map-image':()=>{throw demoError('загрузка своего изображения карты');},
 '/api/design':b=>{const m=read(),d=b.design;if(b.expectedSavedAt!==undefined&&m.designs[d.world]&&(m.designs[d.world].savedAt||'')!==(b.expectedSavedAt||''))throw Error('Карта уже сохранена в другом окне. Обновите редактор, чтобы не перезаписать более новые изменения.');const v=saveDesign(m,d);write(m);return v;},
 '/api/map-presets':b=>{const m=read(),d=meta(b.design||design(m,b.world)),now=new Date().toISOString();if(!(d.sectors||[]).length)throw Error('Добавьте хотя бы одну цель захвата.');const p={id:uuid(),name:checkName(m,b.name,d.world),createdAt:now,updatedAt:now,revision:1,design:d};m.mapPresets[p.id]=p;write(m);return {...summary(m,p),verified:true};},
 '/api/map-preset-update':b=>{const m=read(),p=getPreset(m,b.id),was=inGame(m,p);if(b.revision!==undefined&&b.revision!==(p.revision||1))throw Error('Этот пресет уже изменён в другом окне. Откройте его заново, чтобы не потерять новые изменения.');if(b.design!==undefined){if(b.design.world!==p.design.world)throw Error('Пресет относится к другой карте. Сохраните как новый пресет.');p.design=meta(b.design);}if(b.name!==undefined)p.name=checkName(m,b.name,p.design.world,p.id);p.revision=(p.revision||1)+1;p.updatedAt=new Date().toISOString();const r={...summary(m,p),verified:true};if(was&&b.design!==undefined){saveDesign(m,p.design);r.inGame=true;r.appliedToGame=true;}write(m);return r;},
 '/api/map-preset-delete':b=>{const m=read(),p=getPreset(m,b.id);if(b.revision!==undefined&&b.revision!==(p.revision||1))throw Error('Пресет изменён в другом окне — удаление отменено. Обновите список.');delete m.mapPresets[b.id];write(m);return {deleted:true,id:b.id,name:p.name};},
 '/api/map-preset-apply':b=>{const m=read(),p=getPreset(m,b.id);const v=saveDesign(m,p.design);write(m);return v;}
};

const json=(status,data)=>new Response(JSON.stringify(data),{status,headers:{'Content-Type':'application/json; charset=utf-8'}});
const vectors={};
window.__neroVector=(id,data)=>{const v=vectors[id];if(v)v.resolve(data);};
function loadVector(id){if(!vectors[id]){let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b;});vectors[id]={promise,resolve};const s=document.createElement('script');s.src='demo/vector/'+encodeURIComponent(id)+'.js';s.onerror=()=>{delete vectors[id];reject(Error('нет слоя'));};document.head.append(s);}return vectors[id].promise;}
const nativeFetch=window.fetch?window.fetch.bind(window):null;
window.fetch=async function(input,init={}){
 const raw=typeof input==='string'?input:input instanceof URL?input.href:input?.url;
 if(typeof raw!=='string'||!(raw==='/'||raw.startsWith('/api/')||raw.startsWith('/map-vector/')))return nativeFetch(input,init);
 await new Promise(r=>setTimeout(r,25));
 if(raw==='/')return new Response('const SESSION="'+'0'.repeat(48)+'"',{status:200,headers:{'Content-Type':'text/html'}});
 const url=new URL(raw,'http://demo.local');
 if(url.pathname.startsWith('/map-vector/')){const id=decodeURIComponent(url.pathname.slice(12).replace(/\.json$/,''));try{return json(200,await loadVector(id));}catch{return json(404,{error:'Слой не найден.'});}}
 const method=String(init.method||'GET').toUpperCase();
 try{
  if(method==='GET'&&GET[url.pathname])return json(200,GET[url.pathname](url.searchParams));
  if(method==='POST'&&POST[url.pathname]){const r=POST[url.pathname](JSON.parse(init.body||'{}'));return json(url.pathname==='/api/launch'?202:200,r);}
  return json(404,{error:'Не найдено.'});
 }catch(e){return json(400,{error:e.message});}
};
window.NERO_DEMO={
 tiles:!!D.tiles,
 originOk:o=>o===location.origin||(FILE&&(o==='null'||o==='file://')),
 target:()=>FILE?'*':location.origin
};
/* плашка «демо» — только в главном окне панели, не во встроенном редакторе */
if(window.top===window.self&&!/designer\.html$/i.test(location.pathname)){
 document.addEventListener('DOMContentLoaded',()=>{document.title+=' · демо';const bar=document.createElement('div');bar.setAttribute('role','note');bar.style.cssText='background:#3b2f12;color:#ffe2a6;border-bottom:1px solid #6b5420;padding:8px 16px;font:13px/1.45 "Segoe UI",sans-serif;text-align:center';bar.textContent='Демо-копия NeroAI Control Center (снимок '+D.snapshotDate+'). Можно смотреть и менять настройки, карты и пресеты — изменения живут до закрытия вкладки. Запуск Arma, проверка LLM и запись на диск отключены.';document.body.prepend(bar);});
}
})();
