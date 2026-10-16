"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { buildMessages, buildRequestPayload, buildResponseSchema } = require("../bridge/lm-studio");

test("LM Studio prompt frames a Takistan-war RP planner that answers questions and requests help", () => {
  const messages = buildMessages("[\"v\",3]");
  assert.ok(messages.length >= 4, "system prompt plus few-shot pairs plus the snapshot");
  assert.equal(messages[0].role, "system");
  assert.match(messages[0].content, /raw JSON object/);
  assert.match(messages[0].content, /Warlords war between two regular armies/);
  assert.match(messages[0].content, /GREEN \(partisans\)/);
  assert.match(messages[0].content, /RED \(regular army\)/);
  assert.match(messages[0].content, /BLUE \(coalition\)/);
  assert.match(messages[0].content, /answer a question/i);
  assert.match(messages[0].content, /REQUEST_SUPPORT/);
  assert.match(messages[0].content, /AMBUSH/);
  assert.match(messages[0].content, /INTERGROUP/);
  assert.doesNotMatch(messages[0].content, /\\\\\"version/);
  assert.equal(messages[messages.length - 1].role, "user");
  assert.match(messages[messages.length - 1].content, /TACTICAL_SNAPSHOT/);
});

test("classic local backend keeps max_tokens, temperature and reasoning_effort", () => {
  const payload = buildRequestPayload({
    lmStudio: { model: "qwen3.5-test", temperature: 0.2, maxTokens: 4096, reasoningEffort: "none" }
  }, "[\"v\",3]");
  assert.equal(payload.model, "qwen3.5-test");
  assert.equal(payload.max_tokens, 4096);
  assert.equal(payload.temperature, 0.2);
  assert.equal(payload.reasoning_effort, "none");
  assert.ok(!("max_completion_tokens" in payload));
  assert.ok(!("response_format" in payload));
});

test("gpt-5 backend uses max_completion_tokens, drops temperature, and can attach a strict JSON schema", () => {
  const payload = buildRequestPayload({
    lmStudio: { model: "gpt-5-mini", temperature: 0.35, maxTokens: 2048, reasoningEffort: "low", structuredOutput: true }
  }, "[\"v\",3]");
  assert.equal(payload.max_completion_tokens, 2048);
  assert.ok(!("max_tokens" in payload));
  assert.ok(!("temperature" in payload));
  assert.equal(payload.reasoning_effort, "low");
  assert.equal(payload.response_format.type, "json_schema");
  assert.equal(payload.response_format.json_schema.name, "neroai_plan");
  assert.equal(payload.response_format.json_schema.strict, true);
});

test("response schema is strict and only lists allowlisted action types", () => {
  const schema = buildResponseSchema().schema;
  assert.equal(schema.additionalProperties, false);
  assert.deepEqual(schema.required, ["version", "speech", "actions"]);
  const types = schema.properties.actions.items.properties.type.enum;
  assert.ok(types.includes("REQUEST_SUPPORT") && types.includes("SHARE_INTEL") && types.includes("AUTONOMY"));
  assert.ok(!types.includes("SQF"));
});

test("4.5.1 a 429 is retried once after the wait the API names, then surfaces", async () => {
  const http = require("node:http");
  let calls = 0;
  const server = http.createServer((req, res) => {
    calls++;
    if (calls === 1) { res.writeHead(429, { "Content-Type": "application/json" }); res.end(JSON.stringify({ error: { message: "Rate limit reached ... Please try again in 20ms." } })); return; }
    res.writeHead(200, { "Content-Type": "application/json" }); res.end(JSON.stringify({ ok: true }));
  });
  await new Promise(r => server.listen(0, "127.0.0.1", r));
  const { requestJson } = require("../bridge/lm-studio");
  const out = await requestJson(`http://127.0.0.1:${server.address().port}/v1/chat/completions`, {}, { a: 1 }, 5000);
  assert.deepEqual(out, { ok: true });
  assert.equal(calls, 2);
  server.close();
});

test("4.7.0b ALLIED/ENEMY side keys resolve against the snapshot's playerSide", () => {
  const { effectiveLmConfig, sideRelation, snapshotPlayerSide } = require("../bridge/lm-studio");
  const config = { lmStudio: { baseUrl: "http://127.0.0.1:1234/v1", model: "local", sides: {
    ALLIED: { baseUrl: "http://127.0.0.1:1234/v1", model: "local" },
    ENEMY: { baseUrl: "http://100.113.124.125:1234/v1", model: "mac" } } } };
  const snap = (side, player) => JSON.stringify(["v", 3, "side", side, "playerSide", player]);
  assert.equal(snapshotPlayerSide(snap("RED", "BLUE")), "BLUE");
  assert.equal(sideRelation("RED", "BLUE"), "ENEMY");
  assert.equal(sideRelation("GREEN", "BLUE"), "ENEMY");
  assert.equal(sideRelation("BLUE", "BLUE"), "ALLIED");
  assert.equal(sideRelation("RED", "RED"), "ALLIED", "the player picked EAST: RED is now the ally");
  assert.equal(effectiveLmConfig(config, snap("RED", "BLUE")).lm.model, "mac");
  assert.equal(effectiveLmConfig(config, snap("GREEN", "BLUE")).lm.model, "mac");
  assert.equal(effectiveLmConfig(config, snap("BLUE", "BLUE")).lm.model, "local");
  assert.equal(effectiveLmConfig(config, snap("RED", "RED")).lm.model, "local");
  assert.equal(effectiveLmConfig(config, snap("BLUE", "RED")).lm.model, "mac");
  /* an exact side key still wins over the relation */
  config.lmStudio.sides.GREEN = { baseUrl: "http://127.0.0.1:1235/v1", model: "tiny" };
  assert.equal(effectiveLmConfig(config, snap("GREEN", "BLUE")).lm.model, "tiny");
  /* shipped config: ally on the RTX 3060, enemy on the MacBook */
  const shipped = JSON.parse(fs.readFileSync(path.join(__dirname, "..", "bridge", "neroai3.config.example.json"), "utf8"));
  assert.deepEqual(Object.keys(shipped.lmStudio.sides).sort(), ["ALLIED", "ENEMY"]);
  assert.match(shipped.lmStudio.sides.ALLIED.baseUrl, /127\.0\.0\.1:1234/);
  assert.match(shipped.lmStudio.sides.ENEMY.baseUrl, /100\.113\.124\.125:1234/);
  assert.doesNotMatch(JSON.stringify(shipped), /sk-lm-[A-Za-z0-9]{6}/);
  const snapshotSqf = fs.readFileSync(path.join(__dirname, "..", "addons", "NeroAI3", "functions", "core", "fn_buildSnapshot.sqf"), "utf8");
  assert.match(snapshotSqf, /"playerSide", _playerSideOut,/);
});

test("4.6.0 per-side brain: an unreachable side endpoint falls back to the primary, a model rejection does not", async () => {
  const http = require("node:http");
  const { complete, isEndpointFailure } = require("../bridge/lm-studio");
  const seen = [];
  const primary = http.createServer((req, res) => {
    let body = "";
    req.on("data", p => { body += p; });
    req.on("end", () => {
      seen.push(JSON.parse(body).model);
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ choices: [{ message: { content: "{\"version\":3,\"speech\":\"ok\",\"actions\":[]}" } }] }));
    });
  });
  await new Promise(r => primary.listen(0, "127.0.0.1", r));
  const dead = http.createServer(() => {});
  await new Promise(r => dead.listen(0, "127.0.0.1", r));
  const deadPort = dead.address().port;
  await new Promise(r => dead.close(r)); // port is now refused
  const config = {
    lmStudio: {
      baseUrl: `http://127.0.0.1:${primary.address().port}/v1`, model: "primary-9b", apiKey: "x", timeoutMs: 3000, maxTokens: 64,
      sides: { RED: { baseUrl: `http://127.0.0.1:${deadPort}/v1`, model: "mac-mlx", apiKey: "y" } }
    }
  };
  const log = [];
  const out = await complete(config, JSON.stringify(["v", 3, "ch", "AUTONOMY", "side", "RED", "groups", []]), (k, v) => log.push(`${k}: ${v}`));
  assert.match(out, /"speech":"ok"/);
  assert.deepEqual(seen, ["primary-9b"], "the primary must answer with its own model after the side endpoint refused");
  assert(log.some(l => /LM endpoint fallback/.test(l)), "the fallback must be visible in the debug log");
  assert(isEndpointFailure(new Error("LM Studio request timed out")));
  assert(isEndpointFailure(Object.assign(new Error("connect ECONNREFUSED"), { code: "ECONNREFUSED" })));
  assert(!isEndpointFailure(new Error("LM Studio HTTP 400: model not found")));
  primary.close();
});
