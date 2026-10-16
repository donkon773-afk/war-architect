'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os'),cp=require('node:child_process');
const schema=require('../control-center/campaign-experiments');
test('campaign experiments are opt-in, strictly typed, preserved through validation and emitted in the mission',()=>{
 assert(Object.values(schema.validate()).every(v=>v===false));assert.throws(()=>schema.validate({physicalDrop:1}));assert.throws(()=>schema.validate({arbitrary:true}));
 const campaign=require('../control-center/campaign-operations'),build=require('../tools/build-campaign-operation'),validate=require('../tools/validate-campaign-operation');
 const d=campaign.defaults(),old=build.build(d,fs.mkdtempSync(path.join(os.tmpdir(),'nero-old-')));
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'nero-updates-'));
 try{d.devMode=Object.fromEntries(schema.entries.map(e=>[e.id,true]));const r=build.build(d,dir);assert.equal(r.saveSignature,old.saveSignature);assert.equal(validate.validate(dir).validated,true);const c=require('../tools/validate-mission').parseConfig(fs.readFileSync(path.join(dir,'description.ext'),'utf8')).classes.CfgNeroOperation;
 for(const e of schema.entries)assert.equal(c.classes.DevMode.values[e.id],1);assert(c.classes.WEST.values.deliveryTransport);assert(c.classes.WEST.values.deliveryFighter);assert.equal(r.addonArtifacts.length,3);
 const text=fs.readFileSync(path.join(dir,'description.ext'),'utf8');fs.writeFileSync(path.join(dir,'description.ext'),text.replace('physicalDrop=1','physicalDrop=0'));assert.throws(()=>validate.validate(dir),/DevMode/);
 }finally{fs.rmSync(dir,{recursive:true,force:true});fs.rmSync(old.output,{recursive:true,force:true});}
});
test('production time profile, reserve-force allocation and delivery gates execute in SQF-VM',()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'nero-updates-logic-'));try{
 let code='';for(const [name,file] of [['NeroOP_fnc_campaignAmmoSnapshot','tools/campaign-assets/fn_campaignAmmoSnapshot.sqf'],['NeroOP_fnc_campaignFleetSnapshot','tools/campaign-assets/fn_campaignFleetSnapshot.sqf'],['progress','tools/campaign-assets/fn_campaignProgress.sqf'],['profile','addons/NeroStrategic/functions/fn_fpProfile.sqf'],['plan','tools/campaign-assets/fn_campaignTeamPlan.sqf'],['delivery','tools/campaign-assets/fn_campaignDeliveryGate.sqf']])code+=name+'={'+fs.readFileSync(file,'utf8')+'};\n';
 code+=`private _assert={params ["_v"];if (!_v) then {throw "UPDATE ASSERTION";};};
 [abs(([7,-1] call profile)-277.777778)<.001] call _assert;
 [abs(([3.5,-1] call profile)-161.388889)<.001] call _assert;
 [([100,0] call profile)==277.777778] call _assert;
 [abs(([100,1] call profile)-388.888889)<.001] call _assert;
 [([100,2] call profile)==500] call _assert;
 [([100,10] call profile)==500] call _assert;
 [([10,true,20,10,true] call plan) isEqualTo [3,7,true]] call _assert;
 [([1,true,1,5,true] call plan) isEqualTo [1,0,false]] call _assert;
 [!(([8,false,5,10,true] call plan)#2)] call _assert;
 [([true,true,8,2,false,false,false] call delivery)] call _assert;
 [!([false,true,8,2,true,true,true] call delivery)] call _assert;
 [!([false,true,8,0,true,false,true] call delivery)] call _assert;
 [!([false,true,8,0,true,true,false] call delivery)] call _assert;
 [([false,true,8,1,true,true,true] call delivery)] call _assert;
 private _cut=[-1,[90,20],[2,2],[true,true],2,120,[false,true]] call progress;
 [((_cut#1)#0)==0] call _assert;
 private _row=[0,"car",1,[2000,3000,0],0,0,1,["w","w","w"],true,[],[],[true,"uid"]];
 private _valid={params ["_rows"];[_rows,[2,0],[0,0],[[["car",0,100,"TANK"]],[]],[[0,1,[2000,3000],["w","w"],false,1]],[["w"],["e"]],[2,2],10000,[8,2],24,[1,1]] call NeroOP_fnc_campaignFleetSnapshot};
 [[[_row]] call _valid] call _assert;
 private _legacy=+_row;_legacy resize 11;[!([[_legacy]] call _valid)] call _assert;
 private _bad=+_row;_bad set [7,["e"]];[!([[_bad]] call _valid)] call _assert;
 _bad=+_row;_bad set [11,[false,"uid"]];[!([[_bad]] call _valid)] call _assert;
 _bad=+_row;_bad set [7,[]];_bad set [8,false];_bad set [11,[false,""]];[[[_bad]] call _valid] call _assert;
 diag_log "CAMPAIGN_UPDATES_OK";`;
 const file=path.join(dir,'test.sqf');fs.writeFileSync(file,code);const r=cp.spawnSync(path.resolve('tools/vendor/sqfvm-2026.04.03/runtime/sqfvm_windows_x64/sqfvm.exe'),['-a','--suppress-welcome','--input-sqf',file],{encoding:'utf8',timeout:15000});assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout+r.stderr,/CAMPAIGN_UPDATES_OK/);assert.doesNotMatch(r.stdout+r.stderr,/\[(ERR|FAT)\]/);
 }finally{fs.rmSync(dir,{recursive:true,force:true});}
});
test('radar experiment produces 4.5km local launchers and 16km radar variants without patching original vehicle classes',()=>{
 const mods=JSON.parse(fs.readFileSync('control-center/data/operations-launch.json','utf8')).mods;
 const r=require('../tools/build-air-defense-addon').prepare(mods,{radarNetwork:true}),cfg=require('../tools/validate-mission').parseConfig(r.config,{rejectDuplicateDeclarations:true});
 for(const c of Object.values(cfg.classes.CfgNeroAirDefense.classes)){if(c.values.category==='RADAR')assert.equal(c.values.radarRange,16000);else assert(c.values.localRange<=4500);assert(c.values.spawnClass.startsWith('NeroAD_V_'));}
 for(const [name,c] of Object.entries(cfg.classes.CfgVehicles.classes).filter(([n])=>n.startsWith('NeroAD_V_')))assert.equal(cfg.classes.CfgVehicles.classes[c.parent]._forward,true);
});
