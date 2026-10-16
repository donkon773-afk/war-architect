'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
for(const mode of ['campaign','ground']){
 test(mode+' imports large and automatic setup rosters without the old faction/8-class filter',()=>{
  const source=fs.readFileSync('control-center/'+mode+'-operations-ui.js','utf8'),start=source.indexOf('function setupInfantry('),end=source.indexOf('function renderFleets(){',start);
  const catalog=Array.from({length:1200},(_,i)=>({class:'Unit'+i,side:'WEST',faction:'NewFaction'}));catalog.push({class:'Enemy',side:'EAST',faction:'NewFaction'});
  const context=vm.createContext({bootstrap:{catalog}});vm.runInContext(source.slice(start,end),context);
  const call=setup=>context.setupInfantry({setup},'WEST');
  assert.equal(call({infantry:catalog.map(c=>c.class),faction:'NewFaction'}).ids.length,1200);
  assert.equal(call({infantry:null,faction:'NewFaction'}).ids.length,1200);
  assert.equal(call({infantry:['Unit0','Unit0','Missing','Enemy']}).skipped,2);
  assert.throws(()=>call({infantry:['Missing']}),/Текущий выбор сохранён/);
 });
 test(mode+' saves large infantry catalogs independently of physical squad size',()=>{
  const module=require('../control-center/'+mode+'-operations'),d=module.defaults(),a=d.sides[0];a.faction='';a.classes=module.catalog().filter(c=>c.side===a.side).slice(0,1200).map(c=>c.class);assert.equal(a.classes.length,1200);
  assert.equal(module.validate(d).sides[0].classes.length,1200);
  a.classes.push('MissingClass');assert.throws(()=>module.validate(d),/пехоты/);
 });
}
