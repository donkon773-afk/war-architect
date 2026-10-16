'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const schema=require('../control-center/scenario-design'),editor=require('../control-center/warlords-editor'),builder=require('../tools/build-three-mission'),design=require('../tools/build-designed-mission'),validator=require('../tools/validate-mission');
test('CQ production SQF parses and executes catalog, quote, ballot and replay regression cases',()=>{
 const result=require('../tools/verify-cq-sqf').verify();assert.equal(result.parsedFiles,18);assert.equal(result.assertions,79);assert.equal(result.engineUiExecuted,false);
});
test('three combat sides and the observer receive every UI function and server-only operations',()=>{
 for(const [role,side]of [['commander','WEST'],['commander','EAST'],['commander','GUER'],['observer','WEST']]){
  const temp=fs.mkdtempSync(path.join(os.tmpdir(),'nero-cq-mission-'));
  try{
   const army=editor.defaults(),d=schema.validate({...schema.blank('btrx_sngt'),mode:'three',playerRole:role,playerSide:side,army,greenFaction:army.greenFaction,bases:[{id:'w',name:'W',side:'WEST',position:[5000,5000],radius:200},{id:'e',name:'E',side:'EAST',position:[17000,17000],radius:200},{id:'g',name:'G',side:'GUER',position:[5000,17000],radius:200}],sectors:[{id:'a',name:'A',side:'GUER',position:[10000,10000],radius:200,infantry:12,vehicles:0,vehicleClasses:[]}]});
   builder.build(d,{army,commanders:10,parameters:{}},temp,design.designConfig(d));
   assert.equal(validator.validateDirectory(temp).slots,role==='observer'?31:30);
   const description=fs.readFileSync(path.join(temp,'description.ext'),'utf8'),parsed=validator.parseConfig(description);
   assert.equal(parsed.values.NeroWL_cqInterface,2);
   assert.doesNotMatch(fs.readFileSync(path.join(temp,'mission.sqm'),'utf8'),/ModuleWLInit_F/);
   for(const fn of builder.runtimeFunctions)assert.equal(fs.readFileSync(path.join(temp,'neroDesign','fn_'+fn+'.sqf'),'utf8'),fs.readFileSync(path.join(__dirname,'../tools/designer-assets','fn_'+fn+'.sqf'),'utf8'));
   const missing=path.join(temp,'neroDesign/fn_cqMenuAction.sqf');fs.renameSync(missing,missing+'.saved');
   assert.throws(()=>validator.validateDirectory(temp),/function missing: cqMenuAction/);fs.renameSync(missing+'.saved',missing);
   const savedAction=fs.readFileSync(missing,'utf8');fs.appendFileSync(missing,'\ncall NeroWL_Design_fnc_cqMissing;');assert.throws(()=>validator.validateDirectory(temp),/callback unregistered: cqMissing/);fs.writeFileSync(missing,savedAction);
   fs.writeFileSync(path.join(temp,'description.ext'),description.replace('class NeroWL_Design_fnc_cqVote {allowedTargets=2;}','class NeroWL_Design_fnc_cqVote {allowedTargets=0;}'));
   assert.throws(()=>validator.validateDirectory(temp),/must target server: cqVote/);
  }finally{
   assert.equal(path.dirname(temp),path.resolve(os.tmpdir()));assert(path.basename(temp).startsWith('nero-cq-mission-'));fs.rmSync(temp,{recursive:true,force:true});
  }
 }
});
