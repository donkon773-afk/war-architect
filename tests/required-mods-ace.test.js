'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os'),cp=require('node:child_process');
const policy=require('../control-center/operation-mod-policy'),required=require('../control-center/operation-required-mods');
test('mandatory mod policy cannot be cleared by extraMods and follows enabled missile mechanics',()=>{
 const inventory=require('../control-center/warlords-editor').inventory(),d=require('../control-center/campaign-operations').defaults();d.extraMods=[];let rows=required.resolve(d,inventory);assert(rows.some(r=>r.key==='ace'));assert(!rows.some(r=>r.key==='tt'));
 d.devMode.realisticMissiles=true;rows=required.resolve(d,inventory);for(const k of ['ace','cba','fp5','rhsafrf','tt','rhsusaf','fmc','3cb','strategic','ad','missiles'])assert(rows.some(r=>r.key===k),k);
 const mods=require('../control-center/operations').modPaths(d);for(const r of rows.filter(r=>!r.generated))assert(mods.includes(r.id),r.label);assert.deepEqual(d.extraMods,[]);
 assert(!policy.requirements({type:'airBattle',extraMods:[]},inventory.mods).some(r=>r.key==='fp5'));
});
test('missing required mod and incomplete ACE files stop resolution without touching installed mods',()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'nero-mod-required-'));try{const mods=policy.requirements({type:'airBattle'},[]).map(r=>{const p=path.join(dir,r.key);fs.mkdirSync(path.join(p,'addons'),{recursive:true});for(const file of r.files)fs.writeFileSync(path.join(p,'addons',file),'fixture');return {name:r.name,path:p,patches:[r.patch]};});assert.equal(required.resolve({type:'airBattle'},{mods}).length,2);
 assert.throws(()=>required.resolve({type:'airBattle'},{mods:mods.slice(1)}),/ACE/);
 fs.unlinkSync(path.join(mods[0].path,'addons/ace_main.pbo'));assert.throws(()=>required.resolve({type:'airBattle'},{mods}),/неполный.*ace_main/);
 }finally{fs.rmSync(dir,{recursive:true,force:true});}
});
test('a stale artifact cannot launch after mandatory base or generated mechanics have been removed',()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'nero-mod-artifact-'));try{const design=require('../control-center/campaign-operations').defaults();fs.writeFileSync(path.join(dir,'operation.json'),JSON.stringify(design));const mods=require('../control-center/operations').modPaths(design),a={output:dir,extraMods:mods,addonArtifacts:[]};assert.throws(()=>required.verifyArtifact(a),/обязательный аддон/);a.extraMods=mods.filter(p=>!p.endsWith('@ace'));assert.throws(()=>required.verifyArtifact(a),/ACE/);}finally{fs.rmSync(dir,{recursive:true,force:true});}
});
test('ACE ownership gates and partial repair execute without restoring ERA or damaging healthy components',()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'nero-ace-repair-'));try{let code='';for(const [name,file] of [['repair','tools/campaign-assets/fn_campaignRepairPlan.sqf'],['engineer','tools/campaign-assets/fn_campaignEngineerGate.sqf']])code+=name+'={'+fs.readFileSync(file,'utf8')+'};';code+=`private _a={params ["_v"];if (!_v) then {throw "ACE COMPAT ASSERT";};};
 [([false,true] call engineer)] call _a;[([false,2] call engineer)] call _a;[([true,false] call engineer)] call _a;[!([false,0] call engineer)] call _a;[!([false,"true"] call engineer)] call _a;
 private _r=[.05,["HitWheel","era_1_hitpoint","HitEngine","HitHull"],[.05,1,.6,.9]] call repair;
 [abs((_r#0)-.05)<.001] call _a;[abs(((_r#1)#0)-.05)<.001] call _a;[((_r#1)#1)==1] call _a;[abs(((_r#1)#2)-.35)<.001] call _a;[abs(((_r#1)#3)-.9)<.001] call _a;
 diag_log "ACE_REPAIR_OK";`;
 const file=path.join(dir,'test.sqf'),exe=path.resolve('tools/vendor/sqfvm-2026.04.03/runtime/sqfvm_windows_x64/sqfvm.exe');fs.writeFileSync(file,code);let r=cp.spawnSync(exe,['-a','--suppress-welcome','--input-sqf',file],{encoding:'utf8',timeout:15000});assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout+r.stderr,/ACE_REPAIR_OK/);assert.doesNotMatch(r.stdout+r.stderr,/\[(ERR|FAT)\]/);
 for(const source of ['tools/campaign-assets/fn_campaignFieldRepair.sqf','tools/campaign-assets/fn_campaignTacticalTick.sqf']){fs.copyFileSync(source,file);r=cp.spawnSync(exe,['-a','--suppress-welcome','--parse-only','--input-sqf',file],{encoding:'utf8',timeout:15000});assert.equal(r.status,0,r.stdout+r.stderr);assert.doesNotMatch(r.stdout+r.stderr,/\[(ERR|FAT)\]/);}
 }finally{fs.rmSync(dir,{recursive:true,force:true});}
});
test('derived Patriot explicitly disables ACE flight controller after its installed definition',()=>{
 const mods=require('../control-center/operations').modPaths(require('../control-center/campaign-operations').defaults()),c=require('../tools/validate-mission').parseConfig(require('../tools/build-air-defense-addon').prepare(mods,{patriotBMD:true}).config);assert(c.classes.CfgPatches.classes.NeroAirDefense.values.requiredAddons.includes('ace_missile_sam'));
 for(const prefix of ['NeroAD_B_','NeroAD_R_'])assert.equal(c.classes.CfgAmmo.classes[prefix+'ace_missile_sam_patriot'].classes.ace_missileguidance.values.enabled,0);
 const {readEntry}=require('../tools/read-pbo-entry'),ace=mods.find(m=>m.endsWith('@ace')),source=readEntry(path.join(ace,'addons/ace_missileguidance.pbo'),'functions/fnc_onFired.sqf').toString('utf8');assert(source.includes('"enabled")) != 1) exitWith {}'));assert(source.includes('!local _projectile'));
});
test('AI G-force adapter uses the setting exposed by the installed ACE version',()=>{
 const {readEntry}=require('../tools/read-pbo-entry'),p='H:/SteamLibrary/steamapps/common/Arma 3/!Workshop/@ace/addons/ace_gforces.pbo',settings=readEntry(p,'initSettings.inc.sqf').toString('utf8');assert(settings.includes('QGVAR(coef)'));const source=fs.readFileSync('tools/operation-common/fn_aiGforces.sqf','utf8');assert(source.includes('"ace_gforces_coef"'));assert(!source.includes('ace_gforces_gforcesCoef'));
});
