"use strict";
const http=require("node:http"),fs=require("node:fs"),path=require("node:path"),crypto=require("node:crypto"),{execFile,spawn}=require("node:child_process"),{promisify}=require("node:util");
const run=promisify(execFile),core=require("./core");
const shell=[process.env.NEROAI_PWSH,"C:\\Program Files\\PowerShell\\7\\pwsh.exe",path.join(process.env.USERPROFILE||"", ".cache","codex-runtimes","codex-primary-runtime","dependencies","native","powershell","pwsh.exe")].find(p=>p&&fs.existsSync(p))||"powershell.exe";
const token=crypto.randomBytes(24).toString("hex");
let backgroundJob={status:"idle",world:null,message:""};
let job={status:"idle",message:"Готов к настройке.",startedAt:null};
const apiHeaders={"Content-Type":"application/json; charset=utf-8","Cache-Control":"no-store","X-Content-Type-Options":"nosniff"};
function send(res,status,data){res.writeHead(status,apiHeaders);res.end(JSON.stringify(data));}
// Steam may keep inherited pipes open after the helper exits. Wait for the
// helper's exit with file-backed output, rather than waiting for pipe closure.
function launchHelper(requestFile){return new Promise((resolve,reject)=>{
  const log=path.join(__dirname,"logs","launch-helper.log");fs.mkdirSync(path.dirname(log),{recursive:true});
  const fd=fs.openSync(log,"w"),child=spawn(shell,["-NoProfile","-ExecutionPolicy","Bypass","-File",path.join(__dirname,"launch.ps1"),"-RequestFile",requestFile],{windowsHide:true,stdio:["ignore",fd,fd]});fs.closeSync(fd);
  const timer=setTimeout(()=>{child.kill();reject(new Error("Подготовка запуска превысила четыре минуты. См. launch-helper.log."));},240000);
  child.once("error",e=>{clearTimeout(timer);reject(e);});
  child.once("exit",code=>{clearTimeout(timer);if(code===0)resolve();else reject(new Error(fs.readFileSync(log,"utf8").slice(-6000).replace(/Bearer\s+[^\s]+/g,"Bearer [hidden]")));});
});}
async function body(req,max=131072){let raw="";for await(const chunk of req){raw+=chunk;if(Buffer.byteLength(raw)>max)throw new Error("Слишком большой запрос.");}return JSON.parse(raw||"{}");}
async function gameRunning(){const result=await run(shell,["-NoProfile","-Command","@(Get-Process -Name arma3_x64,arma3server_x64,arma3battleye,arma3launcher -ErrorAction SilentlyContinue).Count"],{windowsHide:true,timeout:10000});return Number(result.stdout.trim())>0;}
async function installed(scenario=core.load().selected.scenario){return require('./addon-package').installed(scenario,core);}
async function prepareAndLaunch(selection){
  if(await gameRunning())throw new Error("Arma уже открыта. Сохраните нужное и закройте её сами; затем нажмите запуск снова.");
  const state=core.load(),s=core.validate(selection,state);
  if(s.scenario==='warlords')require('./operation-required-mods').resolve({type:'warlords'});
  const vanilla=s.mode==="vanilla",tactical=s.mode==="tactical",noLLM=vanilla||tactical;
  for(const prefix of noLLM?[]:s.mode==="dual"?["primary","secondary"]:["primary"]){const node=state.nodes.find(n=>n.id===s[prefix+"Node"]),list=await core.models(node);if(!list.some(m=>m.id===s[prefix+"Model"]))throw new Error(`На узле «${node.label}» не найдена выбранная модель.`);}
  if(!noLLM&&s.scenario==="warlords"&&s.allyRoute==="separate"){const node=state.nodes.find(n=>n.id===s.allyNode),list=await core.models(node);if(!list.some(m=>m.id===s.allyModel))throw new Error("Выбранная модель союзников не найдена на узле.");}
  if(!noLLM&&s.scenario==="warlords"&&s.useDesign){const g=require("./scenario-design").load(s.map).garrisonLLM;if(g.enabled&&g.route==="separate"){const node=state.nodes.find(n=>n.id===g.node),list=await core.models(node);if(!list.some(m=>m.id===g.model))throw new Error("Модель гарнизонов не найдена на выбранном узле.");}}
  const root=core.projects[s.scenario],base=core.read(path.join(root,"bridge","neroai3.config.json")),config=core.makeConfig(s,state,base);
  const runtime=path.join(__dirname,"data","runtime");fs.mkdirSync(runtime,{recursive:true});
  const configPath=path.join(runtime,`${s.scenario}.config.json`);core.atomic(configPath,config);
  let designed=null;
  let missionFiles=[];
  if(s.scenario==="warlords"){
    job.message="Сборка настроек миссии и установка проверенного обновления…";
    core.atomic(path.join(core.project,"dist","warlords-editor-settings.json"),{army:s.army,commanders:s.commanders});
    core.atomic(path.join(core.project,"dist","launcher-mission-settings.json"),{...s.parameters,NeroWL_Dev:s.dev?1:0,NeroWL_Experiments:s.devMode});
    let packs;
    if(s.useDesign){designed=require('../tools/build-designed-mission').build(require('./scenario-design').load(s.map),{...state,selected:s});packs=[designed];}
    else{
      await run("node",[path.join(core.project,"tools","build-australia-mission.js"),path.join(core.project,"dist","australia-rhs20.layout.json")],{windowsHide:true,timeout:20000,cwd:core.project});
      await run("node",[path.join(core.project,"tools","build-criteria-missions.js")],{windowsHide:true,timeout:20000,cwd:core.project});
      packs=[{output:path.join(core.project,"missions","NeroAI_Warlords_Australia_RHS20.australia"),name:"NeroAI_Warlords_Australia_RHS20",world:"australia"},...core.read(path.join(core.project,"dist","criteria-missions.json"))];
    }
    missionFiles=packs.map(m=>m.name+'.'+m.world+'.pbo');
    for(const m of packs){await run("node",[path.join(core.project,"tools","validate-mission.js"),m.output],{windowsHide:true,timeout:15000});await run(shell,["-NoProfile","-ExecutionPolicy","Bypass","-File",path.join(core.project,"tools","pack-pbo.ps1"),"-SourceDir",m.output,"-OutputDir",path.join(runtime,"missions"),"-OutputPbo",`${m.name}.${m.world}.pbo`,"-Mission"],{windowsHide:true,timeout:20000});await run("node",[path.join(core.project,"tools","verify-pbo.js"),path.join(runtime,"missions",`${m.name}.${m.world}.pbo`),m.output,"--mission"],{windowsHide:true,timeout:15000});}
  }
  // Mission builders regenerate native addon files. Pack only after all generators finish.
  job.message="Сборка и проверка аддона "+(s.scenario==='antistasi'?'Antistasi':'Warlords')+"…";
  await require('./addon-package').build(s.scenario,core,run,shell);
  job.message=vanilla?"Запуск клиента через Steam со штатным ИИ Arma (мост и модели не запускаются)…":tactical?"Запуск клиента через Steam с тактическим ИИ NeroAI без LLM (мост и модели не запускаются)…":"Проверка генерации модели и запуск клиента через Steam…";
  const requestFile=path.join(runtime,"launch-request.json");core.atomic(requestFile,{...s,configPath,missionFiles,extraMods:s.scenario==="warlords"?(designed?.extraMods||require("./warlords-editor").mods(s.army)):[]});
  await launchHelper(requestFile);
  job.message=s.scenario==="warlords"?`Клиент запущен. Создайте сервер на карте ${s.map} и выберите «${designed?.title||core.publicState(state).missionNames[s.map]}».${vanilla?" Ботами командует штатный ИИ Arma.":tactical?" Ботами командует тактический ИИ NeroAI без LLM.":""}`:"Клиент запущен. Создайте сервер или загрузите свою кампанию Antistasi.";
}
const vectorCache=new Map();
const server=http.createServer(async(req,res)=>{
  try{
    if(!["127.0.0.1","::1"].includes(req.socket.remoteAddress))return send(res,403,{error:"Только этот ПК."});
    if(req.headers.host!==`127.0.0.1:${server.address().port}`)return send(res,403,{error:"Некорректный адрес панели."});
    const url=new URL(req.url,"http://127.0.0.1");
    if(req.method==="GET"&&url.pathname==="/"){res.writeHead(200,{"Content-Type":"text/html; charset=utf-8","Cache-Control":"no-store","X-Frame-Options":"DENY"});return res.end(fs.readFileSync(path.join(__dirname,"index.html"),"utf8").replace("__SESSION_TOKEN__",token));}
    if(req.method==='GET'&&url.pathname==='/designer'){res.writeHead(200,{"Content-Type":"text/html; charset=utf-8","Cache-Control":"no-store","X-Frame-Options":"SAMEORIGIN","Content-Security-Policy":"frame-ancestors 'self'"});return res.end(fs.readFileSync(path.join(__dirname,'designer.html'),'utf8').replace('__SESSION_TOKEN__',token));}
    if(req.method==='GET'&&url.pathname==='/setups'){res.writeHead(200,{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store','X-Frame-Options':'SAMEORIGIN'});return res.end(fs.readFileSync(path.join(__dirname,'setups.html'),'utf8').replace('__SESSION_TOKEN__',token));}
    if(req.method==='GET'&&['/side-setup-client.js','/setups.js'].includes(url.pathname)){res.writeHead(200,{'Content-Type':'text/javascript; charset=utf-8','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'});return res.end(fs.readFileSync(path.join(__dirname,url.pathname.slice(1)),'utf8'));}
    if(req.method==='GET'&&(url.pathname.startsWith('/map-background/')||url.pathname.startsWith('/map-tile/'))){
      const tile=url.pathname.match(/^\/map-tile\/([^/]+)\/(\d+)\/(\d+)\.jpg$/),overview=url.pathname.match(/^\/map-background\/([^/]+)\.jpg$/);if(!tile&&!overview)return send(res,404,{error:'Фрагмент не найден.'});
      const w=require('./scenario-design').world(decodeURIComponent((tile||overview)[1])),file=require('./map-background').file(w,tile?Number(tile[2]):null,tile?Number(tile[3]):null);if(!file||!fs.existsSync(file)){res.writeHead(404);return res.end();}res.writeHead(200,{'Content-Type':'image/jpeg','Cache-Control':'public,max-age=3600','X-Content-Type-Options':'nosniff'});return fs.createReadStream(file).pipe(res);
    }
    if(req.method==='GET'&&url.pathname.startsWith('/map-vector/')){const m=url.pathname.match(/^\/map-vector\/([^/]+)\.json$/);if(!m)return send(res,404,{error:'Слой не найден.'});const w=require('./scenario-design').world(decodeURIComponent(m[1])),f=require('./map-background').vectorFile(w);if(!f){res.writeHead(404);return res.end();}const stamp=fs.statSync(f).mtimeMs;if(!vectorCache.has(w.id)||vectorCache.get(w.id).stamp!==stamp)vectorCache.set(w.id,{stamp,gz:require('node:zlib').gzipSync(fs.readFileSync(f),{level:6})});const gz=String(req.headers['accept-encoding']||'').includes('gzip');res.writeHead(200,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-cache','X-Content-Type-Options':'nosniff',...(gz?{'Content-Encoding':'gzip'}:{})});return res.end(gz?vectorCache.get(w.id).gz:require('node:zlib').gunzipSync(vectorCache.get(w.id).gz));}
    if(req.method==='GET'&&url.pathname.startsWith('/map-image/')){const w=require('./scenario-design').world(decodeURIComponent(url.pathname.slice(11))),f=path.join(__dirname,'data/map-images',w.id+(fs.existsSync(path.join(__dirname,'data/map-images',w.id+'.img'))?'.img':'.svg'));if(!fs.existsSync(f)){res.writeHead(404);return res.end();}const bytes=fs.readFileSync(f);res.writeHead(200,{'Content-Type':f.endsWith('.svg')?'image/svg+xml':bytes[0]===137?'image/png':'image/jpeg','Cache-Control':'no-store','Content-Security-Policy':"default-src 'none'",'X-Content-Type-Options':'nosniff'});return res.end(bytes);}
    if(req.headers["x-nero-session"]!==token)return send(res,403,{error:"Сессия панели устарела. Обновите страницу."});
    if(req.headers.origin&&req.headers.origin!==`http://127.0.0.1:${server.address().port}`)return send(res,403,{error:"Запрос не из панели."});
    if(req.method==="GET"&&url.pathname==="/api/state"){const state=core.publicState(),updateScenario=url.searchParams.get('scenario')||state.selected.scenario;return send(res,200,{...state,job,running:await gameRunning(),updateScenario,updateInstalled:await installed(updateScenario)});}
    if(req.method==="GET"&&url.pathname==="/api/catalog"){const inv=require("./warlords-editor").inventory();return send(res,200,{...inv,factionLabels:require("./faction-names").labels(inv.factions)});}
    if(req.method==='GET'&&url.pathname==='/api/side-setups')return send(res,200,{setups:require('./side-setups').list()});
    if(req.method==='GET'&&url.pathname==='/api/side-setup')return send(res,200,require('./side-setups').get(url.searchParams.get('id')));
    if(req.method==='GET'&&url.pathname==='/api/worlds')return send(res,200,require('./scenario-design').worlds().map(w=>({...w,background:require('./map-background').metadata(w),hasImage:['.img','.svg'].some(ext=>fs.existsSync(path.join(__dirname,'data/map-images',w.id+ext)))})));
    if(req.method==='GET'&&url.pathname==='/api/background-job')return send(res,200,backgroundJob);
    if(req.method==='GET'&&url.pathname==='/api/design')return send(res,200,require('./scenario-design').load(url.searchParams.get('world')));
    if(req.method==='GET'&&url.pathname==='/api/scenario-library')return send(res,200,require('./scenario-library').list());
    if(req.method==='GET'&&url.pathname==='/api/map-presets')return send(res,200,{presets:require('./map-presets').list(),current:require('./map-presets').current()});
    if(req.method==='GET'&&url.pathname==='/api/map-preset')return send(res,200,require('./map-presets').get(url.searchParams.get('id')));
    if(req.method==='GET'&&url.pathname==='/api/design-defaults')return send(res,200,require('./scenario-design').blank(url.searchParams.get('world')));
    if(req.method==="GET"&&url.pathname==="/api/journal")return send(res,200,require("./journal").read(core.project,path.join(process.env.LOCALAPPDATA||"","Arma 3"),core.load().nodes.map(n=>n.apiKey)));
    if(req.method!=="POST")return send(res,404,{error:"Не найдено."});
    const data=await body(req,url.pathname==='/api/map-image'?29*1024*1024:131072);
    if(url.pathname==='/api/side-setups')return send(res,200,require('./side-setups').save(data));
    if(url.pathname==='/api/side-setup-delete')return send(res,200,require('./side-setups').remove(data.id,data.revision));
    if(url.pathname==='/api/build-background'){
      const w=require('./scenario-design').world(data.world);if(backgroundJob.status==='running')throw Error('Уже собирается карта; дождитесь окончания.');if(await gameRunning())throw Error('Для сборки карты закройте Arma: обработка файлов создаёт временную нагрузку.');
      backgroundJob={status:'running',world:w.id,message:'Сборка спутниковой карты из установленных файлов…'};
      (async()=>{await run('node',[path.join(core.project,'tools/extract-map-background.js'),w.id],{windowsHide:true,cwd:core.project,timeout:120000});const manifest=path.join(__dirname,'data/map-tiles',w.id,'source.json');await run('python',[path.join(core.project,'tools/map-assets/build-background.py'),manifest],{windowsHide:true,cwd:core.project,timeout:240000});backgroundJob.message='Улицы и здания из файла карты, обзор 8K…';try{await run('node',['--max-old-space-size=6144',path.join(core.project,'tools/map-assets/build-vector-map.js'),w.id],{windowsHide:true,cwd:core.project,timeout:300000});await run('python',[path.join(core.project,'tools/map-assets/render-vector.py'),'overview',path.dirname(manifest),'8192'],{windowsHide:true,cwd:core.project,timeout:600000});}catch(e){fs.appendFileSync(path.join(__dirname,'logs','map-vector-error.log'),new Date().toISOString()+' '+w.id+' '+(e.stderr||e.message)+'\n');}backgroundJob={status:'done',world:w.id,message:'Спутниковая карта готова.'};})().catch(e=>{backgroundJob={status:'error',world:w.id,message:'Не удалось собрать карту: '+String(e.stderr||e.message).slice(-1000)};});return send(res,200,backgroundJob);
    }
    if(url.pathname==='/api/import-survey'){const w=require('./scenario-design').world(data.world),c=core.read(path.join(core.project,'bridge/neroai3.config.json')),result=require('./map-survey').importSurvey(w,c.transport.iniFolder),dir=path.join(__dirname,'data/map-images');fs.mkdirSync(dir,{recursive:true});fs.writeFileSync(path.join(dir,w.id+'.svg'),result.svg);return send(res,200,{saved:true,truncated:result.truncated,houses:result.houses,roads:result.roads});}
    if(url.pathname==='/api/map-presets')return send(res,200,require('./map-presets').save(data.name,data.design||require('./scenario-design').load(data.world),core.load().nodes));
    if(url.pathname==='/api/map-preset-apply'){if(job.status==='running')throw Error('Дождитесь завершения запуска игры перед сменой карты.');return send(res,200,require('./map-presets').apply(data.id,core.load().nodes));}
    if(url.pathname==='/api/design')return send(res,200,require('./scenario-design').save(data.design,core.load().nodes,data.expectedSavedAt));
    if(url.pathname==='/api/map-preset-update')return send(res,200,require('./map-presets').update(data.id,{name:data.name,design:data.design,revision:data.revision},core.load().nodes));
    if(url.pathname==='/api/map-preset-delete')return send(res,200,require('./map-presets').remove(data.id,data.revision));
    if(url.pathname==='/api/map-image'){const w=require('./scenario-design').world(data.world);if(typeof data.data!=='string'||!/^data:image\/(png|jpeg);base64,[A-Za-z0-9+/=]+$/.test(data.data))throw Error('Нужно изображение PNG/JPEG.');const bytes=Buffer.from(data.data.split(',')[1],'base64');if(bytes.length>20*1024*1024||!(bytes.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]))||bytes.subarray(0,3).equals(Buffer.from([255,216,255]))))throw Error('Изображение не прошло проверку.');require('./map-image').dimensions(bytes);const dir=path.join(__dirname,'data/map-images');fs.mkdirSync(dir,{recursive:true});fs.writeFileSync(path.join(dir,w.id+'.img'),bytes);return send(res,200,{saved:true});}
    if(url.pathname==="/api/console"){await run(shell,["-NoProfile","-ExecutionPolicy","Bypass","-File",path.join(__dirname,"open-console.ps1")],{windowsHide:true,timeout:10000});return send(res,200,{opened:true});}
    if(url.pathname==='/api/operations-panel'){
      await run(shell,['-NoProfile','-ExecutionPolicy','Bypass','-File',path.join(__dirname,'operations-start.ps1'),'-NoBrowser'],{windowsHide:true,timeout:20000});
      for(const port of [18792,18793,18794,18795,18796,18797,18798,18799,18786])try{const origin='http://127.0.0.1:'+port,health=await(await fetch(origin+'/health',{signal:AbortSignal.timeout(1000)})).json();if(health.application==='NeroAI Operations'&&health.features==='campaign-shop-becti-v7'&&health.workspaceEmbed===true)return send(res,200,{origin});}catch{}
      throw Error('Конструктор операций не ответил. Повторите открытие вкладки.');
    }
    if(url.pathname==="/api/save")return send(res,200,core.saveSelected(data.selected,data.name,{revision:data.revision}));
    if(url.pathname==="/api/preset-delete")return send(res,200,core.deletePreset(data.name,{revision:data.revision}));
    if(url.pathname==="/api/nodes")return send(res,200,core.addNode(data));
    if(url.pathname==="/api/check"){
      const node=core.load().nodes.find(n=>n.id===data.id);if(!node)throw new Error("Узел не найден.");
      const started=Date.now(),list=await core.models(node);return send(res,200,{id:node.id,models:list,ms:Date.now()-started,modelAdvertisementOnly:true});
    }
    if(url.pathname==="/api/launch"){
      if(job.status==="running")throw new Error("Запуск уже выполняется.");
      const selected=core.validate(data.selected,core.load());
      if(await gameRunning())throw new Error("Arma уже открыта. Сохраните нужное и полностью закройте её сами.");
      const savedState=core.saveSelected(selected,undefined,{revision:data.revision});job={status:"running",message:"Проверка выбранных узлов…",startedAt:new Date().toISOString()};
      prepareAndLaunch(selected).then(()=>{job.status="done";}).catch(e=>{job.status="error";job.message=e.message?.includes("Command failed")?"Запуск остановлен. Подробности записаны в control-center/logs/launch-error.log.":e.message;fs.mkdirSync(path.join(__dirname,"logs"),{recursive:true});fs.writeFileSync(path.join(__dirname,"logs","launch-error.log"),String(e.stderr||e.message).replace(/Bearer\s+[^\s]+/g,"Bearer [hidden]"));});
      return send(res,202,{job,revision:savedState.revision});
    }
    send(res,404,{error:"Не найдено."});
  }catch(e){send(res,400,{error:e.message});}
});
function listen(port){server.once("error",e=>{if(e.code==="EADDRINUSE"&&port<18785){server.removeAllListeners("error");listen(port+1);}else throw e;});server.listen(port,"127.0.0.1",()=>{core.load();core.atomic(path.join(__dirname,"data","session.json"),{pid:process.pid,port,startedAt:new Date().toISOString()});console.log(`NeroAI Control Center: http://127.0.0.1:${port}`);});}
if(require.main===module)listen(18775);
module.exports={gameRunning,prepareAndLaunch,installed};
