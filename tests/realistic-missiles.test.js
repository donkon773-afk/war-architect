'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),cp=require('node:child_process');
const build=require('../tools/build-missile-profiles-addon'),parse=require('../tools/validate-mission').parseConfig;
const mods=()=>JSON.parse(fs.readFileSync('control-center/data/operations-launch.json','utf8')).mods;

test('ammunition overrides define patched parents before their children regardless of profile order',()=>{
 const child='class Child:Parent {maxSpeed=1;};',parent='class Parent:External {maxSpeed=2;};',grandchild='class Grandchild:Child {maxSpeed=3;};';
 assert.deepEqual(build.orderOverrides([grandchild,child,parent]),[parent,child,grandchild]);
 assert.throws(()=>build.orderOverrides(['class A:B {};','class B:A {};']),/Cyclic/);
 const r=build.prepare(mods()),ammo=parse(r.config,{rejectDuplicateDeclarations:true}).classes.CfgAmmo.classes;
 const order=Object.keys(ammo).map(x=>x.toLowerCase());
 for(const [name,row] of Object.entries(ammo))if(row.parent&&order.includes(row.parent.toLowerCase()))assert(order.indexOf(row.parent.toLowerCase())<order.indexOf(name.toLowerCase()),name+' uses its base before declaration');
 assert(r.config.indexOf('class rhs_ammo_kh55sm:')<r.config.indexOf('class rhs_ammo_kh55sh:'));
});
test('selected installed missiles get finite profiles while Flamingo, native artillery and child warheads are protected',()=>{
 const r=build.prepare(mods()),c=parse(r.config,{rejectDuplicateDeclarations:true});assert(r.classes>=15);
 assert(!/Flamingo/i.test(r.config));assert.equal(c.classes.CfgAmmo.classes.TT_kh47m2.values.maxSpeed,2800);
 assert.equal(c.classes.CfgAmmo.classes.TT_kh47m2.values.manualControl,1);assert.equal(c.classes.CfgAmmo.classes.TT_kh47m2.classes.ace_missileguidance.values.enabled,0);
 assert.equal(c.classes.CfgAmmo.classes.TT_kh101.values.maxSpeed,195);assert.equal(c.classes.CfgAmmo.classes.TT_3m55.values.maxSpeed,680);assert(c.classes.CfgAmmo.classes.TT_kh47m2.values.hit>0);
 for(const name of ['OFP_M57_HE','rhs_ammo_mgm140a_rocket','rhs_ammo_mgm140b_rocket'])if(c.classes.CfgAmmo.classes[name]){const v=c.classes.CfgAmmo.classes[name].values;assert(!('maxSpeed' in v));assert(!('submunitionAmmo' in v));assert(!('hit' in v));}
 assert(!c.classes.CfgMagazines);assert.equal(c.classes.CfgNeroMissileProfiles.classes.RHS_9M79B.values.range,70000);assert.equal(c.classes.CfgAmmo.classes.RHS_9M79B.values.NeroMS_wholeMap,0);
 assert.equal(c.classes.CfgAmmo.classes.rhs_ammo_kh55sm.values.hit,undefined);
 const vanilla=build.prepare([]);assert.equal(vanilla.classes,2);assert(!vanilla.config.includes('class TT_'));
});
test('edited profile limits reject invalid identifiers, duplicate ammunition and impossible speed/boost values',()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'nero-ms-schema-'));try{const file=path.join(dir,'profiles.json'),original=build.profiles();for(const mutate of [d=>d.profiles[0].maximum=99999,d=>d.profiles[0].boostSeconds=0,d=>d.profiles[0].ammo.push('Flamingo_CruiseMissile'),d=>d.profiles[0].ammo.push('bad;class'),d=>d.profiles[0].ammo.push('TT_agm158')]){const d=structuredClone(original);mutate(d);fs.writeFileSync(file,JSON.stringify(d));assert.throws(()=>build.profiles(file));}}finally{fs.rmSync(dir,{recursive:true,force:true});}
});
test('Kinzhal curve executes boost, short-map scaling and terminal drag in SQF-VM; affected scripts parse',()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'nero-ms-sqf-')),exe=path.resolve('tools/vendor/sqfvm-2026.04.03/runtime/sqfvm_windows_x64/sqfvm.exe');try{
 const code='profile={'+fs.readFileSync('addons/NeroMissileProfiles/functions/fn_curve.sqf','utf8')+'};'+`private _assert={params ["_v"];if (!_v) then {throw "MISSILE CURVE ASSERT";};};
 private _start=[0,0,100000,500,2800,18] call profile;[(_start#0)==500] call _assert;[(_start#1)==0] call _assert;
 private _boost=[18,.5,100000,500,2800,18] call profile;[abs((_boost#0)-2800)<.001] call _assert;[abs((_boost#1)-30000)<.01] call _assert;
 private _impact=[50,1,100000,500,2800,18] call profile;[abs((_impact#0)-2100)<.001] call _assert;[(_impact#1)==0] call _assert;
 private _short=[18,.5,10000,500,2800,18] call profile;[(_short#0)<(_boost#0)] call _assert;[abs((_short#1)-3000)<.01] call _assert;
 private _negative=[-1,-1,10000,500,2800,18] call profile;[(_negative#0)==500] call _assert;
 diag_log "MISSILE_CURVE_OK";`;
 let file=path.join(dir,'curve.sqf');fs.writeFileSync(file,code);let r=cp.spawnSync(exe,['-a','--suppress-welcome','--input-sqf',file],{encoding:'utf8',timeout:15000});assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout+r.stderr,/MISSILE_CURVE_OK/);assert.doesNotMatch(r.stdout+r.stderr,/\[(ERR|FAT)\]/);
 const files=[...fs.readdirSync('addons/NeroMissileProfiles/functions').map(f=>'addons/NeroMissileProfiles/functions/'+f),'tools/campaign-assets/fn_campaignAirDefense.sqf','tools/campaign-assets/fn_campaignMissileEngage.sqf','tools/campaign-assets/fn_campaignCruiseTrack.sqf','tools/campaign-assets/fn_campaignFinish.sqf','tools/campaign-assets/fn_campaignSensors.sqf','tools/campaign-assets/fn_campaignCountermeasure.sqf'];for(const source of files){fs.copyFileSync(source,file);r=cp.spawnSync(exe,['-a','--suppress-welcome','--parse-only','--input-sqf',file],{encoding:'utf8',timeout:15000});assert.equal(r.status,0,source+'\n'+r.stdout+r.stderr);assert.doesNotMatch(r.stdout+r.stderr,/\[(ERR|FAT)\]/);}
 }finally{fs.rmSync(dir,{recursive:true,force:true});}
});
test('Patriot BMD removes native speed rejection while retaining local/radar ranges and finite ammo',()=>{
 const r=require('../tools/build-air-defense-addon').prepare(mods(),{patriotBMD:true}),c=parse(r.config);assert.equal(c.classes.CfgNeroAirDefense.values.patriotBMD,1);
 for(const prefix of ['NeroAD_B_','NeroAD_R_']){const a=c.classes.CfgAmmo.classes[prefix+'ace_missile_sam_patriot'];assert(a);assert.equal(a.values.missileLockMaxSpeed,4000);assert.equal(a.values.maxSpeed,1600);assert.equal(a.values.maneuvrability,40);assert.equal(a.values.missileLockMaxDistance,prefix==='NeroAD_B_'?4500:16000);}
 for(const mag of Object.values(c.classes.CfgMagazines.classes).filter(x=>!x._forward))assert.equal(mag.values.count,undefined);
 assert.equal(c.classes.CfgNeroAirDefense.classes.B_SAM_System_03_F.values.localRange,4500);
 const radar=Object.values(c.classes.CfgVehicles.classes).find(x=>x.classes?.Components?.classes?.SensorsManagerComponent?.classes?.Components?.classes?.ActiveRadarSensorComponent?.values.maxTrackableSpeed===4000);assert(radar);
});
test('Patriot evidence report cannot convert missing or unresolved trials into a success claim',()=>{
 const {analyze}=require('../tools/analyze-patriot-trials'),header='trial,condition,flight_id,outcome,interceptors,notes\n';assert.equal(analyze(header).measured,false);
 let text=header;for(let i=0;i<100;i++)text+=`${i},radar-open,id${i},${i<55?'intercept':'impact'},2,"observed, real trial"\n`;
 const g=analyze(text).conditions[0];assert.equal(g.rate,.55);assert(g.wilson95[0]<.55&&g.wilson95[1]>.55);assert(g.targetObserved);
 assert.equal(analyze(text+'101,radar-open,pending,unresolved,0,\n').conditions[0].targetObserved,false);
 assert.throws(()=>analyze(text+'102,radar-open,id1,impact,1,\n'),/duplicated/);
});
