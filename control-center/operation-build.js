'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),cp=require('node:child_process'),{promisify}=require('node:util');
const run=promisify(cp.execFile),root=path.resolve(__dirname,'..');
const shell=[process.env.NEROAI_PWSH,'C:/Program Files/PowerShell/7/pwsh.exe',path.join(process.env.USERPROFILE||'','.cache/codex-runtimes/codex-primary-runtime/dependencies/native/powershell/pwsh.exe')].find(p=>p&&fs.existsSync(p))||'powershell.exe';
const arma='H:/SteamLibrary/steamapps/common/Arma 3';
async function build(design){delete require.cache[require.resolve('../tools/build-operation')];const result=require('../tools/build-operation').build(design);require('../tools/validate-operation').validate(result.output);
 for(const addon of result.addonArtifacts||[]){await require('./build-addon-artifact').ensure(addon,{pack:a=>run(shell,['-NoProfile','-ExecutionPolicy','Bypass','-File',path.join(root,'tools/pack-pbo.ps1'),'-SourceDir',a.source,'-OutputDir',path.dirname(a.pbo),'-OutputPbo',path.basename(a.pbo),'-Prefix',a.prefix],{windowsHide:true,timeout:30000,maxBuffer:1024*1024}),verify:a=>run(process.execPath,[path.join(root,'tools/verify-pbo.js'),a.pbo,a.source,a.prefix],{windowsHide:true,timeout:20000,maxBuffer:1024*1024})});}
 for(const mod of result.extraMods){let available=false;try{available=fs.statSync(mod).isDirectory();}catch{}if(!available)throw Error('Недоступен обязательный мод операции: '+mod);}
 const warnings=(design.extraMods||[]).filter(p=>!result.extraMods.includes(p)).map(p=>'Пропущен недоступный дополнительный мод: '+path.basename(p));
 const output=path.dirname(result.output),pbo=path.join(output,result.name+'.'+result.world+'.pbo');
 await run(shell,['-NoProfile','-ExecutionPolicy','Bypass','-File',path.join(root,'tools/pack-pbo.ps1'),'-SourceDir',result.output,'-OutputDir',output,'-OutputPbo',path.basename(pbo),'-Mission'],{windowsHide:true,timeout:30000,maxBuffer:1024*1024});
 const verified=await run(process.execPath,[path.join(root,'tools/verify-pbo.js'),pbo,result.output,'--mission'],{windowsHide:true,timeout:20000,maxBuffer:1024*1024});
 const sha256=crypto.createHash('sha256').update(fs.readFileSync(pbo)).digest('hex').toUpperCase();
 const requiredMods=require('./operation-required-mods').resolve(design);const artifact={...result,requiredModLoading:true,requiredMods,warnings,pbo,sha256,bytes:fs.statSync(pbo).size,sourceVerified:true,gameTested:false,verification:JSON.parse(verified.stdout)};
 fs.writeFileSync(path.join(result.output,'..',result.name+'.verification.json'),JSON.stringify(artifact,null,2));return artifact;
}
function install(artifact){const folder=path.join(arma,'MPMissions');if(!fs.existsSync(folder))throw Error('Папка MPMissions Arma не найдена.');const installed=path.join(folder,path.basename(artifact.pbo));
 if(fs.existsSync(installed)){const existing=crypto.createHash('sha256').update(fs.readFileSync(installed)).digest('hex').toUpperCase();if(existing!==artifact.sha256)throw Error('Уже существует другая сборка с этим именем. Активный файл не заменён. Измените название операции и соберите отдельный вариант.');}
 else fs.copyFileSync(artifact.pbo,installed,fs.constants.COPYFILE_EXCL);
 if(crypto.createHash('sha256').update(fs.readFileSync(installed)).digest('hex').toUpperCase()!==artifact.sha256)throw Error('Проверка установленного файла не прошла.');const cleanup=require("./scenario-archive").cleanup({keepFiles:[installed]});return {...artifact,installed,installationVerified:true,cleanup};
}
async function launch(artifact){const requiredMods=require('./operation-required-mods').verifyArtifact(artifact);const request=path.join(root,'control-center/data/operations-launch.json');require('./durable').write(request,{mods:artifact.extraMods,requiredModLoading:true,requiredMods:requiredMods.filter(r=>!r.generated).map(r=>({path:r.id,label:r.label,files:r.files})),world:artifact.world,title:artifact.title});
 const log=path.join(__dirname,'logs','operations-launch.log');fs.mkdirSync(path.dirname(log),{recursive:true});
 await new Promise((resolve,reject)=>{const fd=fs.openSync(log,'w'),child=cp.spawn(shell,['-NoProfile','-ExecutionPolicy','Bypass','-File',path.join(__dirname,'operations-launch.ps1'),'-RequestFile',request],{windowsHide:true,stdio:['ignore',fd,fd]});fs.closeSync(fd);const timer=setTimeout(()=>{reject(Error('Запуск не подтвердился за 95 секунд. Смотрите журнал операций.'));},95000);child.once('error',e=>{clearTimeout(timer);reject(e);});child.once('exit',code=>{clearTimeout(timer);if(code===0)resolve();else reject(Error(fs.readFileSync(log,'utf8').slice(-2000)));});});
 return {launched:true,message:'Arma запущена. Создайте сервер на карте '+artifact.world+' и выберите «'+artifact.title+'».'+(artifact.warnings?.length?'\n'+artifact.warnings.join('\n'):'')};}
module.exports={build,install,launch,arma};
