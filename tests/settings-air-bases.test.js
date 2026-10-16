"use strict";
// 7.10 user request: allied LLM from the start, GREEN <= 7 on the map, no fast
// travel, bounded-but-real purchases, aircraft for lift/support/air control,
// bases on airfields, GPT-OSS without grammar-constrained decoding, telemetry.
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const root = path.join(__dirname, "..");
const read = file => fs.readFileSync(path.join(root, file), "utf8");
const fn = name => read(`addons/NeroAI3/functions/${name}`);

test("Australia bases stand beside a real runway of the installed world config", () => {
  const config = read("research/worlds/australia/config-data.bin");
  const ils = name => {
    const at = config.indexOf(`class ${name}`);
    assert(at >= 0, name);
    const m = /ilsPosition\[\]\s*=\s*\{([\d.]+),\s*([\d.]+)\}/.exec(config.slice(at, at + 400));
    return [Number(m[1]), Number(m[2])];
  };
  const { places } = require("../tools/australia-layout");
  const base = name => { const p = places.find(x => x.name === name); assert.equal(p.kind, "Base"); assert.equal(p.runway, true); return [p.position[0], p.position[2]]; };
  const dist = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1]);
  // fn_purchaseAirAsset accepts an airport within 2500 m of the home sector.
  assert(dist(base("Darwin BLUFOR"), ils("ausrunwaydarwin")) < 1000);
  assert(dist(base("South OPFOR"), ils("ausrunwaysydney")) < 1000);
});

test("lobby has a map-wide GREEN cap, default 7, applied to every GREEN spawner", () => {
  const params = read("tools/mission-assets/params.hpp");
  assert.match(params, /class NeroWL_GreenTotal \{.*values\[\]=\{-1,0,4,7,10,15,20,30\}.*default=7;\};/);
  const settings = read("tools/mission-assets/fn_applySettings.sqf");
  assert.match(settings, /NeroWL_greenTotalCap=\["NeroWL_GreenTotal",7,\[-1,0,4,7,10,15,20,30\]\] call _param;/);
  assert.match(settings, /forEach \["NeroWL_greenTotalCap",/);
  assert.match(fn("CfgFunctions.hpp"), /class greenRoom \{\};/);
  const room = fn("core/fn_greenRoom.sqf");
  assert.match(room, /isNil \{/, "reservation is atomic");
  assert.match(room, /side group _x\) isEqualTo resistance/);
  const populate = fn("native/fn_WLSectorPopulate.sqf");
  assert.match(populate, /_greenGrant=\[if \(_neroCap<0\) then \{1000\} else \{_neroCap\}\] call NeroAI_fnc_greenRoom;\s*_neroCap=_greenGrant;/);
  assert.match(populate, /if \(_greenGrant>0\) then \{\[-_greenGrant\] call NeroAI_fnc_greenRoom;\};\s*$/);
  // A capped sector never calls the native response team that would add more GREEN.
  assert.match(populate, /if \(_side == RESISTANCE && \{_neroCap<0\}\)/);
  assert.match(fn("tactical/fn_spawnGreenGarrison.sqf"), /if \(\(\[0\] call NeroAI_fnc_greenRoom\) < 0\) exitWith \{[\s\S]*?deleteVehicle _veh;/);
  assert.equal((fn("tactical/fn_spawnDesignGarrison.sqf").match(/NeroAI_fnc_greenRoom/g) || []).length, 3);
});

test("saved launch profile: allied LLM auto from start, no fast travel, GREEN 7", () => {
  const core = require("../control-center/core");
  const p = core.load().selected.parameters;
  assert.equal(p.NeroWL_FriendlyLLM, 2);
  assert(p.NeroWL_FriendlyLimit >= 10);
  assert.equal(p.BIS_WLFTEnabled, 0);
  assert.equal(p.NeroWL_GreenTotal, 7);
  // Auto mode enrolls on the shared 8 s manage tick with no distance gate.
  const settings = read("tools/mission-assets/fn_applySettings.sqf");
  assert.match(settings, /NeroAI_friendlyAutoEnrollEnabled=NeroWL_friendlyMode==2;/);
  assert.doesNotMatch(fn("tactical/fn_manageFriendlyAI.sqf"), /distance[^;]*>\s*\d{3,}/);
});

test("air groups buy by role before ground gating, refusals are visible, squads take side helicopters", () => {
  const auto = fn("tactical/fn_autoRequisition.sqf");
  const air = auto.indexOf("if (_airRole) exitWith {");
  const groundGate = auto.indexOf("if (!_canBuyInitial && {!_canBuyTail}) exitWith {};");
  assert(air > 0 && groundGate > air, "air branch precedes the on-foot/no-vehicle gate");
  assert.match(auto, /case "AIR_TRANSPORT": \{\["HELICOPTER"\]\}; case "AIR_CAS": \{\["PLANE","HELICOPTER"\]\}; default \{\["PLANE"\]\};/);
  assert.match(auto, /air requisition role=%2 cp %3 refused/);
  assert.match(auto, /NeroWL_lastAirRefusal/);
  assert.match(auto, /\[_group,getPosATL _objective\] call NeroAI_fnc_airTransport;/);
  assert.match(auto, /\(_leader distance2D _objective\) > 2500/);
  assert.match(auto, /NeroAI_airEnemyBaseNoFlyMeters/);
  // Planes for support and air control, helicopters for lift.
  const buyAir = fn("tactical/fn_purchaseAirAsset.sqf");
  assert.match(buyAir, /_kind == "PLANE" && \{_role == "AIR_SUPERIORITY"\}[^;]*_catalogRole == "JET_FIGHTER"/);
  assert.match(buyAir, /_catalogRole in \["AIR_CAS","JET_CAS"\]/);
  assert.match(buyAir, /getNumber \(_cfg >> "transportSoldier"\) >= count/);
  assert.match(fn("tactical/fn_assignDefaultRole.sqf"), /\["AIR_TRANSPORT","AIR_CAS","AIR_SUPERIORITY"\] # _index/);
});

test("purchases are bounded but never silently starved", () => {
  const pre = fn("bootstrap/fn_preInit.sqf");
  assert.match(pre, /NeroAI_purchaseCooldownSeconds = 90;/);
  assert.match(pre, /NeroAI_purchaseSideCooldownSeconds = 75;/);
  // 8.10: two vehicles — the second only as a carrier for a walking tail.
  assert.match(pre, /NeroAI_purchaseMaxVehicles = 2;/);
  assert.match(pre, /NeroAI_purchaseAutoMinCP = 2500;/);
  // Every NeroAI path (ground, air, native FSM) passes the shared side slot.
  assert.match(fn("tactical/fn_purchaseAsset.sqf"), /NeroAI_fnc_claimSidePurchaseSlot/);
  assert.match(fn("tactical/fn_purchaseAirAsset.sqf"), /NeroAI_fnc_claimSidePurchaseSlot/);
  assert.match(fn("tactical/fn_nativeGroundPurchaseAllowed.sqf"), /NeroAI_fnc_claimSidePurchaseSlot/);
  // A destroyed vehicle no longer counts as owned, so the group can buy again.
  assert.match(fn("tactical/fn_autoRequisition.sqf"), /_ownAll = \(_group getVariable \["BIS_WL_groupVehs", \[\]\]\) select \{!isNull _x && \{alive _x\}/);
  for (const name of ["tactical/fn_purchaseAsset.sqf", "tactical/fn_purchaseAirAsset.sqf"]) {
    assert.match(fn(name), /NeroWL_buys_%1[\s\S]*NeroWL_buyRefusals_%1[\s\S]*\n_result\r?\n?$/);
  }
  const telemetry = fn("core/fn_sideTelemetry.sqf");
  for (const field of ["fps=", "cp=", "ground=", "air=", "buys=", "refused=", "green="]) assert(telemetry.includes(field), field);
  assert.match(fn("CfgFunctions.hpp"), /class sideTelemetry \{\};/);
  assert.match(fn("bootstrap/fn_serverLoop.sqf"), /sleep 60;\s*if \(NeroAI_transportReady\) then \{\[\] call NeroAI_fnc_sideTelemetry;\};/);
});

test("GPT-OSS runs without json_schema, with low reasoning and token room; other models unchanged", () => {
  const core = require("../control-center/core");
  const base = { lmStudio: { structuredOutput: true, timeoutMs: 60000 }, transport: { maxPending: 1 }, limits: {} };
  const state = { nodes: [{ id: "mac", label: "Mac", baseUrl: "http://127.0.0.1:1234/v1", apiKey: "k" }] };
  const selection = { ...core.load().selected, mode: "single", primaryNode: "mac", allyRoute: "shared", useDesign: false, map: "Australia", maxTokens: 900 };
  const oss = core.makeConfig({ ...selection, primaryModel: "openai/gpt-oss-20b" }, state, base);
  assert.equal(oss.lmStudio.structuredOutput, false);
  assert.equal(oss.lmStudio.reasoningEffort, "low");
  assert.equal(oss.lmStudio.maxTokens, 1500);
  assert.equal(oss.lmStudio.sides.ALLIED.structuredOutput, false);
  const gemma = core.makeConfig({ ...selection, primaryModel: "google/gemma-4-26b-a4b-qat" }, state, base);
  assert.equal(gemma.lmStudio.structuredOutput, true);
  assert.equal(gemma.lmStudio.reasoningEffort, "none");
  assert.equal(gemma.lmStudio.maxTokens, 900);
  const { buildRequestPayload } = require("../bridge/lm-studio");
  const payload = buildRequestPayload(oss, '["v",3,"ch","AUTONOMY","side","RED"]');
  assert.equal(payload.response_format, undefined);
  assert.equal(payload.reasoning_effort, "low");
  assert.equal(payload.max_tokens, 1500);
});

test("generated native files equal their adapters, so a mission build cannot drop the GREEN cap", () => {
  const { adapt } = require("../tools/adapt-garrison");
  const native = read("research/native/Warlords/fn_WLSectorPopulate.sqf");
  assert.equal(adapt(native), fn("native/fn_WLSectorPopulate.sqf"));
});

test("bridge sends exactly one leading system message (Qwen3.5 templates reject a second one)", async t => {
  const http = require("node:http");
  let seen;
  const server = http.createServer((req, res) => {
    let body = ""; req.on("data", c => body += c); req.on("end", () => {
      seen = JSON.parse(body);
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ choices: [{ message: { content: '{"version":3,"speech":"Гром-2: приём.","actions":[]}' } }] }));
    });
  });
  await new Promise(r => server.listen(0, "127.0.0.1", r));
  t.after(() => server.close());
  const { complete } = require("../bridge/lm-studio");
  const config = { lmStudio: { baseUrl: `http://127.0.0.1:${server.address().port}/v1`, model: "qwen3.5-9b", apiKey: "k", timeoutMs: 5000, maxTokens: 64, temperature: 0.2, structuredOutput: true }, limits: {} };
  await complete(config, '["v",3,"ch","AUTONOMY","side","RED","playerSide","NONE","order","x"]');
  const roles = seen.messages.map(m => m.role);
  assert.equal(roles[0], "system");
  assert.equal(roles.filter(r => r === "system").length, 1);
  assert.match(seen.messages[0].content, /FOG OF WAR: You command only RED/);
});
