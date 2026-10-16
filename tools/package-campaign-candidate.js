'use strict';
// Offline packaging only: no install(), launch(), saved-campaign write or Workshop modification.
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..');
function build(design,out){
 out=path.resolve(out);fs.mkdirSync(out,{recursive:true});const r=require('./build-campaign-operation').build(design,path.join(out,'mission'));require('./validate-campaign-operation').validate(r.output);
 const shell=[process.env.NEROAI_PWSH,path.join(process.env.USERPROFILE,'.cache/codex-runtimes/codex-primary-runtime/dependencies/native/powershell/pwsh.exe'),'C:/Program Files/PowerShell/7/pwsh.exe'].find(p=>p&&fs.existsSync(p))||'powershell.exe';
 const run=(exe,args)=>{const p=cp.spawnSync(exe,args,{cwd:root,encoding:'utf8',timeout:30000,windowsHide:true});if(p.error)throw p.error;if(p.status!==0)throw Error((p.stdout||'')+(p.stderr||''));return p.stdout;};
 const pack=(source,pbo,prefix)=>{run(shell,['-NoProfile','-File','tools/pack-pbo.ps1','-SourceDir',source,'-OutputDir',path.dirname(pbo),'-OutputPbo',path.basename(pbo),...(prefix==='--mission'?['-Mission']:['-Prefix',prefix])]);return {sha256:crypto.createHash('sha256').update(fs.readFileSync(pbo)).digest('hex').toUpperCase(),verification:JSON.parse(run(process.execPath,['tools/verify-pbo.js',pbo,source,prefix]))};};
 for(const a of r.addonArtifacts)Object.assign(a,pack(a.source,a.pbo,a.prefix));r.requiredModLoading=true;r.requiredMods=require('../control-center/operation-required-mods').resolve(design);r.pbo=path.join(out,r.name+'.'+r.world+'.pbo');Object.assign(r,pack(r.output,r.pbo,'--mission'),{gameTested:false,installed:false});fs.writeFileSync(path.join(out,'build.json'),JSON.stringify(r,null,2));return r;
}
if(require.main===module){const [,,input,out]=process.argv;if(!input||!out)throw Error('Usage: node tools/package-campaign-candidate.js design.json output-folder');const r=build(JSON.parse(fs.readFileSync(input,'utf8')),out);console.log(JSON.stringify({pbo:r.pbo,sha256:r.sha256,addons:r.addonArtifacts.map(a=>({prefix:a.prefix,hash:a.hash,classes:a.classes,verified:a.verification.manifestMatchesSource}))},null,2));}
module.exports={build};
