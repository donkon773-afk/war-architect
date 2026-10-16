"use strict";
const fs=require("node:fs"),path=require("node:path"),crypto=require("node:crypto");
const editor=require("./warlords-editor");
const project=path.resolve(__dirname,"..");
const projects={warlords:project,antistasi:path.resolve(project,"..","NeroAI_5.0-antistasi")};
const read=file=>JSON.parse(fs.readFileSync(file,"utf8").replace(/^\uFEFF/,""));
const profileFile=path.join(__dirname,"data","profiles.json");
// 8.10: every panel write is fsync + rename + read-back verified (durable.js).
function atomic(file,value){require("./durable").write(file,value);}
function endpointUrl(value){const u=new URL(value);if(!["http:","https:"].includes(u.protocol)||u.username||u.password||u.search||u.hash)throw new Error("Нужен HTTP-адрес API модели без пароля и параметров.");return u.href.replace(/\/+$/,"");}
function initial(){
  const ownConfig=path.join(project,"bridge","neroai3.config.json"),antiConfig=path.join(projects.antistasi,"bridge","neroai3.config.json");
  const wl=read(fs.existsSync(ownConfig)?ownConfig:path.join(project,"bridge","neroai3.config.example.json"));
  const anti=fs.existsSync(antiConfig)?read(antiConfig):{lmStudio:wl.lmStudio,endpoints:{}};
  const nodes=[];
  function add(id,label,e){if(e?.baseUrl&&!nodes.some(n=>n.baseUrl===e.baseUrl)){nodes.push({id,label,baseUrl:endpointUrl(e.baseUrl),model:e.model||"",apiKey:e.apiKey||"lm-studio"});}}
  add("mac","MacBook",wl.lmStudio);
  for(const [id,e] of Object.entries(anti.endpoints||{}))if(id!=="primary")add(id,e.label||id,{...anti.lmStudio,...e});
  const selected={scenario:"warlords",mode:"single",primaryNode:nodes[0].id,primaryModel:wl.lmStudio.model,secondaryNode:nodes[1]?.id||nodes[0].id,secondaryModel:nodes[1]?.model||wl.lmStudio.model,temperature:0.9,maxTokens:900,profile:"donko",map:"Australia",dev:true,ace:true,parameters:{}};
  return {version:1,nodes,selected,presets:{"Warlords · Mac":selected,"Antistasi · Mac":{...selected,scenario:"antistasi"}}};
}
function load(){if(!fs.existsSync(profileFile))atomic(profileFile,initial());return read(profileFile);}
function parameters(){const {parseConfig}=require("../tools/validate-mission");return Object.entries(parseConfig(fs.readFileSync(path.join(project,"tools","mission-assets","params.hpp"),"utf8")).classes.Params.classes).map(([id,c])=>({id,title:c.values.title,values:c.values.values,texts:c.values.texts,default:c.values.default}));}
function validate(value,state,options={}){
  const s={...value};
  if(!Object.hasOwn(projects,s.scenario)||!["single","dual","vanilla","tactical"].includes(s.mode))throw new Error("Неизвестный сценарий или режим LLM.");
  // 9.10: "vanilla" = standard Arma/Warlords AI — no bridge, no model checks, NeroAI leaves the bots alone.
  const vanilla=s.mode==="vanilla";if(vanilla&&s.scenario!=="warlords")throw new Error("Штатный ИИ Arma без LLM доступен только для Warlords.");
  // 11.10: "tactical" = NeroAI tactical AI without LLM (side strategist + squad rules in the addon) — no bridge, no models.
  const tactical=s.mode==="tactical";if(tactical&&s.scenario!=="warlords")throw new Error("Тактический ИИ NeroAI без LLM доступен только для Warlords.");
  const noLLM=vanilla||tactical;
  s.vanillaLambs=s.vanillaLambs??false;if(typeof s.vanillaLambs!=="boolean")throw new Error("Некорректный переключатель LAMBS.");
  if(!["Australia","Takistan","Altis","Chernarus",...require('./scenario-design').worlds().map(w=>w.id)].includes(s.map))throw new Error("Неизвестная карта.");
  s.useDesign=s.useDesign??false;if(typeof s.useDesign!=='boolean')throw new Error('Некорректный переключатель редактора.');
  if(s.scenario==='warlords'&&s.useDesign){const designs=require('./scenario-design'),d=designs.load(s.map);if(!options.draft&&!d.sectors.length)throw new Error('В рабочей карте «'+designs.world(s.map).label+'» нет целей захвата. Если точки есть в пресете, откройте его и нажмите «Использовать этот пресет в игре». Сохранение пресета само по себе не выбирает его для запуска.');designs.validate(d,state.nodes,options);}
  if(s.scenario==='warlords'&&!s.useDesign&&!['Australia','Takistan','Altis','Chernarus'].includes(s.map))throw new Error('Для этой карты сначала сохраните сценарий в редакторе и включите его использование.');
  if(typeof s.profile!=="string"||!s.profile.trim()||s.profile.length>60||/["\r\n\\/;<>]/.test(s.profile))throw new Error("Некорректное имя профиля Arma.");
  for(const prefix of noLLM?[]:s.mode==="dual"?["primary","secondary"]:["primary"]){if(!state.nodes.some(n=>n.id===s[prefix+"Node"]))throw new Error("Узел не найден.");if(typeof s[prefix+"Model"]!=="string"||!s[prefix+"Model"].trim()||s[prefix+"Model"].length>200||/[\r\n]/.test(s[prefix+"Model"]))throw new Error("Выберите модель.");}
  if(!Number.isFinite(s.temperature)||s.temperature<0||s.temperature>1.5)throw new Error("Температура: от 0 до 1.5.");
  if(!Number.isInteger(s.maxTokens)||s.maxTokens<256||s.maxTokens>4096)throw new Error("Лимит ответа: 256–4096 токенов.");
  if(typeof s.dev!=="boolean"||typeof s.ace!=="boolean")throw new Error("Некорректные переключатели.");
  if(s.scenario==='warlords')s.ace=true;
  const catalog=parameters(),clean={};
  for(const [id,v] of Object.entries(s.parameters||{})){const p=catalog.find(p=>p.id===id);if(!p||!p.values.includes(v))throw new Error(`Недопустимое значение параметра ${id}`);clean[id]=v;}
  if(vanilla)clean.NeroWL_VanillaAI=1;else if(tactical)clean.NeroWL_VanillaAI=2;else delete clean.NeroWL_VanillaAI;
  s.parameters=clean;
  s.devMode=require('./dev-mode').normalize(s.devMode);
  s.instructions=s.instructions??""; if(typeof s.instructions!=="string"||s.instructions.length>3000)throw new Error("Инструкции: максимум 3000 символов.");
  s.commanders=s.commanders??10;if(![10,12,16].includes(s.commanders))throw new Error("Командиров на сторону: 10, 12 или 16.");
  s.allyRoute=s.allyRoute??"shared";if(!["shared","separate"].includes(s.allyRoute))throw new Error("Неизвестный маршрут союзной LLM.");
  if(!noLLM&&s.allyRoute==="separate"){if(!state.nodes.some(n=>n.id===s.allyNode)||typeof s.allyModel!=="string"||!s.allyModel.trim()||s.allyModel.length>200||/[\r\n]/.test(s.allyModel))throw new Error("Выберите узел и модель союзников.");}
  s.army=options.draft?editor.validateDraft(s.army):editor.validate(s.army);return s;
}
function selectedPresetName(state){
  const name=state.activePreset;
  if(!name||!Object.hasOwn(state.presets||{},name))return "";
  try{return require("node:util").isDeepStrictEqual(validate(state.selected,state,{draft:true}),validate(state.presets[name],state,{draft:true}))?name:"";}
  catch{return "";}
}
// 8.10: opts.revision = the profile revision the page loaded; a stale window (older revision) cannot overwrite newer settings.
function checkRevision(state,opts){if(opts&&opts.revision!==undefined&&opts.revision!==(state.revision||0))throw new Error("Настройки уже изменены в другом окне или после перезапуска панели. Обновите страницу (F5) — иначе старые значения перезаписали бы новые.");}
function deletePreset(name,opts={}){const state=load();checkRevision(state,opts);if(typeof name!=="string"||!Object.hasOwn(state.presets||{},name))throw new Error("Пресет не найден — возможно, он уже удалён.");delete state.presets[name];if(state.activePreset===name)state.activePreset="";state.revision=(state.revision||0)+1;atomic(profileFile,state);return publicState(state);}
function saveSelected(value,name,opts={}){const state=load();checkRevision(state,opts);const s=validate(value,state,{draft:true});state.selected=s;if(name){if(typeof name!=="string"||name.length>60||!name.trim())throw new Error("Введите название пресета до 60 символов.");Object.defineProperty(state.presets,name,{value:s,enumerable:true,configurable:true,writable:true});state.activePreset=name;}else state.activePreset=selectedPresetName(state);state.revision=(state.revision||0)+1;atomic(profileFile,state);return publicState(state);}
function addNode(value){const state=load();if(state.nodes.length>=16)throw new Error("Слишком много узлов.");if(typeof value.label!=="string"||!value.label.trim()||value.label.length>60)throw new Error("Введите короткое название узла.");const node={id:crypto.randomUUID(),label:value.label,baseUrl:endpointUrl(value.baseUrl),model:"",apiKey:value.apiKey||"lm-studio"};if(typeof node.apiKey!=="string"||node.apiKey.length>2048||/[\r\n]/.test(node.apiKey))throw new Error("Некорректный ключ.");state.nodes.push(node);atomic(profileFile,state);return publicState(state);}
function publicState(state=load()){return {...state,revision:state.revision||0,activePreset:selectedPresetName(state),maps:require("./scenario-design").worlds().map(w=>({id:w.id,label:w.label})),nodes:state.nodes.map(({apiKey,...n})=>n),parameters:parameters(),armyDefaults:editor.defaults(),missionNames:{Australia:`NeroAI Warlords - Australia (Mac RHS ${state.selected?.commanders||10}v${state.selected?.commanders||10})`,Takistan:"NeroAI Warlords RHS + Zeus - Takistan",Altis:"NeroAI Warlords RHS + Zeus - Altis",Chernarus:"NeroAI Warlords RHS + Zeus - Chernarus"}};}
async function models(node){const response=await fetch(endpointUrl(node.baseUrl)+"/models",{headers:{Authorization:`Bearer ${node.apiKey||"lm-studio"}`},signal:AbortSignal.timeout(8000)});if(!response.ok)throw new Error(`API моделей: HTTP ${response.status}`);const json=await response.json();if(!Array.isArray(json.data))throw new Error("Ответ API не содержит список моделей.");return json.data.slice(0,100).map(m=>({id:String(m.id),vision:!!(m.capabilities?.vision||m.type==="vlm"||m.arch?.includes?.("vl"))}));}
function makeConfig(selection,state,base){
  const s=validate(selection,state),primary=state.nodes.find(n=>n.id===s.primaryNode),secondary=state.nodes.find(n=>n.id===s.secondaryNode);
  if(s.mode==="vanilla")return {...structuredClone(base),standardAI:true};
  if(s.mode==="tactical")return {...structuredClone(base),tacticalAI:true};
  // GPT-OSS (harmony) loses its reasoning channel under grammar-constrained
  // json_schema decoding and then answers only SET_SECTOR (live 7.10: 0 moves in
  // 82 plans; without the schema 1-3 of 4 moved). The protocol validator,
  // allowlist and grounding stay authoritative; the reasoning needs token room.
  const tuned=model=>/gpt-oss/i.test(model)?{structuredOutput:false,reasoningEffort:"low",maxTokens:Math.max(s.maxTokens,1500)}:{};
  const profile=(node,model)=>({...base.lmStudio,baseUrl:node.baseUrl,apiKey:node.apiKey||"lm-studio",model,fallbackModel:"",temperature:s.temperature,maxTokens:s.maxTokens,reasoningEffort:"none",maxConcurrent:1,...tuned(model)});
  const result=structuredClone(base);
  result.lmStudio=profile(primary,s.primaryModel);result.transport.maxPending=1;
  if(s.scenario==="warlords"){
    result.preGameInstructions=s.instructions;
    // 7.10: in dual mode the primary is the strategist for every AI army (bothSides), the secondary plans the groups.
    result.dualEnemy={...(result.dualEnemy||{}),enabled:s.mode==="dual",bothSides:s.mode==="dual",strategy:profile(primary,s.primaryModel)};
    if(s.mode==="dual")result.lmStudio=profile(secondary,s.secondaryModel);
    result.lmStudio.sides={ALLIED:s.allyRoute==="separate"?profile(state.nodes.find(n=>n.id===s.allyNode),s.allyModel):profile(primary,s.primaryModel)};
    delete result.lmStudio.garrison;
    result.garrisonInstructions='';
    if(s.useDesign){const g=require('./scenario-design').load(s.map).garrisonLLM;if(g?.enabled){result.garrisonInstructions=g.instructions;if(g.route==='separate')result.lmStudio.garrison=profile(state.nodes.find(n=>n.id===g.node),g.model);}}
  }else{
    result.endpoints={primary:{label:primary.label,maxConcurrent:1}};
    result.routing={};
    if(s.mode==="dual")result.endpoints.tactical={...profile(secondary,s.secondaryModel),label:secondary.label};
    for(const lane of ["STRATEGY","ORDER","TALK","AUTONOMY","INTERGROUP"])result.routing[lane]=lane==="STRATEGY"||s.mode==="single"?["primary"]:["tactical","primary"];
  }
  // Current capture path is not a camera source. GPT-OSS text-only selection
  // must never silently activate an old visual endpoint.
  if(result.vision)result.vision.enabled=false;
  return result;
}
module.exports={project,projects,profileFile,read,atomic,endpointUrl,load,parameters,validate,saveSelected,deletePreset,addNode,publicState,models,makeConfig};

