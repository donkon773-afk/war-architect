'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {list}=require('../control-center/scenario-library');
test('library joins separate stores without changing ids or leaking launch credentials',()=>{
  const input={maps:[{id:'map-a',name:'Город',world:'altis',sectors:5,bases:2,mode:'native'}],operations:[{id:'air-a',title:'Воздух',world:'altis',type:'airBattle'},{id:'ground-a',title:'Штурм',world:'altis',type:'assaultDefense'},{id:'campaign-a',title:'Фронт',world:'altis',type:'frontlineCampaign'}],state:{nodes:[{apiKey:'SECRET'}],presets:{Test:{scenario:'antistasi',map:'altis',apiKey:'SECRET'}}},worlds:[{id:'altis',label:'Алтис'}]};
  const before=JSON.stringify(input),result=list(input);
  assert.equal(JSON.stringify(input),before);assert.deepEqual(result.counts,{maps:1,operations:3,profiles:1});
  assert.equal(result.items.length,5);assert.equal(result.items[0].worldLabel,'Алтис');assert.equal(result.items[0].id,'map-a');
  assert.equal(new Set(result.items.map(r=>r.key)).size,5);assert(!JSON.stringify(result).includes('SECRET'));
  assert.deepEqual(result.items.filter(r=>r.kind==='operation').map(r=>r.mode),['airBattle','assaultDefense','frontlineCampaign']);
});
test('same titles remain independently addressable and unavailable map labels retain their ids',()=>{
  const r=list({maps:[],operations:[{id:'a',title:'Операция',world:'old-map',type:'airBattle'},{id:'b',title:'Операция',world:'old-map',type:'airBattle'}],state:{presets:{}},worlds:[]});
  assert.deepEqual(r.items.map(p=>p.id),['a','b']);assert.equal(r.items[0].worldLabel,'old-map');
});
