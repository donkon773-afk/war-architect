'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const schema=require('../control-center/scenario-design'),editor=require('../control-center/warlords-editor');
test('resource limits accept chosen positive counts beyond the old 48/240 ceilings',()=>{
 const d=schema.blank('Australia');d.sectors=[{id:'town',name:'Town',side:'GUER',position:[12000,16000],radius:250,infantry:12,vehicles:0,vehicleClasses:[]}];d.maxVehicles=128;d.maxNPCs=1000;
 assert.equal(schema.validate(d).maxVehicles,128);assert.equal(schema.validate(d).maxNPCs,1000);
 for(const bad of [-1,0,1.5,NaN])assert.throws(()=>schema.validate({...d,maxVehicles:bad}),/Общий лимит техники/);
});
test('map drafts preserve mixed and unavailable catalogs and incomplete plans, launch validation stays strict',()=>{
 const d=schema.blank('Australia');d.maxVehicles=128;d.army=editor.defaults();d.army.westAssets=['O_MBT_02_cannon_F','Missing_Tank'];d.army.westInfantry=['Missing_Infantry'];d.army.westInfantryCosts={Missing_Infantry:200};
 const saved=schema.validate(d,[],{draft:true});assert.deepEqual(saved.army.westAssets,d.army.westAssets);assert.deepEqual(saved.army.westInfantry,d.army.westInfantry);assert.equal(saved.sectors.length,0);
 assert.throws(()=>schema.validate(saved),/Каталог содержит/);
});
test('map preset storage round-trips a draft without dropping any chosen equipment',()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'nero-map-drafts-'));
 try{const designs={...schema,load:()=>schema.blank('Australia')},store=require('../control-center/map-presets').createStore(dir,designs),d=schema.blank('Australia');d.maxVehicles=96;d.maxNPCs=500;d.army=editor.defaults();d.army.greenAssets=['B_MBT_01_cannon_F','Missing_Tank'];const record=store.save('Draft',d,[]);const back=store.get(record.id);assert.deepEqual(back.design.army.greenAssets,d.army.greenAssets);assert.equal(back.design.maxVehicles,96);assert.equal(back.design.maxNPCs,500);}
 finally{if(path.dirname(dir)!==path.resolve(os.tmpdir())||!path.basename(dir).startsWith('nero-map-drafts-'))throw Error('Unexpected test path');fs.rmSync(dir,{recursive:true,force:true});}
});
