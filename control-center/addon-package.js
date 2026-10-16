"use strict";
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const variants={warlords:{folder:'@NeroAI_Warlords',name:'NeroWL.pbo',prefix:'NeroWL',sourceName:'NeroAI3'},antistasi:{folder:'@NeroAI_Antistasi',name:'NeroAI5.pbo',prefix:'NeroAI5',sourceName:'NeroAI5'}};
function descriptor(scenario,core){
  if(!Object.hasOwn(variants,scenario))throw Error('Неизвестный сценарий обновления.');
  const v=variants[scenario],root=core.projects[scenario],cfg=core.read(path.join(root,'tools',scenario+'-launch.json'));
  return {...v,root,source:path.join(root,'addons',v.sourceName),candidate:path.join(root,'dist','candidate',v.name),installed:path.join(cfg.armaRoot,v.folder,'addons',v.name)};
}
async function build(scenario,core,run,shell){
  const a=descriptor(scenario,core);
  await run(shell,['-NoProfile','-ExecutionPolicy','Bypass','-File',path.join(a.root,'tools','pack-pbo.ps1'),'-SourceDir',a.source,'-OutputDir',path.dirname(a.candidate),'-OutputPbo',a.name,'-Prefix',a.prefix],{windowsHide:true,timeout:30000,cwd:a.root});
  await run(process.execPath,[path.join(a.root,'tools','verify-pbo.js'),a.candidate,a.source,a.prefix],{windowsHide:true,timeout:15000,cwd:a.root});
  return a;
}
function installed(scenario,core){
  const a=descriptor(scenario,core),hash=f=>crypto.createHash('sha256').update(fs.readFileSync(f)).digest('hex');
  return fs.existsSync(a.installed)&&fs.existsSync(a.candidate)&&hash(a.installed)===hash(a.candidate);
}
module.exports={descriptor,build,installed};
