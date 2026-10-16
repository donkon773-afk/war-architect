"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");
const { complete } = require("../bridge/lm-studio");
const root = path.resolve(__dirname, "..");

async function modelServer(name, seen) {
  const server = http.createServer((request, response) => {
    let body = "";
    request.on("data", chunk => { body += chunk; });
    request.on("end", () => {
      seen.push(JSON.parse(body));
      response.writeHead(200, { "content-type": "application/json" });
      response.end(JSON.stringify({ choices: [{ message: { content: name === "mac" ? "Удержать текущий сектор. CP направить на броню." : '{"version":3,"speech":"Принято","actions":[]}' } }] }));
    });
  });
  await new Promise(resolve => server.listen(0, "127.0.0.1", resolve));
  return { server, url: `http://127.0.0.1:${server.address().port}/v1` };
}

test("enemy requests use Mac strategic intent and RTX tactical answer; repeated plans reuse bounded strategy", async () => {
  const macSeen = [], rtxSeen = [];
  const mac = await modelServer("mac", macSeen), rtx = await modelServer("rtx", rtxSeen);
  try {
    const config = { lmStudio: { baseUrl: rtx.url, model: "rtx-test", timeoutMs: 3000, maxTokens: 200, temperature: 0.8, structuredOutput: true }, dualEnemy: { enabled: true, strategy: { baseUrl: mac.url, model: "mac-test", timeoutMs: 3000, maxTokens: 200 } } };
    const snapshot = '["v",3,"ch","AUTONOMY","side","RED","playerSide","BLUE","groups",[]]';
    for (let i = 0; i < 2; i++) assert.match(await complete(config, snapshot), /"version":3/);
    assert.equal(macSeen.length, 1);
    assert.equal(rtxSeen.length, 2);
    assert.equal(macSeen[0].model, "mac-test");
    assert.equal(rtxSeen[0].model, "rtx-test");
    assert.match(rtxSeen[0].messages.at(-1).content, /CP направить на броню/);
  } finally { mac.server.close(); rtx.server.close(); }
});

test("no enemy planning is issued for the player's own side", async () => {
  const macSeen = [], rtxSeen = [];
  const mac = await modelServer("mac", macSeen), rtx = await modelServer("rtx", rtxSeen);
  try {
    const config = { lmStudio: { baseUrl: rtx.url, model: "rtx-test", timeoutMs: 3000, maxTokens: 200, temperature: 0.8 }, dualEnemy: { enabled: true, strategy: { baseUrl: mac.url, model: "mac-test" } } };
    await complete(config, '["v",3,"ch","AUTONOMY","side","BLUE","playerSide","BLUE"]');
    assert.equal(macSeen.length, 0);
    assert.equal(rtxSeen.length, 1);
  } finally { mac.server.close(); rtx.server.close(); }
});

test("tactical AI stays available if strategic endpoint fails mid-mission", async () => {
  const rtxSeen = [];
  const rtx = await modelServer("rtx", rtxSeen);
  try {
    const config = { lmStudio: { baseUrl: rtx.url, model: "rtx-test", timeoutMs: 3000, maxTokens: 200, temperature: 0.8 }, dualEnemy: { enabled: true, strategy: { baseUrl: "http://127.0.0.1:1/v1", model: "mac-offline", timeoutMs: 500 } } };
    const diagnostics = [];
    const result = await complete(config, '["v",3,"ch","AUTONOMY","side","GREEN","playerSide","BLUE"]', (event) => diagnostics.push(event));
    assert.match(result, /"version":3/);
    assert(diagnostics.includes("Enemy strategy unavailable"));
    assert.equal(rtxSeen.length, 1);
  } finally { rtx.server.close(); }
});

test("launcher and installed package are isolated from Antistasi", () => {
  const launch = JSON.parse(fs.readFileSync(path.join(root, "tools", "warlords-launch.json"), "utf8"));
  assert(!launch.mods.some(mod => /@NeroAI_Antistasi|@Antistasi Ultimate|@DCO GPT/i.test(mod)));
  const config = JSON.parse(fs.readFileSync(path.join(root, "bridge", "neroai3.config.json"), "utf8"));
  assert.equal(config.transport.outboxDb, "NeroWL_out");
  assert.equal(config.transport.inboxDb, "NeroWL_in");
  if (config.dualEnemy.enabled) assert.notEqual(config.dualEnemy.strategy.baseUrl, config.lmStudio.baseUrl);
  else {
    assert.equal(config.lmStudio.model,"openai/gpt-oss-20b");
    assert.equal(config.lmStudio.baseUrl,config.dualEnemy.strategy.baseUrl);
  }
});

test("single-model mode issues one request and retains the shared game doctrine", async () => {
  const seen=[], mac=await modelServer("tactical",seen);
  try {
    await complete({lmStudio:{baseUrl:mac.url,model:"single-mac",timeoutMs:3000,maxTokens:200,temperature:0.9},dualEnemy:{enabled:false}},'["v",3,"ch","AUTONOMY","side","RED","playerSide","BLUE"]');
    assert.equal(seen.length,1);
    assert.match(seen[0].messages[0].content,/URBAN GAMEPLAY/);
    assert.match(seen[0].messages[0].content,/GROUND MOBILITY/);
    assert.match(seen[0].messages[0].content,/BUY HELICOPTER, PLANE or UAV/);
  } finally {mac.server.close();}
});

test("air purchases cross the schema and validation allowlist, code and unknown kinds do not", () => {
  const {buildResponseSchema}=require("../bridge/lm-studio");
  const {validateModelResponse}=require("../bridge/protocol");
  const allowed=buildResponseSchema().schema.properties.actions.items.properties.support.enum;
  for(const kind of ["HELICOPTER","PLANE","UAV"]) {
    assert(allowed.includes(kind));
    const response=validateModelResponse(JSON.stringify({version:3,speech:"Принято",actions:[{type:"BUY",position:[],support:kind}]}));
    assert(response.actions.some(action=>action[0]==="BUY"&&action[2]===kind));
  }
  const rejected=validateModelResponse(JSON.stringify({version:3,speech:"Принято",actions:[{type:"BUY",position:[],support:"NUCLEAR"},{type:"compile",position:[]}]}));
  assert.equal(rejected.actions.length,0);
});

test("Warlords bootstrap keeps waiting when a community mission initializes late", () => {
  const bootstrap = fs.readFileSync(path.join(root, "addons", "NeroAI3", "functions", "bootstrap", "fn_initServer.sqf"), "utf8");
  assert.match(bootstrap, /while \{!_warlordsReady\} do/);
  assert.match(bootstrap, /count _warlords > 0/);
  assert.match(bootstrap, /count _sectors > 0/);
  assert.doesNotMatch(bootstrap, /Warlords mission API was not ready; NeroAI Warlords remains inactive/);
});

// 7.10 dual: the Mac strategist (gpt-oss-20b) plans for both AI armies, the RTX 3060 plans the groups.
test("bothSides gives the player's own AI army the strategist intent too", async () => {
  const macSeen = [], rtxSeen = [];
  const mac = await modelServer("mac", macSeen), rtx = await modelServer("rtx", rtxSeen);
  try {
    const config = { lmStudio: { baseUrl: rtx.url, model: "rtx-test", timeoutMs: 3000, maxTokens: 200, temperature: 0.8 }, dualEnemy: { enabled: true, bothSides: true, strategy: { baseUrl: mac.url, model: "openai/gpt-oss-20b", reasoningEffort: "low", maxTokens: 1500, timeoutMs: 3000 } } };
    await complete(config, '["v",3,"session","m1","ch","AUTONOMY","side","BLUE","playerSide","BLUE"]');
    await complete(config, '["v",3,"session","m1","ch","AUTONOMY","side","RED","playerSide","BLUE"]');
    assert.equal(macSeen.length, 2, "one intent per side");
    assert.equal(macSeen[0].reasoning_effort, "low");
    assert(macSeen[0].max_tokens >= 1500, "gpt-oss reasoning needs token room");
    assert.match(macSeen[0].messages[0].content, /ЦЕЛЬ:[\s\S]*ПОКУПКИ:/);
    assert.match(rtxSeen[0].messages.at(-1).content, /STRATEGIC_INTENT_FROM_MACBOOK=/);
  } finally { mac.server.close(); rtx.server.close(); }
});

test("a failing strategist is retried after a pause, not on every tactical request", async () => {
  let macHits = 0;
  const mac = http.createServer((q, r) => { macHits++; q.resume(); r.writeHead(500); r.end("down"); });
  await new Promise(resolve => mac.listen(0, "127.0.0.1", resolve));
  const rtxSeen = [], rtx = await modelServer("rtx", rtxSeen);
  try {
    const config = { lmStudio: { baseUrl: rtx.url, model: "rtx-test", timeoutMs: 3000, maxTokens: 200, temperature: 0.8 }, dualEnemy: { enabled: true, bothSides: true, strategy: { baseUrl: `http://127.0.0.1:${mac.address().port}/v1`, model: "mac-test", timeoutMs: 2000 } } };
    for (let i = 0; i < 3; i++) assert.match(await complete(config, '["v",3,"session","m1","ch","AUTONOMY","side","RED","playerSide","BLUE"]'), /"version":3/);
    assert.equal(macHits, 1);
    assert.equal(rtxSeen.length, 3);
  } finally { mac.close(); rtx.server.close(); }
});

test("panel dual mode turns the primary into the strategist for both sides", () => {
  const core = require("../control-center/core");
  const state = { nodes: [{ id: "mac", baseUrl: "http://100.113.124.125:1234/v1" }, { id: "rtx", baseUrl: "http://127.0.0.1:1234/v1" }] };
  const cfg = core.makeConfig({ scenario: "warlords", mode: "dual", primaryNode: "mac", primaryModel: "openai/gpt-oss-20b", secondaryNode: "rtx", secondaryModel: "qwen3.5-9b", allyRoute: "separate", allyNode: "rtx", allyModel: "qwen3.5-9b", temperature: .9, maxTokens: 1500, profile: "donko", map: "Australia", dev: true, ace: true, parameters: {} }, state, { lmStudio: {}, transport: {} });
  assert.equal(cfg.dualEnemy.bothSides, true);
  assert.equal(cfg.dualEnemy.strategy.reasoningEffort, "low");
  assert.equal(cfg.lmStudio.baseUrl, "http://127.0.0.1:1234/v1");
  assert.equal(cfg.lmStudio.sides.ALLIED.baseUrl, "http://127.0.0.1:1234/v1", "both armies' groups are planned on the RTX");
});

test("planner schema caps the radio line so a slow local GPU is not spent on prose", () => {
  const { buildResponseSchema } = require("../bridge/lm-studio");
  assert.equal(buildResponseSchema().schema.properties.speech.maxLength, 240);
});

// 8.10: radio silence — AI commanders exchange data only (3060 A/B: 7.1 s -> 3.7 s, 133 -> 45 tokens).
test("radio silence drops speech from the schema and the prompt, and keeps it off the air", () => {
  const { buildRequestPayload, buildResponseSchema } = require("../bridge/lm-studio");
  const silent = buildResponseSchema(true).schema;
  assert.equal(silent.properties.speech, undefined);
  assert.deepEqual(silent.required, ["version", "actions"]);
  assert.equal(buildResponseSchema().schema.properties.speech.maxLength, 240, "radio mode unchanged");
  const lm = { baseUrl: "http://127.0.0.1:1/v1", model: "qwen", maxTokens: 300, temperature: 0.8, structuredOutput: true };
  const payload = buildRequestPayload({ lmStudio: lm, radioSpeech: false }, '["v",3,"ch","AUTONOMY","side","RED"]');
  assert.match(payload.messages[0].content, /RADIO SILENCE/);
  assert.equal(payload.response_format.json_schema.schema.properties.speech, undefined);
  assert.doesNotMatch(buildRequestPayload({ lmStudio: lm }, '["v",3]').messages[0].content, /RADIO SILENCE/);
  assert.match(fs.readFileSync(path.join(root, "bridge", "server.js"), "utf8"), /if \(config\.radioSpeech === false\) \{\s*final\.speech = autonomous \? "" :/);
  assert.equal(JSON.parse(fs.readFileSync(path.join(root, "bridge", "neroai3.config.json"), "utf8").replace(/^﻿/, "")).radioSpeech, false);
  assert.match(fs.readFileSync(path.join(root, "addons", "NeroAI3", "functions", "core", "fn_dispatchResponse.sqf"), "utf8"), /if \(_canSpeak && \{!_silentPlan\}\) then/);
});
