'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const dev=require('../control-center/dev-mode'),parse=require('../tools/validate-mission').parseConfig;
test('old profiles retain active mechanics; explicit master off disables experiments without losing choices',()=>{
  assert.deepEqual(dev.effective({}),{transportDrop:true,vehicleCrew:true,fieldRepair:true});
  const mode=dev.normalize({enabled:false,features:{fieldRepair:true,vehicleCrew:false}});
  assert.equal(mode.features.fieldRepair,true);
  assert.deepEqual(dev.effective({devMode:mode}),{transportDrop:false,vehicleCrew:false,fieldRepair:false});
  assert.deepEqual(dev.effective({devMode:{...mode,enabled:true}}),{transportDrop:true,vehicleCrew:false,fieldRepair:true});
});
test('DevMode rejects malformed flags and unknown updates',()=>{
  for(const v of [null,[],true,{}, {enabled:'yes'}, {enabled:true,features:[]},{enabled:true,features:{vehicleCrew:1}},{enabled:true,features:{injected:true}}])assert.throws(()=>dev.normalize(v),/DevMode/);
});
test('new opt-in entries default off; stable promotion uses the ordinary setting independently of the DevMode master',()=>{
  const entries=[{id:'future',field:'future',stage:'experimental',default:false},{id:'verified',field:'verified',stage:'stable',default:true,parameter:'NeroWL_Verified'}];
  assert.deepEqual(dev.effective({},entries),{future:false,verified:true});
  assert.deepEqual(dev.effective({devMode:{enabled:false,features:{verified:false}},parameters:{NeroWL_Verified:1}},entries),{future:false,verified:true});
  assert.equal(dev.effective({parameters:{NeroWL_Verified:0}},entries).verified,false);
  assert.equal(dev.effective({devMode:{enabled:false,features:{verified:false}}},entries).verified,false);
});
test('mission config contains explicit effective values, consumed before settings-ready signal',()=>{
  const config=parse(dev.config({devMode:{enabled:true,features:{vehicleCrew:false,fieldRepair:false}}}));
  const c=config.classes.CfgNeroExperiments.values;
  assert.equal(c.transportDrop,1);assert.equal(c.vehicleCrew,0);assert.equal(c.fieldRepair,0);
  const sqf=fs.readFileSync('tools/mission-assets/fn_applySettings.sqf','utf8');
  assert(sqf.indexOf('NeroAI_transportDropEnabled')<sqf.indexOf('NeroWL_settingsApplied = true'));
});
test('core validation keeps DevMode selections in a launch profile',()=>{
  const core=require('../control-center/core'),state=core.load(),s={...state.selected,devMode:{enabled:true,features:{transportDrop:false,vehicleCrew:true,fieldRepair:false}}};
  const valid=core.validate(s,state,{draft:true});
  assert.deepEqual(valid.devMode,s.devMode);
  assert.deepEqual(core.validate(JSON.parse(JSON.stringify(valid)),state,{draft:true}).devMode,s.devMode);
});
test('three-side mission generator writes explicit DevMode config to an isolated temporary mission',()=>{
  const os=require('node:os'),path=require('node:path'),schema=require('../control-center/scenario-design'),core=require('../control-center/core');
  const state=core.load(),d=schema.load(state.selected.map),out=fs.mkdtempSync(path.join(os.tmpdir(),'nero-devmode-mission-'));
  const design=structuredClone(d);design.mode='three';
  if(!design.bases.some(b=>b.side==='GUER'))design.bases.push({...design.bases[0],id:'qa-green',side:'GUER'});
  try{
    require('../tools/build-three-mission').build(design,{...state.selected,army:d.army,devMode:{enabled:false,features:{}}},out,'',[]);
    const mission=parse(fs.readFileSync(path.join(out,'description.ext'),'utf8'));
    assert.deepEqual(mission.classes.CfgNeroExperiments.values,{transportDrop:0,vehicleCrew:0,fieldRepair:0});
    assert(fs.readFileSync(path.join(out,'neroDesign/fn_applySettings.sqf'),'utf8').includes('NeroAI_groundPurchaseCrew'));
  }finally{fs.rmSync(out,{recursive:true,force:true});}
});
