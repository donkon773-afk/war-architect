"use strict";
const fs=require("node:fs"),path=require("node:path");
const {complete,buildRequestPayload}=require("../bridge/lm-studio");
const {validateModelResponse}=require("../bridge/protocol");

// Diagnostic completion only: no game queues, dispatcher or command execution.
async function benchmark(config,runs=1,completion=complete){
 if(!Number.isInteger(runs)||runs<1||runs>5)throw Error("Runs must be an integer from 1 to 5");
 const snapshot='["v",3,"mission","neroai-benchmark","ch","AUTONOMY","side","RED","playerSide","NONE","groups",[],"order","Диагностика API. Верни короткий REPORT без координат и без боевых действий."]';
 const payload=buildRequestPayload(config,snapshot),results=[];
 for(let i=0;i<runs;i++){
  const started=performance.now();
  try{const response=validateModelResponse(await completion(config,snapshot),config.limits||{});results.push({run:i+1,elapsedMs:Math.round(performance.now()-started),valid:response.ok,actions:response.actions.length});}
  catch(error){results.push({run:i+1,elapsedMs:Math.round(performance.now()-started),valid:false,error:String(error.message).replace(/Bearer\s+[^\s]+/g,"Bearer [hidden]")});}
 }
 return {configuredModel:config.lmStudio.model,requests:runs,promptCharacters:payload.messages.reduce((n,m)=>n+String(m.content).length,0),results,allValid:results.every(r=>r.valid)};
}

async function main(){
 const args=process.argv.slice(2);
 if(args.includes("--help")){console.log("node tools/benchmark-local-llm.js [--config path.json] [--runs 1..5]\nMeasures complete responses without sending anything to Arma.");return;}
 let configPath=process.env.NEROAI3_CONFIG||path.join(__dirname,"../bridge/neroai3.config.json"),runs=1;
 for(let i=0;i<args.length;i++){if(args[i]==="--config"&&args[i+1])configPath=args[++i];else if(args[i]==="--runs"&&args[i+1])runs=Number(args[++i]);else throw Error("Unknown or incomplete argument: "+args[i]);}
 const config=JSON.parse(fs.readFileSync(configPath,"utf8").replace(/^\uFEFF/,""));
 if(!config.lmStudio?.model||!config.lmStudio?.baseUrl)throw Error("Config must contain an LLM endpoint and model");
 const result=await benchmark(config,runs);console.log(JSON.stringify(result,null,2));if(!result.allValid)process.exitCode=1;
}
if(require.main===module)main().catch(error=>{console.error(error.message);process.exitCode=1;});
module.exports={benchmark};
