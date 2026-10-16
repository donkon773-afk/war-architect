"use strict";
// Source migration, idempotent. Private configuration is backed up, never printed.
const fs = require("node:fs"), path = require("node:path");
const root = path.resolve(__dirname,"..");
function replace(file, before, after) {
  const full = path.join(root,file), text = fs.readFileSync(full,"utf8");
  if (after !== "" && text.includes(after)) return;
  if (!text.includes(before)) {
    if (after === "") return;
    throw new Error(`Migration anchor missing: ${file}`);
  }
  fs.writeFileSync(full,text.replace(before,after));
}
replace("bridge/protocol.js",'new Set(["INFANTRY", "CAR", "APC", "TANK", "TRUCK"])','new Set(["INFANTRY", "CAR", "APC", "TANK", "TRUCK", "HELICOPTER", "PLANE", "UAV"])');
replace("bridge/system-prompt.js","INFANTRY|CAR|APC|TANK|TRUCK (BUY)","INFANTRY|CAR|APC|TANK|TRUCK|HELICOPTER|PLANE|UAV (BUY)");
replace("bridge/system-prompt.js","APCs carry infantry, tanks lead,","APCs carry infantry, tanks support on open ground and cover infantry at the urban edge,");
replace("bridge/lm-studio.js",'const { buildSystemPrompt } = require("./system-prompt");','const { buildSystemPrompt } = require("./system-prompt");\nconst { WARLORDS_DOCTRINE } = require("./warlords-doctrine");');
replace("bridge/lm-studio.js",'"CAS", "INFANTRY", "CAR", "APC", "TANK", "TRUCK"]','"CAS", "INFANTRY", "CAR", "APC", "TANK", "TRUCK", "HELICOPTER", "PLANE", "UAV"]');
replace("bridge/lm-studio.js",'Maximum 500 characters." }','Maximum 500 characters.\\n" + WARLORDS_DOCTRINE }');
replace("tools/start-warlords.ps1"," -or -not $config.dualEnemy.enabled","");
replace("tools/start-warlords.ps1","namespace or dual-model mode is invalid.","namespace is invalid.");
replace("tools/start-warlords.ps1","One or both local LLMs failed the readiness check.","Configured local LLM readiness check failed.");
replace("tools/check-brains.js",'await verify("RTX tactical", config.lmStudio);\n  await verify("Mac strategic", config.dualEnemy?.strategy);','await verify(config.dualEnemy?.enabled ? "Tactical LLM" : "Mac strategy + tactics", config.lmStudio);\n  if (config.dualEnemy?.enabled) await verify("Mac strategic", config.dualEnemy.strategy);');
const configPath = path.join(root,"bridge","neroai3.config.json");
const config = JSON.parse(fs.readFileSync(configPath,"utf8"));
if (config.lmStudio.model !== "openai/gpt-oss-20b" || config.dualEnemy.enabled) {
  const backup = path.join(root,"backups","doctrine-"+new Date().toISOString().replace(/[:.]/g,"-"));
  fs.mkdirSync(backup,{recursive:true}); fs.copyFileSync(configPath,path.join(backup,"neroai3.config.json"));
  if (!config.dualEnemy.strategy?.baseUrl) throw new Error("Mac profile missing");
  config.lmStudio = {...config.lmStudio,...config.dualEnemy.strategy,model:"openai/gpt-oss-20b",temperature:0.9,maxTokens:900,timeoutMs:60000,reasoningEffort:"none",structuredOutput:true};
  config.dualEnemy.enabled = false;
  fs.writeFileSync(configPath,JSON.stringify(config,null,2));
}
console.log("Doctrine/protocol migrated; current mode: Mac GPT-OSS 20B strategy + tactics. Dual mode remains supported.");
