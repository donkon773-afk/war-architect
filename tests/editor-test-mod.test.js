'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process'),os=require('node:os');
const root=path.resolve(__dirname,'..'),mod=path.join(root,'dist/editor-test/@NeroAI_Operations_Test'),{parseConfig}=require('../tools/validate-mission');
test('editor opt-in has executable module and isolated, editable complete campaign templates',()=>{
 const m=JSON.parse(fs.readFileSync(path.join(mod,'manifest.json'))),c=parseConfig(fs.readFileSync(path.join(mod,'source/config.cpp'),'utf8'));
 assert.equal(c.classes.CfgVehicles.classes.NeroSandbox_Module.values.isGlobal,2);assert.equal(c.classes.CfgVehicles.classes.NeroSandbox_Module.values.function,'NeroSandbox_fnc_enable');
 assert.equal(c.classes.CfgFunctions.classes.NeroSandbox.classes.Editor.classes.enable.values.postInit,undefined);
 assert.ok(c.classes.CfgFunctions.classes.NeroSandbox.classes.Editor.classes.airCombat);assert.ok(c.classes.CfgFunctions.classes.NeroSandbox.classes.Editor.classes.campaignMissileEngage);
 assert.ok(m.missions.length>=3);assert(m.missions.some(x=>x.world==='australia'));
 for(const mission of m.missions){const template=path.join(mod,'EdenTemplates',mission.name);assert(fs.existsSync(path.join(template,'mission.sqm')));require('../tools/validate-operation').validate(template);const cfg=parseConfig(fs.readFileSync(path.join(template,'description.ext'),'utf8'));if(cfg.classes.CfgNeroOperation?.values.type==='frontlineCampaign'){assert.equal(cfg.classes.CfgNeroOperation.values.persistence,0);assert.notEqual(cfg.classes.CfgNeroOperation.values.saveSignature,'6cc32e1217bb');}}
 for(const fn of m.functions)assert(fs.existsSync(path.join(mod,'source/functions/fn_'+fn+'.sqf')));
});
test('standalone module source parses with the same SQF engine parser as campaign functions',()=>{
 const folder=path.join(mod,'source/functions'),files=fs.readdirSync(folder).filter(x=>x.endsWith('.sqf'));const temp=fs.mkdtempSync(path.join(os.tmpdir(),'nero-eden-parse-'));try{for(const f of files)fs.copyFileSync(path.join(folder,f),path.join(temp,f));const r=cp.spawnSync(path.join(root,'tools/vendor/sqfvm-2026.04.03/runtime/sqfvm_windows_x64/sqfvm.exe'),['-a','--suppress-welcome','--parse-only',...files.flatMap(f=>['--input-sqf',f])],{cwd:temp,encoding:'utf8',windowsHide:true,timeout:15000,maxBuffer:1024*1024});assert.equal(r.status,0,r.stdout+r.stderr);assert.doesNotMatch(r.stdout+r.stderr,/\[(ERR|FAT)\]/);}finally{if(path.dirname(temp)!==path.resolve(os.tmpdir())||!path.basename(temp).startsWith('nero-eden-parse-'))throw Error('Unexpected test temp path');fs.rmSync(temp,{recursive:true,force:true});}
});
