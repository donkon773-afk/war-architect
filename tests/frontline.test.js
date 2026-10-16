'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const root=path.join(__dirname,'..'),base=path.join(root,'addons/NeroAI3/functions');
test('production topology, capture rules and HQ allocation execute in SQF-VM; native FSM scripts parse',()=>{
 const r=require('../tools/verify-frontline-sqf').verify();assert.equal(r.parsedFiles,11);assert.equal(r.parsedIntegrationFiles,7);assert.equal(r.parsedNativeConfigs,2);assert(r.parsedNativeScripts>=100);assert(r.assertions>=24);
});
test('frontline functions and native FSM adapters are registered',()=>{
 const files=fs.readdirSync(path.join(base,'frontline')).filter(n=>/^fn_.*\.sqf$/.test(n)).map(n=>n.slice(3,-4)).sort();
 const cfg=fs.readFileSync(path.join(base,'CfgFunctions.hpp'),'utf8'),block=cfg.slice(cfg.indexOf('class frontline {'),cfg.indexOf('class bootstrap {'));
 assert.deepEqual([...block.matchAll(/class (\w+) \{\};/g)].map(m=>m[1]).sort(),files);
 for(const name of ['WLAICore','WLSectorHandleServer'])assert(cfg.includes(`class ${name} {file="\\NeroWL\\functions\\native\\fn_${name}.fsm";ext=".fsm";};`));
});
test('generated native files match their source adapters; HQ defense has a release transition',()=>{
 const adapt=require('../tools/adapt-frontline');
 for(const [name,fn] of [['fn_WLAICore.fsm',adapt.adaptCore],['fn_WLSectorHandleServer.fsm',adapt.adaptCapture],['fn_WLAIPathSegmentation.sqf',adapt.adaptPath]]){
  assert.equal(fs.readFileSync(path.join(base,'native',name),'latin1'),fn(fs.readFileSync(path.join(root,'research/native/Warlords',name),'latin1')),name);
 }
 const core=fs.readFileSync(path.join(base,'native/fn_WLAICore.fsm'),'latin1');
 assert(!/finalStates\[\]\s*=\s*\{[^}]*"defend_1"/.test(core),'defense is not a permanent terminal state');
 for(const name of ['defend','defend_1']){
  const start=core.indexOf(`/*%FSM<STATE "${name}">*/`),end=core.indexOf('/*%FSM</STATE>*/',start),state=core.slice(start,end);
  assert.match(state,/class reconsider \{priority=5;to="status_";/,name+' is reconsidered');assert.match(state,/class nero_owned/);
 }
 assert(core.includes('class nero_controlled {'));assert(core.includes('class released {priority=20;to="status_";'));
 assert(fs.readFileSync(path.join(root,'tools/build-australia-mission.js'),'utf8').includes('require("./adapt-frontline").write(root);'),'normal mission builds regenerate the native adapters');
});
