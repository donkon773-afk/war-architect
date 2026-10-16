"use strict";
const test=require("node:test"),assert=require("node:assert/strict"),http=require("node:http"),fs=require("node:fs");
const core=require("./core");
const state={nodes:[{id:"mac",label:"Mac",baseUrl:"http://127.0.0.1:1234/v1",apiKey:"secret-mac"},{id:"rtx",label:"RTX",baseUrl:"http://127.0.0.1:1235/v1",apiKey:"secret-rtx"}],presets:{}};
const selected={scenario:"warlords",mode:"single",primaryNode:"mac",primaryModel:"openai/gpt-oss-20b",secondaryNode:"rtx",secondaryModel:"vl-model",temperature:0.9,maxTokens:900,profile:"donko",map:"Australia",ace:true,dev:true,parameters:{BIS_WLMaxSubordinates:9,NeroWL_Air:5}};
const base={lmStudio:{model:"old",baseUrl:"http://old/v1",apiKey:"old"},transport:{outboxDb:"isolated_out",maxPending:2},endpoints:{obsolete:{baseUrl:"http://dead/v1"}},routing:{STRATEGY:["obsolete"]},vision:{enabled:true}};
test("single Mac routing removes stale nodes and leaves transport independent",()=>{
  const c=core.makeConfig({...selected,scenario:"antistasi"},state,base);
  assert.equal(c.lmStudio.model,selected.primaryModel);assert.equal(c.lmStudio.baseUrl,state.nodes[0].baseUrl);
  assert.deepEqual(Object.keys(c.endpoints),["primary"]);for(const lanes of Object.values(c.routing))assert.deepEqual(lanes,["primary"]);
  assert.equal(c.transport.outboxDb,"isolated_out");assert.equal(c.vision.enabled,false);assert.equal(base.lmStudio.model,"old");
});
test("two LLM routing binds strategy and tactics to selected roles",()=>{
  const wl=core.makeConfig({...selected,mode:"dual"},state,base);assert.equal(wl.dualEnemy.strategy.model,selected.primaryModel);assert.equal(wl.lmStudio.model,selected.secondaryModel);
  const anti=core.makeConfig({...selected,scenario:"antistasi",mode:"dual"},state,base);assert.deepEqual(anti.routing.STRATEGY,["primary"]);assert.deepEqual(anti.routing.AUTONOMY,["tactical","primary"]);assert.equal(anti.endpoints.tactical.baseUrl,state.nodes[1].baseUrl);
});
test("invalid launch arguments, URLs and unsupported settings are rejected",()=>{
  for(const profile of ['donko" -mod=other','donko\n','../other'])assert.throws(()=>core.validate({...selected,profile},state));
  for(const url of ["file:///C:/Windows","http://user:password@localhost/v1","http://localhost/v1?x=1"])assert.throws(()=>core.endpointUrl(url));
  assert.throws(()=>core.validate({...selected,parameters:{NeroWL_Air:99}},state));assert.throws(()=>core.validate({...selected,primaryNode:"missing"},state));
  assert(!JSON.stringify(core.publicState({...state,selected})).includes("secret-mac"));
});
test("model discovery validates HTTP and does not pretend to verify a completion",async()=>{
  const server=http.createServer((req,res)=>{if(req.headers.authorization!=="Bearer test-key"){res.writeHead(401);return res.end();}res.setHeader("Content-Type","application/json");res.end(JSON.stringify({data:[{id:"loaded-model"}]}));});
  await new Promise(resolve=>server.listen(0,"127.0.0.1",resolve));
  try{const n={baseUrl:`http://127.0.0.1:${server.address().port}/v1`,apiKey:"test-key"};assert.deepEqual(await core.models(n),[{id:"loaded-model",vision:false}]);await assert.rejects(()=>core.models({...n,apiKey:"wrong"}),/401/);}finally{await new Promise(resolve=>server.close(resolve));}
});
test("active preset label describes selected settings and ignores object key order",()=>{
  const preset=core.validate(selected,state),snapshot={...state,selected:preset,presets:{Campaign:{...preset}},activePreset:"Campaign"};
  assert.equal(core.publicState(snapshot).activePreset,"Campaign");
  snapshot.presets.Campaign=Object.fromEntries(Object.entries(preset).reverse());
  assert.equal(core.publicState(snapshot).activePreset,"Campaign");
  snapshot.selected={...preset,map:"Altis"};
  assert.equal(core.publicState(snapshot).activePreset,"");
  assert.equal(snapshot.activePreset,"Campaign");assert.equal(snapshot.presets.Campaign.map,"Australia");
  snapshot.selected=preset;snapshot.presets.Campaign={...preset,parameters:{...preset.parameters,NeroWL_Air:0}};
  assert.equal(core.publicState(snapshot).activePreset,"");
  snapshot.presets.Campaign={...preset,primaryNode:"deleted-node"};
  assert.equal(core.publicState(snapshot).activePreset,"");
});
test("saving a changed selection clears stale names without rewriting presets, including special object keys",()=>{
  const vm=require('node:vm'),source=fs.readFileSync(require('node:path').join(__dirname,'core.js'),'utf8');
  let snapshot={...structuredClone(state),selected:core.validate(selected,state),presets:{Campaign:core.validate(selected,state)},activePreset:'Campaign'},writes=0;
  const context=vm.createContext({require,load:()=>snapshot,validate:core.validate,publicState:core.publicState,profileFile:'isolated',atomic:(file,value)=>{writes++;snapshot=value;}});
  vm.runInContext(source.slice(source.indexOf('function selectedPresetName('),source.indexOf('function addNode(')),context);
  context.changed={...selected,map:'Altis'};vm.runInContext('saveSelected(changed)',context);
  assert.equal(writes,1);assert.equal(snapshot.activePreset,'');assert.equal(snapshot.presets.Campaign.map,'Australia');
  const prototype=Object.getPrototypeOf(snapshot.presets);vm.runInContext('saveSelected(changed,"__proto__")',context);
  assert.equal(Object.getPrototypeOf(snapshot.presets),prototype);assert(Object.hasOwn(snapshot.presets,'__proto__'));assert.equal(snapshot.presets.__proto__.map,'Altis');
});
test("launch script guards live game and installs only isolated scenario artifacts",()=>{
  const source=fs.readFileSync(require("node:path").join(__dirname,"launch.ps1"),"utf8");
  assert(source.indexOf('if ($games.Count)')<source.indexOf('Copy-Item'));
  assert(source.includes("{'@NeroAI_Warlords'} else {'@NeroAI_Antistasi'}"));assert(!source.includes('NeroAI4.pbo'));assert(!source.includes('Remove-Item'));
});
