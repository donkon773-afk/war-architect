'use strict';
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),cp=require('node:child_process');
const root=path.resolve(__dirname,'..'),vm=process.env.NEROAI_SQFVM||path.join(__dirname,'vendor/sqfvm-2026.04.03/runtime/sqfvm_windows_x64/sqfvm.exe');
function invoke(args,cwd){
 const r=cp.spawnSync(vm,['-a','--suppress-welcome','--no-execute-print','--no-work-print','--max-runtime','5000',...args],{cwd,encoding:'utf8',timeout:15000,windowsHide:true,maxBuffer:1024*1024});
 const out=(r.stdout||'')+(r.stderr||'');
 if(r.error||r.status!==0||/\[(?:ERR|FAT)\]/.test(out))throw Error('SQF-VM failed: '+(r.error?.message||out||r.status));
 return out;
}
function verify(){
 if(!fs.existsSync(vm))throw Error('SQF-VM is required. Set NEROAI_SQFVM to the executable or use tools/vendor/sqfvm-2026.04.03.');
 const assets=path.join(__dirname,'designer-assets'),files=fs.readdirSync(assets).filter(n=>/^fn_cq.*\.sqf$/.test(n));
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'nero-cq-sqf-'));
 try{
  for(const file of files)fs.copyFileSync(path.join(assets,file),path.join(dir,file));
  invoke(['--parse-only',...files.flatMap(f=>['--input-sqf',f])],dir);
  const pure=['cqCatalog','cqQuote','cqText','cqTally','cqLedger'];
  const code=pure.map(fn=>'NeroWL_Design_fnc_'+fn+'={\n'+fs.readFileSync(path.join(assets,'fn_'+fn+'.sqf'),'utf8')+'\n};').join('\n')+'\n'+fs.readFileSync(path.join(root,'tests/cq-logic.sqf'),'utf8');
  fs.writeFileSync(path.join(dir,'tests.sqf'),code);
  const output=invoke(['--input-sqf','tests.sqf'],dir),match=output.match(/CQ_TESTS_OK (\d+)/);
  if(!match)throw Error('SQF tests did not reach the terminal success marker: '+output);
  return {parser:'SQF-VM v2026.04.03-ed9f5f5',parsedFiles:files.length,executedPureFunctions:pure,assertions:Number(match[1]),engineUiExecuted:false};
 }finally{
  if(path.dirname(dir)!==path.resolve(os.tmpdir())||!path.basename(dir).startsWith('nero-cq-sqf-'))throw Error('Unexpected SQF test temp path');
  fs.rmSync(dir,{recursive:true,force:true});
 }
}
if(require.main===module){try{console.log(JSON.stringify(verify(),null,2));}catch(e){console.error(e.message);process.exitCode=1;}}
module.exports={verify};
