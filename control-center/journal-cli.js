"use strict";
const path=require("node:path"),journal=require("./journal"),core=require("./core");
let oldBridge="",oldEngine="";
function delta(before,after){if(!before)return after;const a=before.split("\n"),b=after.split("\n");for(let n=Math.min(a.length,b.length);n>0;n--)if(a.slice(-n).join("\n")===b.slice(0,n).join("\n"))return b.slice(n).join("\n");return before===after?"":after;}
function tick(){try{const keys=core.load().nodes.map(n=>n.apiKey),r=journal.read(core.project,path.join(process.env.LOCALAPPDATA||"","Arma 3"),keys);const b=delta(oldBridge,r.bridge),e=delta(oldEngine,r.engine);if(b)process.stdout.write("\n[LLM bridge: "+r.bridgeFile+"]\n"+b+"\n");if(e)process.stdout.write("\n[Arma execution: "+r.rptFile+"]\n"+e+"\n");oldBridge=r.bridge;oldEngine=r.engine;}catch(e){process.stderr.write(e.message+"\n");}}
tick();setInterval(tick,1500);
