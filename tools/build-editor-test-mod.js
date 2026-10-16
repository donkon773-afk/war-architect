'use strict';
// Explicit opt-in Eden module + editable test missions. Never replace installed missions.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),out=path.join(root,'dist/editor-test/@NeroAI_Operations_Test'),source=path.join(out,'source');
const functions=['campaignAirDefense','campaignADGate','campaignADFuse','campaignADMagazine','campaignADAhead','campaignMissileCompatible','campaignMissileGate','campaignMissileEngage','campaignPlayerControl','campaignCruiseTrack','campaignSensors','campaignCountermeasure','campaignCMChance','airAvionics','airHelmet','zeusPrepare','zeusServer','zeusClient'];
const q=s=>'"'+s.replaceAll('"','""')+'"';
function prepare(){
 fs.mkdirSync(path.join(out,'addons'),{recursive:true});fs.mkdirSync(path.join(source,'functions'),{recursive:true});fs.mkdirSync(path.join(source,'missions'),{recursive:true});
 const base=JSON.parse(fs.readFileSync(path.join(root,'control-center/data/operations/cba3cb3d-2940-4964-861d-9586013f88ff.json'),'utf8')).design;
 const mods=JSON.parse(fs.readFileSync(path.join(root,'control-center/data/operations-launch.json'),'utf8')).mods;
 const ad=require('./build-air-defense-addon').prepare(mods);
 fs.copyFileSync(ad.pbo,path.join(out,'addons/NeroAirDefense.pbo'));
 fs.copyFileSync(path.join(root,'dist/strategic-compat/@NeroAI_Strategic/addons/NeroStrategic.pbo'),path.join(out,'addons/NeroStrategic.pbo'));
 const flight=path.join(root,'dist/flight-test/@NeroAI_Flight/addons/NeroFlight.pbo');if(fs.existsSync(flight))fs.copyFileSync(flight,path.join(out,'addons/NeroFlight.pbo'));
 for(const fn of functions){const dir=fn.startsWith('zeus')?'operation-common':fn.startsWith('air')?'operation-assets':'campaign-assets';let s=fs.readFileSync(path.join(__dirname,dir,'fn_'+fn+'.sqf'),'utf8');
  if(fn==='campaignSensors')s=s.replace('[player,"CM",0] remoteExecCall ["NeroOP_fnc_campaignEquipmentAction",2]','[player] remoteExecCall ["NeroSandbox_fnc_cmRequest",2]');
  fs.writeFileSync(path.join(source,'functions/fn_'+fn+'.sqf'),s);
 }
 fs.copyFileSync(path.join(__dirname,'editor-test-assets/fn_airCombat.sqf'),path.join(source,'functions/fn_airCombat.sqf'));
 fs.copyFileSync(path.join(__dirname,'editor-test-assets/fn_enable.sqf'),path.join(source,'functions/fn_enable.sqf'));
 fs.copyFileSync(path.join(__dirname,'editor-test-assets/fn_cmRequest.sqf'),path.join(source,'functions/fn_cmRequest.sqf'));
 const missions=[],warnings=[],presets=require('../control-center/campaign-presets');
 for(const p of presets.list()){
  const geometry=presets.layout(require('../control-center/scenario-design').world(p.id));
  const d={...structuredClone(base),world:p.id,title:'NeroAI TEST — '+p.label+': линия фронта',campaignKey:crypto.createHash('sha256').update('eden-test-'+p.id).digest('hex').slice(0,32).replace(/^(.{8})(.{4})(.{4})(.{4})(.{12})$/,'$1-$2-$3-$4-$5'),persistence:false,sectors:geometry.sectors,links:geometry.links,extraMods:base.extraMods,sides:base.sides.map((s,i)=>({...structuredClone(s),base:geometry.bases[i]}))};
  try {const r=require('./build-campaign-operation').build(d);copyMission(r,'Front_'+p.id.replace(/\W/g,'_'));} catch(e){if(p.id===base.world)throw e;warnings.push({world:p.id,reason:e.message});}
 }
 const saved=fs.readdirSync(path.join(root,'control-center/data/operations')).filter(f=>f.endsWith('.json')).map(f=>JSON.parse(fs.readFileSync(path.join(root,'control-center/data/operations',f),'utf8'))).filter(r=>r.design).reverse();
 for(const type of ['airBattle','assaultDefense']){const record=saved.find(r=>r.design.type===type);if(record){const d={...structuredClone(record.design),title:'NeroAI TEST — '+record.design.title,extraMods:base.extraMods};const r=require('./build-operation').build(d);copyMission(r,type);}}
 function copyMission(r,id){const name='NeroAI_Test_'+id+'.'+r.world;const dest=path.join(source,'missions',name);fs.cpSync(r.output,dest,{recursive:true});if(!id.startsWith('Front_'))for(const f of ['initServer.sqf','initPlayerLocal.sqf'])fs.appendFileSync(path.join(dest,f),'\n[] spawn NeroSandbox_fnc_enable;\n');fs.mkdirSync(path.join(out,'EdenTemplates'),{recursive:true});fs.cpSync(dest,path.join(out,'EdenTemplates',name),{recursive:true});missions.push({id,name,world:r.world,title:r.title,folder:dest});}
 const entries=missions.map(m=>'class NeroTest_'+m.id+' {briefingName='+q(m.title)+';directory='+q('NeroEditor\\missions\\'+m.name)+';};').join('\n');
 const config='class CfgPatches {class NeroEditor {requiredVersion=2.18;requiredAddons[]={"A3_Modules_F","NeroAirDefense","NeroStrategic"};units[]={"NeroSandbox_Module"};weapons[]={};};};\nclass CfgFactionClasses {class NO_CATEGORY;class NeroSandbox: NO_CATEGORY {displayName="NeroAI — тестирование";};};\nclass CfgVehicles {class Logic;class Module_F:Logic {class AttributesBase;class ModuleDescription;};class NeroSandbox_Module:Module_F {scope=2;scopeCurator=1;displayName="NeroAI: ПВО, РЛС и авиация — тест";category="NeroSandbox";function="NeroSandbox_fnc_enable";functionPriority=1;isGlobal=2;isTriggerActivated=0;isDisposable=1;class ModuleDescription:ModuleDescription {description="Включает сеть РЛС 3 км, ПВО, Skynex, радарные цели крылатых ракет, F/A-18 и Zeus. Полная экономика/ИИ доступны в тестовых сценариях.";};};};\nclass CfgFunctions {class NeroSandbox {class Editor {file="NeroEditor\\functions";'+[...functions,'enable','cmRequest','airCombat'].map(fn=>'class '+fn+' {};').join('')+'};};};\nclass CfgRemoteExec {class Functions {class NeroSandbox_fnc_cmRequest {allowedTargets=2;jip=0;};};};\nclass CfgMissions {class Missions {'+entries+'};class MPMissions {'+entries+'};};\n';
 fs.writeFileSync(path.join(source,'config.cpp'),config);
 fs.writeFileSync(path.join(out,'mod.cpp'),'name="NeroAI Operations — Editor Test";author="NeroAI";tooltip="Тестирование систем NeroAI в Eden";description="Модуль Eden и готовые тестовые сценарии";');
 const manifest={version:1,out,source,prefix:'NeroEditor',missions,functions,requiredMods:mods,warnings,gameTested:false};fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(manifest,null,2));return manifest;
}
async function build(){const m=prepare(),shell=['C:/Program Files/PowerShell/7/pwsh.exe',path.join(process.env.USERPROFILE,'.cache/codex-runtimes/codex-primary-runtime/dependencies/native/powershell/pwsh.exe')].find(p=>fs.existsSync(p))||'powershell.exe';const r=cp.spawnSync(shell,['-NoProfile','-File',path.join(__dirname,'pack-pbo.ps1'),'-SourceDir',source,'-OutputDir',path.join(out,'addons'),'-OutputPbo','NeroEditor.pbo','-Prefix','NeroEditor'],{encoding:'utf8',windowsHide:true,timeout:60000,maxBuffer:1024*1024});if(r.status!==0)throw Error(r.error?.message||r.stderr||r.stdout);const v=cp.spawnSync(process.execPath,[path.join(__dirname,'verify-pbo.js'),path.join(out,'addons/NeroEditor.pbo'),source,'NeroEditor'],{encoding:'utf8',windowsHide:true,maxBuffer:1024*1024});if(v.status!==0)throw Error(v.stderr||v.stdout);m.verification=JSON.parse(v.stdout);fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(m,null,2));return m;}
if(require.main===module)build().then(m=>console.log(JSON.stringify({out:m.out,missions:m.missions.length,verified:m.verification.verified},null,2))).catch(e=>{console.error(e.stack);process.exitCode=1;});
module.exports={prepare,build,functions,out};
