'use strict';
// Parse combat integrations; execute production pure functions, without an Arma engine.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),vm=process.env.NEROAI_SQFVM||path.join(__dirname,'vendor/sqfvm-2026.04.03/runtime/sqfvm_windows_x64/sqfvm.exe');
const doctrine=path.join(root,'addons/NeroAI3/functions/logistics');
const PURE=['logisticsQueueAction','queueAdmission','deliveryConfirmed','baseDeliveryRule','airdropRiskScore','airdropFlightState'];
// Existing files the tactical mode touches: parsed too (syntax only, no engine).
const INTEGRATION=['tactical/fn_purchaseAsset.sqf','tactical/fn_autoRequisition.sqf','tactical/fn_nativeGroundPurchaseAllowed.sqf','bootstrap/fn_serverLoop.sqf','native/fn_WLAirdrop.sqf'].map(p=>'addons/NeroAI3/functions/'+p);
function invoke(args,cwd){
 const r=cp.spawnSync(vm,['-a','--suppress-welcome','--no-execute-print','--no-work-print','--max-runtime','5000',...args],{cwd,encoding:'utf8',timeout:15000,windowsHide:true,maxBuffer:1024*1024});
 const out=(r.stdout||'')+(r.stderr||'');
 if(r.error||r.status!==0||/\[(?:ERR|FAT)\]/.test(out))throw Error('SQF-VM failed: '+(r.error?.message||out||r.status));
 return out;
}
function verify(){
 if(!fs.existsSync(vm))throw Error('SQF-VM is required. Set NEROAI_SQFVM to the executable or use tools/vendor/sqfvm-2026.04.03.');
 const files=fs.readdirSync(doctrine).filter(n=>/^fn_.*\.sqf$/.test(n));
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'nero-logistics-sqf-'));
 try{
  for(const file of files)fs.copyFileSync(path.join(doctrine,file),path.join(dir,file));
  invoke(['--parse-only',...files.flatMap(f=>['--input-sqf',f])],dir);
  const integration=INTEGRATION.map((rel,i)=>{const name='int'+i+'_'+path.basename(rel);fs.copyFileSync(path.join(root,rel),path.join(dir,name));return name;});
  invoke(['--parse-only',...integration.flatMap(f=>['--input-sqf',f])],dir);
  const native=fs.readFileSync(path.join(root,'addons/NeroAI3/functions/native/fn_WLAIPurchases.fsm'),'utf8');
  fs.writeFileSync(path.join(dir,'purchases.cpp'),require('./verify-frontline-sqf').normalizeConfig(native));
  invoke(['--parse-only','--input-config','purchases.cpp'],dir);
  const scripts=[...native.matchAll(/\b(?:init|precondition|condition|action)\s*=\s*(?:\/\*[\s\S]*?\*\/\s*)?("(?:""|[^"])*"(?:\s*\\n\s*"(?:""|[^"])*")*)/g)].map(m=>require('./adapt-frontline').decode(m[1])).filter(s=>s.trim());
  const nativeNames=scripts.map((s,i)=>{const n='purchase'+i+'.sqf';fs.writeFileSync(path.join(dir,n),s);return n;});
  invoke(['--parse-only',...nativeNames.flatMap(f=>['--input-sqf',f])],dir);
  const code=PURE.map(fn=>'NeroAI_fnc_'+fn+'={\n'+fs.readFileSync(path.join(doctrine,'fn_'+fn+'.sqf'),'utf8')+'\n};').join('\n')+'\n'+fs.readFileSync(path.join(root,'tests/logistics-logic.sqf'),'utf8');
  fs.writeFileSync(path.join(dir,'tests.sqf'),code);
  const output=invoke(['--input-sqf','tests.sqf'],dir),match=output.match(/LOGISTICS_TESTS_OK (\d+)/);
  if(!match)throw Error('SQF tests did not reach the terminal success marker: '+output);
  return {parser:'SQF-VM v2026.04.03-ed9f5f5',parsedFiles:files.length,parsedIntegrationFiles:INTEGRATION.length,parsedNativeConfigs:1,parsedNativeScripts:scripts.length,executedPureFunctions:PURE,assertions:Number(match[1])};
 }finally{
  if(path.dirname(dir)!==path.resolve(os.tmpdir())||!path.basename(dir).startsWith('nero-logistics-sqf-'))throw Error('Unexpected SQF test temp path');
  fs.rmSync(dir,{recursive:true,force:true});
 }
}
if(require.main===module){try{console.log(JSON.stringify(verify(),null,2));}catch(e){console.error(e.message);process.exitCode=1;}}
module.exports={verify};
