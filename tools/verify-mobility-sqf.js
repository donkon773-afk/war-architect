'use strict';
// 11.10: tactical AI without LLM — parse every rules SQF file with SQF-VM and
// execute the pure decision functions against tests/rules-logic.sqf.
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),vm=process.env.NEROAI_SQFVM||path.join(__dirname,'vendor/sqfvm-2026.04.03/runtime/sqfvm_windows_x64/sqfvm.exe');
const doctrine=path.join(root,'addons/NeroAI3/functions/mobility');
const PURE=['motionProgress','motionAuthority','motionCandidates','motionPointDistance','crewSeatRoles'];
// Existing files the tactical mode touches: parsed too (syntax only, no engine).
const INTEGRATION=['tactical/fn_vehicleRoute.sqf','tactical/fn_routeStop.sqf','tactical/fn_roadRoute.sqf','tactical/fn_mobilityWatchdog.sqf','tactical/fn_purchaseAsset.sqf','tactical/fn_vehicleTactics.sqf','bootstrap/fn_preInit.sqf','native/fn_WLAirdrop.sqf'].map(p=>'addons/NeroAI3/functions/'+p);
function invoke(args,cwd){
 const r=cp.spawnSync(vm,['--command-dummy-unary','isAISteeringComponentEnabled','-a','--suppress-welcome','--no-execute-print','--no-work-print','--max-runtime','5000',...args],{cwd,encoding:'utf8',timeout:15000,windowsHide:true,maxBuffer:1024*1024});
 const out=(r.stdout||'')+(r.stderr||'');
 if(r.error||r.status!==0||/\[(?:ERR|FAT)\]/.test(out))throw Error('SQF-VM failed: '+(r.error?.message||out||r.status));
 return out;
}
function verify(){
 if(!fs.existsSync(vm))throw Error('SQF-VM is required. Set NEROAI_SQFVM to the executable or use tools/vendor/sqfvm-2026.04.03.');
 const files=fs.readdirSync(doctrine).filter(n=>/^fn_.*\.sqf$/.test(n));
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'nero-mobility-sqf-'));
 try{
  for(const file of files)fs.copyFileSync(path.join(doctrine,file),path.join(dir,file));
  invoke(['--parse-only',...files.flatMap(f=>['--input-sqf',f])],dir);
  const integration=INTEGRATION.map((rel,i)=>{const name='int'+i+'_'+path.basename(rel);fs.copyFileSync(path.join(root,rel),path.join(dir,name));return name;});
  invoke(['--parse-only',...integration.flatMap(f=>['--input-sqf',f])],dir);
  const code=PURE.map(fn=>'NeroAI_fnc_'+fn+'={\n'+fs.readFileSync(path.join(doctrine,'fn_'+fn+'.sqf'),'utf8')+'\n};').join('\n')+'\n'+fs.readFileSync(path.join(root,'tests/mobility-logic.sqf'),'utf8');
  fs.writeFileSync(path.join(dir,'tests.sqf'),code);
  const output=invoke(['--input-sqf','tests.sqf'],dir),match=output.match(/MOBILITY_TESTS_OK (\d+)/);
  if(!match)throw Error('SQF tests did not reach the terminal success marker: '+output);
  return {parser:'SQF-VM v2026.04.03-ed9f5f5',parserOnlyStubs:['isAISteeringComponentEnabled'],parsedFiles:files.length,parsedIntegrationFiles:INTEGRATION.length,executedPureFunctions:PURE,assertions:Number(match[1])};
 }finally{
  if(path.dirname(dir)!==path.resolve(os.tmpdir())||!path.basename(dir).startsWith('nero-mobility-sqf-'))throw Error('Unexpected SQF test temp path');
  fs.rmSync(dir,{recursive:true,force:true});
 }
}
if(require.main===module){try{console.log(JSON.stringify(verify(),null,2));}catch(e){console.error(e.message);process.exitCode=1;}}
module.exports={verify};
