'use strict';
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const {resolve}=require('./flight-profiles');
const root=path.resolve(__dirname,'..'),out=path.join(root,'dist/flight-test/@NeroAI_Flight'),source=path.join(out,'source');
function prepare(){
 const assets=require('../control-center/campaign-equipment').assets();
 const installed=require('../dist/mod-assets.json').assets;
 const classes=[...new Set([...assets,...installed].filter(x=>['PLANE','VTOL'].includes(x.kind)).map(x=>x.class))];
 // Base-game classes are not consistently present in the scanned Workshop asset table.
 classes.push(...['B_Plane_CAS_01_dynamicLoadout_F','O_Plane_CAS_02_dynamicLoadout_F','I_Plane_Fighter_03_dynamicLoadout_F','B_Plane_Fighter_01_F','B_Plane_Fighter_01_Stealth_F','O_Plane_Fighter_02_F','O_Plane_Fighter_02_Stealth_F','I_Plane_Fighter_04_F','C_Plane_Civil_01_F','C_Plane_Civil_01_racing_F','I_C_Plane_Civil_01_F','B_T_VTOL_01_infantry_F','B_T_VTOL_01_vehicle_F','B_T_VTOL_01_armed_F','O_T_VTOL_02_infantry_dynamicLoadout_F','O_T_VTOL_02_vehicle_dynamicLoadout_F']);
 const mapped=[],unmapped=[];
 for(const name of [...new Set(classes)].sort()){if(!/^[a-z0-9_]+$/i.test(name))throw Error('Invalid classname');const p=resolve(name);if(p)mapped.push({class:name,...p});else unmapped.push(name);}
 fs.mkdirSync(path.join(source,'functions'),{recursive:true});fs.mkdirSync(path.join(out,'addons'),{recursive:true});
 for(const fn of ['init','step'])fs.copyFileSync(path.join(__dirname,'flight-assets/fn_'+fn+'.sqf'),path.join(source,'functions/fn_'+fn+'.sqf'));
 const config='class CfgPatches {class NeroFlight {requiredVersion=2.18;requiredAddons[]={"A3_Air_F"};units[]={};weapons[]={};};};\nclass CfgNeroFlight {'+mapped.map(p=>'class '+p.class+' {model='+JSON.stringify(p.label)+';cruise='+p.cruise+';maximum='+p.maximum+';dryMaximum='+p.dryMaximum+';afterburner='+Number(p.afterburner)+';};').join('\n')+'};\nclass CfgFunctions {class NeroFlight {class Flight {file="NeroFlight\\functions";class init {postInit=1;};class step {};};};};';
 require('./validate-mission').parseConfig(config,{rejectDuplicateDeclarations:true});fs.writeFileSync(path.join(source,'config.cpp'),config);
 const manifest={date:new Date().toISOString(),source,out,mapped,unmapped,engineTested:false,notes:'Profiles are reference envelopes. Fuel surcharge and acceleration are gameplay approximations; no native vehicle config or Workshop files are patched.'};
 fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(manifest,null,2));return manifest;
}
function build(){const m=prepare(),shell=['C:/Program Files/PowerShell/7/pwsh.exe',path.join(process.env.USERPROFILE,'.cache/codex-runtimes/codex-primary-runtime/dependencies/native/powershell/pwsh.exe')].find(fs.existsSync)||'powershell.exe';const r=cp.spawnSync(shell,['-NoProfile','-File',path.join(__dirname,'pack-pbo.ps1'),'-SourceDir',source,'-OutputDir',path.join(out,'addons'),'-OutputPbo','NeroFlight.pbo','-Prefix','NeroFlight'],{encoding:'utf8',windowsHide:true,timeout:60000});if(r.status!==0)throw Error(r.stdout+r.stderr);const v=cp.spawnSync(process.execPath,[path.join(__dirname,'verify-pbo.js'),path.join(out,'addons/NeroFlight.pbo'),source,'NeroFlight'],{encoding:'utf8',windowsHide:true});if(v.status!==0)throw Error(v.stdout+v.stderr);console.log(JSON.stringify({mapped:m.mapped.length,unmapped:m.unmapped,verified:JSON.parse(v.stdout).verified}));return m;}
module.exports={prepare,build};if(require.main===module)build();
