"use strict";
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const core=require('../control-center/core'),schema=require('../control-center/scenario-design'),builder=require('../tools/build-designed-mission');
const {parseConfig,validateDirectory}=require('../tools/validate-mission');

test('Posadkovo resolves the RHS terrain models provider even when its manifest omits it',()=>{
 const state=core.load(),d=schema.load('m_36tuu484111s99');
 assert(builder.mods(d,state.selected.army).some(p=>p.endsWith('@RHSTERRACORE')));
 assert.throws(()=>require('../control-center/map-mod-dependencies').requiredPaths(d.world,[]),/rhs_structures_data/);
});

test('native and three-side builds use supplied army and lobby settings instead of stale global defaults',()=>{
 const state=core.load();state.selected.commanders=12;state.selected.parameters={...state.selected.parameters,NeroWL_Air:0,BIS_WLMaxSubordinates:12};
 const editor=require('../control-center/warlords-editor');state.selected.army=editor.validate(state.selected.army);state.selected.army.westInfantry=[editor.infantry(state.selected.army,'west')[0].class];
 const d=schema.blank('Australia');d.playerRole='observer';d.sectors=[{id:'audit_town',name:'Audit',side:'GUER',position:[12000,16000],radius:250,infantry:6,vehicles:0,vehicleClasses:[]}];
 for(const mode of ['native','three']){
  d.mode=mode;if(mode==='three')d.bases.push({id:'green',name:'Green',side:'GUER',position:[20000,20000],radius:200});
  const m=builder.build(d,state),folder=mode==='native'?'neroWL':'neroDesign';
  const params=parseConfig(fs.readFileSync(path.join(m.output,folder,'params.hpp'),'utf8')).classes.Params.classes;
  assert.equal(params.NeroWL_Air.values.default,0);assert.equal(params.BIS_WLMaxSubordinates.values.default,12);
  assert.equal(validateDirectory(m.output).slots,mode==='native'?25:37);
  const catalog=parseConfig(fs.readFileSync(path.join(m.output,folder,mode==='native'?'startPreset.hpp':'preset.hpp'),'utf8'));
  assert.deepEqual(Object.keys(catalog.classes.CfgWLRequisitionPresets.classes.NeroWL_RHSStart.classes.WEST.classes.Infantry.classes),state.selected.army.westInfantry);
  if(mode==='three'){
   const loaded=new Set(m.extraMods),assets=editor.inventory().assets,guer=catalog.classes.CfgWLRequisitionPresets.classes.NeroWL_RHSStart.classes.GUER;
   for(const category of Object.values(guer.classes))for(const id of Object.keys(category.classes||{})){
    const a=assets.find(a=>a.class===id);assert(a,`catalog class ${id} exists`);assert(!a.modPath||loaded.has(a.modPath),`catalog provider for ${id} is loaded`);
   }
  }
 }
});

test('LLM diagnostics report validation failures and never accept an invalid run count',async()=>{
 const {benchmark}=require('../tools/benchmark-local-llm'),config={lmStudio:{model:'test',baseUrl:'http://127.0.0.1:1/v1'}};
 let count=0;const result=await benchmark(config,2,async()=>++count===1?'{"version":3,"speech":"Принял.","actions":[]}':'broken JSON');
 assert.equal(result.requests,2);assert.equal(result.results[0].valid,true);assert.equal(result.results[1].valid,false);assert.equal(result.allValid,false);
 await assert.rejects(()=>benchmark(config,6),/1 to 5/);
});

test('air requisition claims the shared side slot before debit and rolls back an over-budget crew',()=>{
 const s=fs.readFileSync('addons/NeroAI3/functions/tactical/fn_purchaseAirAsset.sqf','utf8');
 const lock=s.indexOf('call NeroAI_fnc_claimSidePurchaseSlot'),debit=s.indexOf('_funds - _price - _fee');
 assert(lock>0&&lock<debit);assert(s.includes('private _crewCapacity = ["INFANTRY"] call NeroAI_fnc_designPurchaseCapacity;'));
 const rollback=s.slice(s.indexOf('if (_crew isEqualTo []'),s.indexOf('private _airGroup'));
 assert(rollback.includes('4 min _crewCapacity'));assert(rollback.includes('deleteVehicle _air'));assert(rollback.includes('+ _price + _fee'));
});

test('LLM receives current reserve and the third side role instead of fixed obsolete doctrine',()=>{
 const {SYSTEM_PROMPT,buildMessages}=require('../bridge/lm-studio');
 assert(SYSTEM_PROMPT.includes('snapshot.economy'));assert(SYSTEM_PROMPT.includes('snapshot.greenRole'));
 assert(!SYSTEM_PROMPT.includes('reserve 300 CP'));assert(!SYSTEM_PROMPT.includes('Never raid an army base with heavy vehicles'));
 const s=fs.readFileSync('addons/NeroAI3/functions/core/fn_buildSnapshot.sqf','utf8');
 assert(s.includes('"economy", [missionNamespace getVariable ["NeroAI_purchaseReserveCP",1500]'));assert(s.includes('"greenRole"'));
 assert.equal(buildMessages('[]').length,2);
});

test('three-side objective change cannot clear manual orders or ongoing boarding',()=>{
 const s=fs.readFileSync('tools/designer-assets/fn_cqLoop.sqf','utf8'),start=s.indexOf('private _busy='),clear=s.indexOf('deleteWaypoint',start),guard=s.slice(start,clear);
 assert(start>0&&clear>start);
 for(const key of ['NeroAI_playerHold','NeroAI_manualOrderUntil','NeroWL_logisticsUntil','NeroAI_purchaseHoldUntil','BOARDING','PARTIAL_BOARDING'])assert(guard.includes(key));
 assert(guard.includes('if(!_busy'));
});
