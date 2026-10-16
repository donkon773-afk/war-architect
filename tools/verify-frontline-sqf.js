'use strict';
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),cp=require('node:child_process');
const {decode}=require('./adapt-frontline');
const root=path.resolve(__dirname,'..'),vm=process.env.NEROAI_SQFVM||path.join(__dirname,'vendor/sqfvm-2026.04.03/runtime/sqfvm_windows_x64/sqfvm.exe');
const base='addons/NeroAI3/functions/',PURE=['wlGraph','wlTargetState','wlCaptureRule'];
const INTEGRATION=['rules/fn_rulesCommander.sqf','rules/fn_rulesAllocate.sqf','rules/fn_rulesGroupPlan.sqf','core/fn_executeMacro.sqf','core/fn_registerGroup.sqf','bootstrap/fn_postInit.sqf','native/fn_WLAIPathSegmentation.sqf'];
function invoke(args,cwd){const r=cp.spawnSync(vm,['-a','--suppress-welcome','--no-execute-print','--no-work-print','--max-runtime','5000',...args],{cwd,encoding:'utf8',timeout:15000,windowsHide:true,maxBuffer:1048576});const out=(r.stdout||'')+(r.stderr||'');if(r.error||r.status!==0||/\[(?:ERR|FAT)\]/.test(out))throw Error('SQF-VM failed: '+(r.error?.message||out||r.status));return out;}
function normalizeConfig(s){
 // Native FSMs also fail the VM's config parser: it does not support all the
 // engine's quoted string/newline concatenation and trailing array commas.
 return s.replace(/"(?:""|[^"])*"(?:\s*\\n\s*"(?:""|[^"])*")+/g,raw=>'"'+decode(raw).replaceAll('"','""').replaceAll('\n','\\n')+'"').replace(/,\s*(?=};)/g,'');
}
function verify(){
 if(!fs.existsSync(vm))throw Error('SQF-VM required.');
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'nero-frontline-sqf-'));let scripts=0;
 try{
  const folder=path.join(root,base,'frontline'),files=fs.readdirSync(folder).filter(n=>/^fn_.*\.sqf$/.test(n));
  for(const f of files)fs.copyFileSync(path.join(folder,f),path.join(dir,f));
  const ints=INTEGRATION.map((r,i)=>{const n='int'+i+'.sqf';fs.copyFileSync(path.join(root,base,r),path.join(dir,n));return n;});
  invoke(['--parse-only',...[...files,...ints].flatMap(n=>['--input-sqf',n])],dir);
  for(const name of ['fn_WLAICore.fsm','fn_WLSectorHandleServer.fsm']){
   const source=fs.readFileSync(path.join(root,base,'native',name),'latin1'),config=name+'.cpp';
   fs.writeFileSync(path.join(dir,config),normalizeConfig(source));
   invoke(['--parse-only','--input-config',config],dir);
   const blocks=[...source.matchAll(/\b(?:init|precondition|condition|action)\s*=\s*(?:\/\*[\s\S]*?\*\/\s*)?("(?:""|[^"])*"(?:\s*\\n\s*"(?:""|[^"])*")*)/g)].map(m=>decode(m[1])).filter(s=>s.trim());
   if(name.includes('SectorHandle'))for(const b of [...blocks])for(const m of b.matchAll(/"((?:""|[^"])*)"/g)){const code=m[1].replaceAll('""','"');if(code.includes('call NeroAI_fnc_wlCaptureAllowed'))blocks.push(code);}
   const names=blocks.map((code,i)=>{const n=name+i+'.sqf';fs.writeFileSync(path.join(dir,n),code);return n;});
   invoke(['--parse-only',...names.flatMap(n=>['--input-sqf',n])],dir);scripts+=names.length;
  }
  const code=PURE.map(n=>'NeroAI_fnc_'+n+'={\n'+fs.readFileSync(path.join(folder,'fn_'+n+'.sqf'),'utf8')+'\n};').join('\n')+'\nNeroAI_fnc_rulesAllocate={\n'+fs.readFileSync(path.join(root,base,'rules/fn_rulesAllocate.sqf'),'utf8')+'\n};\n'+fs.readFileSync(path.join(root,'tests/frontline-logic.sqf'),'utf8');
  fs.writeFileSync(path.join(dir,'test.sqf'),code);const out=invoke(['--input-sqf','test.sqf'],dir),m=out.match(/FRONTLINE_TESTS_OK (\d+)/);if(!m)throw Error('Missing test completion marker: '+out);
  return {parser:'SQF-VM v2026.04.03-ed9f5f5',parsedFiles:files.length,parsedIntegrationFiles:ints.length,parsedNativeConfigs:2,parsedNativeScripts:scripts,configNormalization:'VM compatibility only; original native configs fail its parser too',executedPureFunctions:[...PURE,'rulesAllocate'],assertions:Number(m[1])};
 }finally{if(path.dirname(dir)!==path.resolve(os.tmpdir())||!path.basename(dir).startsWith('nero-frontline-sqf-'))throw Error('Unexpected test temp path');fs.rmSync(dir,{recursive:true,force:true});}
}
if(require.main===module){try{console.log(JSON.stringify(verify(),null,2));}catch(e){console.error(e.message);process.exitCode=1;}}
module.exports={verify,normalizeConfig};
