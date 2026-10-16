"use strict";
const fs=require("node:fs"),path=require("node:path");
function tail(file,bytes=128*1024){
 if(!file||!fs.existsSync(file))return "";
 const fd=fs.openSync(file,"r");try{const size=fs.fstatSync(fd).size,start=Math.max(0,size-bytes),buffer=Buffer.alloc(size-start);fs.readSync(fd,buffer,0,buffer.length,start);const s=buffer.toString("utf8");return start?s.slice(s.indexOf("\n")+1):s;}finally{fs.closeSync(fd);}
}
function redact(text,keys=[]){let s=String(text).replace(/Bearer\s+[^\s"']+/gi,"Bearer [hidden]");for(const key of keys.filter(k=>typeof k==="string"&&k.length>4))s=s.split(key).join("[hidden]");return s;}
function read(project,profileRoot,keys=[]){
 const logs=path.join(project,"control-center","logs");
 const candidates=[path.join(logs,"warlords-bridge.log"),path.join(project,"bridge","live-console.log")].filter(f=>fs.existsSync(f));
 if(fs.existsSync(logs))candidates.push(...fs.readdirSync(logs).filter(n=>/^bridge-.*\.(stdout|stderr)\.log$/.test(n)).map(n=>path.join(logs,n)));
 candidates.sort((a,b)=>fs.statSync(b).mtimeMs-fs.statSync(a).mtimeMs);
 const bridge=candidates.find(f=>fs.statSync(f).size>0);let rpt;
 if(profileRoot&&fs.existsSync(profileRoot))rpt=fs.readdirSync(profileRoot).filter(n=>/^Arma3.*\.rpt$/i.test(n)).map(n=>path.join(profileRoot,n)).sort((a,b)=>fs.statSync(b).mtimeMs-fs.statSync(a).mtimeMs)[0];
 return {bridgeFile:bridge?path.basename(bridge):null,rptFile:rpt?path.basename(rpt):null,bridge:redact(tail(bridge).split(/\r?\n/).slice(-180).join("\n"),keys),engine:redact(tail(rpt).split(/\r?\n/).filter(l=>/NeroAI|NeroWL|Error|Undefined/i.test(l)).slice(-100).join("\n"),keys),observedAt:new Date().toISOString()};
}
module.exports={tail,redact,read};
