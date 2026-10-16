"use strict";
const fs = require("node:fs");
const path = require("node:path");
const { complete } = require("../bridge/lm-studio");
const { validateModelResponse } = require("../bridge/protocol");
const config = JSON.parse(fs.readFileSync(path.join(__dirname, "..", "bridge", "neroai3.config.json"), "utf8"));
const snapshot = '["v",3,"ch","AUTONOMY","side","RED","playerSide","BLUE","groups",[["Враг-1","VANILLA",[1000,1000],4,4,0,3000,[],50,["alive",4,"vehicles",0]]],"shop",[["INFANTRY",50,150],["APC",900,1400]],"sectors",[["Цель",[1500,1500],"NONE",700,false]],"order","Тест схемы. Не выполнять в игре."]';
(async () => {
  const trace = [];
  const raw = await complete(config, snapshot, (event, detail) => { if (event === "Enemy strategy unavailable" || event === "Enemy strategy ready" || event === "LM request") trace.push([event, String(detail || "").slice(0, 160)]); });
  const checked = validateModelResponse(raw, config.limits);
  console.log(JSON.stringify({ macCalled: trace.some(row => row[0] === "Enemy strategy ready"), tacticalCalled: trace.some(row => row[0] === "LM request"), validated: Boolean(checked), trace }));
})().catch(error => { console.error(error.message); process.exitCode = 1; });
