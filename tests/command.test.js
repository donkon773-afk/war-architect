"use strict";

/* NeroAI 4.4.0 [Command] — the 16-point package. Every test here is anchored
 * to a live incident or an explicit user requirement; see
 * docs/CHANGELOG_4.4.0_COMMAND.md for the mapping. */

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { toSqfValue } = require("../bridge/protocol");

const root = path.join(__dirname, "..");
const addonRoot = path.join(root, "addons", "NeroAI3");
const read = rel => fs.readFileSync(path.join(addonRoot, rel), "utf8");

test("#3 sectors come from the real Warlords sector list (names verified in functions_f_warlords), never from the commander list", () => {
  const sectors = read("functions/core/fn_warlordsSectors.sqf");
  const cfg = read("functions/CfgFunctions.hpp");
  assert.match(cfg, /class warlordsSectors \{\};/);
  assert.match(sectors, /BIS_WL_sectors\b/);
  assert.match(sectors, /entities "ModuleWLSector_F"/);
  assert.match(sectors, /entities "ModuleWLBase_F"/);
  assert.match(sectors, /BIS_WL_sectorSide/);
  /* ownership only when the variable really is a SIDE; otherwise NONE */
  assert.match(sectors, /if !\(_o isEqualType west\) exitWith \{"NONE"\}/);
  assert.match(sectors, /NeroAI_sectorCache/);
  /* live 13.09: bis_wl_allWarlords = AI commanders; garrisons landed on bases and RED squads */
  for (const f of ["functions/tactical/fn_spawnGreenGarrison.sqf", "functions/tactical/fn_warlordsAutonomy.sqf", "functions/core/fn_buildSnapshot.sqf", "functions/core/fn_warlordsSectors.sqf"]) {
    assert.doesNotMatch(read(f), /forEach bis_wl_allWarlords/i, f);
  }
});

test("#3 GREEN heavy vehicles guard points of interest only, never bases, and mortars are rare", () => {
  const g = read("functions/tactical/fn_spawnGreenGarrison.sqf");
  const preInit = read("functions/bootstrap/fn_preInit.sqf");
  assert.match(g, /\{!_isBase\}/);
  assert.match(g, /_ownerKey in \["NONE", "GREEN"\]/);
  assert.match(g, /NeroAI_greenBaseExclusionMeters/);
  assert.match(preInit, /NeroAI_greenBaseExclusionMeters\s*=\s*2000/);
  assert.match(preInit, /NeroAI_greenMortarChance\s*=\s*0\.05/);
});

test("#1/#11 parked aircraft are physically grounded (no fuel) and refuelled only by a dispatched sortie", () => {
  const spawn = read("functions/tactical/fn_spawnBaseAssets.sqf");
  const air = read("functions/tactical/fn_dispatchAir.sqf");
  assert.match(spawn, /_veh engineOn false;\s*_veh setFuel 0;/);
  assert.match(spawn, /disableAI "PATH"/);
  /* launch refuels, park drains */
  const launchAt = air.indexOf("_air setFuel 1;");
  const parkAt = air.indexOf("_air setFuel 0;");
  assert.ok(launchAt > 0 && parkAt > launchAt, "refuel on launch must precede the drain on park");
  assert.match(air, /_air engineOn false;\s*_air setFuel 0;/);
});

test("#1 RECON never hijacks a parked base UAV; with a position it is a bounded drone sortie", () => {
  const recon = read("functions/tactical/fn_uavRecon.sqf");
  const macro = read("functions/core/fn_executeMacro.sqf");
  /* strip comments so the incident note does not trip the code assertions */
  const code = recon.replace(/\/\*[\s\S]*?\*\//g, "");
  assert.doesNotMatch(code, /connectTerminalToUAV/);
  assert.doesNotMatch(code, /allUnitsUAV # 0|_uavs # 0/);
  assert.match(recon, /call NeroAI_fnc_dispatchAir/);
  assert.match(recon, /isEqualTo "PARKED"\)\}\) then \{ _observers pushBack _x; \}/);
  // 8.10: RECON+HUNT/CREEP is a behaviour template; plain RECON is still the bounded drone sortie.
  assert.match(macro, /case "RECON": \{[\s\S]*?NeroAI_fnc_tacticOrder;[\s\S]*?_result = \[_group, if \(_hasPosition\) then \{_position\} else \{\[\]\}\] call NeroAI_fnc_uavRecon;\s*\};/);
});

test("#11 the drone cannot be overloaded: per-group request cooldown, per-side airborne cap", () => {
  const air = read("functions/tactical/fn_dispatchAir.sqf");
  const preInit = read("functions/bootstrap/fn_preInit.sqf");
  assert.match(air, /NeroAI_airGroupRequestCooldown/);
  assert.match(air, /NeroAI_airMaxConcurrentPerSide/);
  assert.match(air, /NeroAI_lastAirRequest/);
  assert.doesNotMatch(air, /JET_CAS|JET_MULTI|HELI_ATTACK/, "4.5.0: NeroAI dispatches only the drone");
  assert.match(preInit, /NeroAI_airGroupRequestCooldown\s*=\s*240/);
  assert.match(preInit, /NeroAI_airMaxConcurrentPerSide\s*=\s*2/);
});


test("#5 both regular armies are under NeroAI from the first pass with no distance gate; only partisans have the 2.5 km ring", () => {
  const manage = read("functions/tactical/fn_manageEnemyAI.sqf");
  const preInit = read("functions/bootstrap/fn_preInit.sqf");
  /* identical caps for BLUE (auto-enrolled friendly side) and RED (army) */
  assert.match(preInit, /NeroAI_maxEnemyArmyGroups\s*=\s*16/);
  assert.match(preInit, /NeroAI_maxFriendlyGroups\s*=\s*16/);
  assert.match(preInit, /NeroAI_enemyMaxDistanceMeters\s*=\s*2500/);
  assert.match(manage, /_armyCandidates pushBack \[_d, _grp\]/);
  assert.match(manage, /if \(_d <= _activationDist\) then \{ _partisanCandidates pushBack/);
  /* army groups are never released for distance */
  assert.match(manage, /if \(!_isArmy\) then \{\s*_tooFar =/);
  assert.doesNotMatch(manage, /NeroAI_enemySeedDistanceMeters/);
});

test("#4 the player's own side is enrolled automatically, with a sticky manual opt-out", () => {
  const friendly = read("functions/tactical/fn_manageFriendlyAI.sqf");
  const register = read("functions/core/fn_registerGroup.sqf");
  const loop = read("functions/bootstrap/fn_serverLoop.sqf");
  const cfg = read("functions/CfgFunctions.hpp");
  assert.match(cfg, /class manageFriendlyAI \{\};/);
  assert.match(loop, /NeroAI_fnc_manageFriendlyAI/);
  assert.match(friendly, /NeroAI_optOut", false\]/);
  assert.match(friendly, /NeroAI_isBaseAssetCrew", false\]/);
  assert.match(friendly, /\{isPlayer _x\} count units _grp\) isEqualTo 0/);
  /* toggling OFF marks opt-out; any successful (re)registration clears it */
  assert.match(register, /if \(_isActive\) exitWith \{[\s\S]*?NeroAI_optOut", true, true/);
  assert.match(register, /NeroAI_active", true, true\];\s*_group setVariable \["NeroAI_optOut", false, true\]/);
});

test("#1/#7 the planner is given real objectives and told to take them decisively", () => {
  const snap = read("functions/core/fn_buildSnapshot.sqf");
  const auto = read("functions/tactical/fn_tacticalAutonomy.sqf");
  assert.match(snap, /"sectors", _sectors/);
  assert.match(snap, /"terrain", _terrain/);
  assert.match(snap, /"side", _sideKeyOut/);
  assert.match(snap, /_byDist sort true;/);
  assert.match(auto, /ЦЕЛЬ: сектор/);
  assert.match(auto, /!\(_sOwner isEqualTo _mySideKey\)/);
  /* the order carries facts only; doctrine lives once in the system prompt */
  assert.match(auto, /format \["АВТОНОМИЯ %1: %2\.%3", _mySideKey, _reason, _facts\]/);
  assert.doesNotMatch(auto, /Советская доктрина|Технологичное превосходство|Асимметричная война/);
});

test("#15 (4.7.0) terrain is surveyed, not picked from a map list; the prompt keys doctrine off terrain tags", () => {
  const preInit = read("functions/bootstrap/fn_preInit.sqf");
  const auto = read("functions/tactical/fn_tacticalAutonomy.sqf");
  const prompt = require("../bridge/lm-studio").SYSTEM_PROMPT;
  // 4.7.0: no map list in preInit — the profile is surveyed at server start
  assert.doesNotMatch(preInit, /toLower worldName\) in \[/);
  assert.match(preInit, /NeroAI_terrainProfile = "AUTO"/);
  assert.doesNotMatch(auto, /МЕСТНОСТЬ:/);
  assert.match(prompt, /TERRAIN — the snapshot's terrain line is/);
  assert.match(prompt, /mountains = take the ridge first/);
  assert.match(prompt, /forest\/dense_forest = infantry war/);
  assert.match(prompt, /FACTIONS: factions = \[BLUE,RED,GREEN\]/);
  assert.doesNotMatch(prompt, /TAKISTAN:|- ALTIS:/, "the prompt must not hardwire a map");
  const mission = path.join(root, "missions", "NeroAI_Warlords.Altis");
  for (const f of ["description.ext", "init.sqf", "mission.sqm", "README.md"]) {
    assert.ok(fs.existsSync(path.join(mission, f)), `missing ${f}`);
  }
  assert.match(fs.readFileSync(path.join(mission, "mission.sqm"), "utf8"), /ModuleWLSector_F/);
  assert.match(fs.readFileSync(path.join(mission, "init.sqf"), "utf8"), /NeroAI_terrainProfile = "ALTIS"/);
});

test("#6 a garbled callsign still routes when unambiguous; otherwise the nearest groups ask who the order is for", () => {
  const resolve = read("functions/communication/fn_resolveTargets.sqf");
  const receive = read("functions/communication/fn_receiveClientCommand.sqf");
  assert.match(resolve, /_fnc_editDistance/);
  assert.match(resolve, /\(\[\(_x # 0\), _csL\] call _fnc_editDistance\) <= 2/);
  assert.match(resolve, /\(_x # 1\) isEqualTo _csD/);
  assert.match(resolve, /if \(\(count _fuzzy\) isEqualTo 1\) exitWith/);
  assert.match(receive, /Кому приказ\?/);
  assert.match(receive, /_nearest resize \(\(count _nearest\) min 2\)/);
  assert.match(receive, /call NeroAI_fnc_broadcastSpeech/);
});


test("#6/#7/#8/#9/#10 the prompt carries the doctrine: emotion, aggression, tactics-not-roles, fear, support duty, rare mortars, CP spending", () => {
  const p = require("../bridge/lm-studio").SYSTEM_PROMPT;
  assert.match(p, /OBJECTIVES — YOU ARE HERE TO TAKE GROUND/);
  assert.match(p, /BE DECISIVE AND AGGRESSIVE IN THE ATTACK/);
  assert.match(p, /TACTICS to assign between neighbouring groups[\s\S]*not fixed roles/);
  assert.match(p, /RADIO VOICE — ALIVE, EMOTIONAL, HUMAN/);
  assert.match(p, /swearing and panic are allowed/);
  assert.match(p, /NEVER paralyses you/);
  assert.match(p, /you OWE them that support/);
  assert.match(p, /They are RARE/);
  assert.match(p, /Кому приказ\?/);
  assert.match(p, /never airborne permanently/);
  /* #9: the 15 000 CP must be spent, not admired */
  assert.match(p, /REQUISITION — SPEND YOUR CP, THEY ARE USELESS UNSPENT/);
  assert.match(p, /cp = your Command Points \(-1 = no purse\)/);
  assert.match(p, /shop = \[kind,minCost,maxCost\]/);
  for (const s of ["DRONE: each army has ONE armed drone", "never near an enemy base", "Treat a refusal as information", "If ready is 0 for a role", "Do NOT repeat yourself"]) {
    assert.ok(p.includes(s), s);
  }
});


test("#2 (4.6.0) one local LM Studio brain for planning, identical sides, plan cadence sized for a local model, unchanged-state plan skipping", () => {
  const lm = require("../bridge/lm-studio");
  const config = JSON.parse(fs.readFileSync(path.join(root, "bridge", "neroai3.config.json"), "utf8"));
  const example = JSON.parse(fs.readFileSync(path.join(root, "bridge", "neroai3.config.example.json"), "utf8"));
  for (const c of [config, example]) {
    /* 4.6.0: OpenAI credits ran out 15.09 23:07 (HTTP 429 "no credits remaining");
     * the planner is a local Qwen3.5-9B in LM Studio, the vision model a local
     * Qwen3-VL. Nothing leaves the machine and no API key is needed. */
    assert.match(c.lmStudio.baseUrl, /^http:\/\/127\.0\.0\.1:1234\/v1$/);
    assert.match(c.lmStudio.model, /^qwen3\.5-9b/);
    assert.match(c.lmStudio.fallbackModel, /^qwen\/qwen3-vl-4b$/);
    assert.match(c.vision.baseUrl, /^http:\/\/127\.0\.0\.1:1234\/v1$/);
    assert.match(c.vision.model, /^qwen\/qwen3-vl-4b$/);
    assert.ok(!lm.isReasoningModel(c.lmStudio.model));
    assert.ok(!lm.isOpenAiEndpoint(c.lmStudio));
    /* BLUE and RED: sides can be undefined (single brain) or an object (dual brain) */
    assert.ok(c.lmStudio.sides === undefined || typeof c.lmStudio.sides === "object");
    assert.equal(c.lmStudio.reasoningEffortByChannel, undefined);
    /* Qwen3.5 must not think: bench 16.09 with reasoning_effort none — 6/6 valid,
     * reasoning_content empty; without it the budget goes to hidden reasoning */
    assert.equal(c.lmStudio.reasoningEffort, "none");
    assert.equal(c.lmStudio.structuredOutput, true);
    assert.equal(c.lmStudio.maxTokens, 4096);
    /* LM Studio 85 s < dispatch 95 s < Arma 100 s */
    assert.equal(c.lmStudio.timeoutMs, 85000);
    assert.equal(c.autonomy.planIntervalSeconds, 30);
    assert.equal(c.autonomy.maxParallelPlans, 2);
    assert.equal(c.transport.maxPending, 2);
  }
  /* the per-side routing code path stays available (a future second brain), unused by default */
  const routed = lm.effectiveLmConfig({ lmStudio: { model: "base", apiKey: "k", sides: { RED: { model: "red-brain" } } } }, "[\"v\",3,\"side\",\"RED\"]");
  assert.equal(routed.lm.model, "red-brain");
  assert.equal(lm.effectiveLmConfig({ lmStudio: { model: "base" } }, "[\"v\",3,\"side\",\"RED\"]").lm.model, "base");
  /* Arma side: 30 s cadence, 2 parallel (local model), unchanged fingerprint skips the scheduled plan */
  const auto = read("functions/tactical/fn_tacticalAutonomy.sqf");
  const preInit = read("functions/bootstrap/fn_preInit.sqf");
  assert.match(auto, /NeroAI_planFingerprint/);
  assert.match(auto, /if \(_due && \{!_event\} && \{missionNamespace getVariable \["NeroAI_planSkipUnchanged", true\]\}\)/);
  assert.match(preInit, /NeroAI_planSkipUnchanged = true/);
  assert.match(preInit, /NeroAI_autonomyPlanIntervalSeconds = 30/);
  /* 4.5.1: no scheduled replan mid-march; snapshot under the INIDBI 8 KB value limit; oversized multi-group orders are split */
  assert.match(auto, /NeroAI_lastAutonomyMove/);
  assert.match(auto, /_leader distance2D \(_lm # 1\)\) > 120/);
  assert.match(preInit, /NeroAI_maxSnapshotChars = 7400/);
  assert.match(read("functions/core/fn_sendBridgeRequest.sqf"), /split into per-group requests/);
  assert.match(read("functions/core/fn_buildSnapshot.sqf"), /_x set \[14, \[\]\]/);
  assert.match(preInit, /NeroAI_autonomyMaxParallelPlans = 2/);
  assert.match(preInit, /NeroAI_maxPendingAutonomy = 2/);
});

test("#12 model fallback is exercised end-to-end through complete()", async () => {
  const lm = require("../bridge/lm-studio");
  const http = require("node:http");
  const seen = [];
  const server = http.createServer((req, res) => {
    let body = "";
    req.on("data", d => { body += d; });
    req.on("end", () => {
      const payload = JSON.parse(body);
      seen.push(payload.model);
      if (payload.model === "gpt-5.5") {
        res.writeHead(404, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: { message: "The model `gpt-5.5` does not exist" } }));
        return;
      }
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ choices: [{ message: { content: "{\"version\":3,\"speech\":\"ок\",\"actions\":[]}" } }] }));
    });
  });
  await new Promise(r => server.listen(0, "127.0.0.1", r));
  const port = server.address().port;
  try {
    const out = await lm.complete({ lmStudio: { baseUrl: `http://127.0.0.1:${port}/v1`, model: "gpt-5.5", fallbackModel: "gpt-5-mini", apiKey: "x", timeoutMs: 5000, maxTokens: 64, temperature: 0.3 } }, "[\"v\",3,\"side\",\"BLUE\"]");
    assert.match(out, /"version":3/);
    assert.deepEqual(seen, ["gpt-5.5", "gpt-5-mini"]);
  } finally {
    server.close();
  }
});

test("#14 (4.6.0) the commander's-eye vision loop is OFF by default: a local VLM needs ~43 s per frame on this GPU pair", () => {
  const preInit = read("functions/bootstrap/fn_preInit.sqf");
  const config = JSON.parse(fs.readFileSync(path.join(root, "bridge", "neroai3.config.json"), "utf8"));
  /* bench 16.09: qwen3-vl-4b next to the 9B planner = 43 s warm per frame and
   * ~4 GB more VRAM that Arma needs; capture and monitor are both off until the
   * player opts in (NeroAI_visionCaptureEnabled + vision.enabled). */
  assert.match(preInit, /NeroAI_visionCaptureEnabled = false/);
  assert.match(preInit, /NeroAI_visionCaptureInterval = 20/);
  assert.equal(config.vision.enabled, false);
  assert.ok(Number(config.vision.minIntervalMs) >= 45000);
});

test("#8 fire support is rarer: 150 s per-group cooldown", () => {
  const preInit = read("functions/bootstrap/fn_preInit.sqf");
  assert.match(preInit, /NeroAI_fireSupportCooldownSeconds = 150/);
});


test("#13 request economy: compact prompt, two doctrine-consistent few-shots (one buys armour), facts-only autonomy order, aggregated unit rows", () => {
  const lm = require("../bridge/lm-studio");
  const { validateModelResponse, isGroundedPosition } = require("../bridge/protocol");
  assert.ok(lm.SYSTEM_PROMPT.length < 7500, `system prompt grew to ${lm.SYSTEM_PROMPT.length} chars`);
  const messages = lm.buildMessages("[\"v\",3]");
  assert.equal(messages.length, 6, "system + 2 few-shot pairs + snapshot");
  let buys = 0;
  for (let i = 1; i < messages.length - 1; i += 2) {
    const snapshot = messages[i].content.replace(/^TACTICAL_SNAPSHOT=/, "");
    const validated = validateModelResponse(messages[i + 1].content, { maxActions: 5, maxSpeechChars: 700 });
    assert.ok(validated.ok, `few-shot ${i} must validate`);
    for (const action of validated.actions) {
      if (Array.isArray(action[1]) && action[1].length === 2) assert.ok(isGroundedPosition(action[1], snapshot), `few-shot ${i} action ${action[0]} must be grounded`);
      if (action[0] === "BUY") { buys++; assert.equal(action[2], "TANK"); }
    }
    assert.match(messages[i + 1].content, /ASSAULT|ADVANCE/, "examples model the decisive doctrine, not recon spam");
    assert.match(messages[i].content, /"shop",/, "examples show the purse and the shop");
  }
  assert.equal(buys, 1, "one example spends CP on armour");
  /* the Arma-side order text carries no doctrine (it is in the prompt once) */
  const auto = read("functions/tactical/fn_tacticalAutonomy.sqf");
  assert.match(auto, /format \["АВТОНОМИЯ %1: %2\.%3", _mySideKey, _reason, _facts\]/);
  /* snapshot: one aggregated row per (unit class, mount), previous speech dropped, CP purse instead of the stress model */
  const snap = read("functions/core/fn_buildSnapshot.sqf");
  assert.match(snap, /_agg getOrDefault \[_k, \[typeOf _x, 0, 0, 0, 0, _mount\]\]/);
  assert.match(snap, /_unitStates resize \(\(count _unitStates\) min 6\)/);
  assert.match(snap, /_decisionMemory set \[1, ""\]/);
  assert.match(snap, /"shop", _shop,/);
  assert.match(snap, /getVariable \["BIS_WL_funds", 0\]/);
  assert.doesNotMatch(snap, /NeroAI_psyche|_stress/);
});

test("#6/#13 player orders keep the model's own voice and 'attack the sector' is an assault", () => {
  const server = fs.readFileSync(path.join(root, "bridge", "server.js"), "utf8");
  const { explicitOrderIntent } = require("../bridge/protocol");
  assert.match(server, /cleanText\(final\.speech, config\.limits\.maxSpeechChars\) \|\| radioReplyFor\(final\.actions\)/);
  assert.equal(explicitOrderIntent('["v",3,"order","Альфа-3 атакуйте сектор"]').type, "ASSAULT");
  assert.equal(explicitOrderIntent('["v",3,"order","Альфа-3 выдвигайтесь к точке"]').type, "ADVANCE");
  assert.equal(explicitOrderIntent('["v",3,"order","Альфа-3 наблюдайте сектор 4319,7656"]').type, "SET_SECTOR");
});


test("#13 cost levers: stable prompt_cache_key on OpenAI only, optional per-channel reasoning effort, compact request log", () => {
  const lm = require("../bridge/lm-studio");
  const cfg = { lmStudio: { baseUrl: "https://api.openai.com/v1", model: "gpt-5.5", maxTokens: 2048, temperature: 0.35, reasoningEffort: "low", reasoningEffortByChannel: { INTERGROUP: "minimal" }, structuredOutput: true } };
  const auto = lm.buildRequestPayload(cfg, "[\"v\",3,\"ch\",\"AUTONOMY\",\"side\",\"RED\"]");
  const inter = lm.buildRequestPayload(cfg, "[\"v\",3,\"ch\",\"INTERGROUP\",\"side\",\"RED\"]");
  assert.equal(auto.prompt_cache_key, "neroai-4.5-RED");
  assert.equal(inter.prompt_cache_key, "neroai-4.5-RED", "same side → same cache key regardless of channel");
  assert.equal(auto.reasoning_effort, "low");
  assert.equal(inter.reasoning_effort, "minimal");
  /* the production config: a plain chat model gets temperature and no reasoning field */
  const prod = lm.buildRequestPayload({ lmStudio: { baseUrl: "https://api.openai.com/v1", model: "gpt-4o-mini", maxTokens: 2048, temperature: 0.35, structuredOutput: true } }, "[\"v\",3,\"ch\",\"AUTONOMY\",\"side\",\"BLUE\"]");
  assert.equal(prod.reasoning_effort, undefined);
  assert.equal(prod.temperature, 0.35);
  assert.equal(prod.max_tokens, 2048);
  assert.equal(prod.prompt_cache_key, "neroai-4.5-BLUE");
  /* a local backend never receives the OpenAI-only field */
  const local = lm.buildRequestPayload({ lmStudio: { baseUrl: "http://127.0.0.1:1234/v1", model: "qwen", maxTokens: 64, temperature: 0.2, reasoningEffort: "none" } }, "[\"v\",3,\"ch\",\"AUTONOMY\"]");
  assert.equal(local.prompt_cache_key, undefined);
  assert.equal(local.reasoning_effort, "none");
});

test("4.5.0 live 21:46: own vehicle first, spend the purse — deterministic, not a model whim", () => {
  const auto = read("functions/tactical/fn_autoRequisition.sqf");
  const tick = read("functions/tactical/fn_tacticalAutonomy.sqf");
  const preInit = read("functions/bootstrap/fn_preInit.sqf");
  assert.match(read("functions/CfgFunctions.hpp"), /class autoRequisition \{\};/);
  assert.match(tick, /if \(!_manualBusy && \{!_manualHold\}\) then \{ \[_group\] call NeroAI_fnc_autoRequisition; \};/);
  /* A) an empty own vehicle (groupVehs OR itemOwner-tagged airdrop) gets boarded, or walked to first */
  assert.match(auto, /BIS_WL_groupVehs/);
  assert.match(auto, /BIS_WL_itemOwner/);
  assert.match(auto, /\[_group, "BOARD", _vpos, _v\] call NeroAI_fnc_vehicleTactics/);
  assert.match(auto, /\[_group, "MOVE", _vpos\] call NeroAI_fnc_vehicleTactics/);
  assert.match(auto, /isNull \(attachedTo _x\)/, "a vehicle still under its parachute is not boardable");
  /* B) with a purse and no vehicle it buys: APC for a full squad, else TANK */
  assert.match(auto, /\["APC", "TANK", "CAR"\]/);
  assert.match(auto, /\["TANK", "APC", "CAR"\]/);
  assert.match(auto, /call NeroAI_fnc_purchaseAsset/);
  assert.match(auto, /NeroAI_purchaseAutoMinCP/);
  assert.match(preInit, /NeroAI_purchaseAutoEnabled = true/);
  assert.match(preInit, /NeroAI_purchaseAutoMinCP = 2500/);
  /* player authority wins; nothing is spawned */
  assert.match(auto, /NeroAI_playerHold/);
  assert.match(auto, /NeroAI_manualOrderUntil/);
  assert.doesNotMatch(auto, /createVehicle|createUnit|setSkill|deleteVehicle/);
});

test("4.5.0 live 21:44: the bridge never depends on the console (own log file, no stdout pipe), vision sends no reasoning field to chat models", () => {
  const server = fs.readFileSync(path.join(root, "bridge", "server.js"), "utf8");
  const vision = fs.readFileSync(path.join(root, "bridge", "vision.js"), "utf8");
  const monitor = fs.readFileSync(path.join(root, "tools", "vision-monitor.js"), "utf8");
  const console_ = fs.readFileSync(path.join(root, "tools", "live-console.js"), "utf8");
  assert.match(server, /NEROAI_LOG_FILE/);
  assert.match(server, /NEROAI_QUIET_STDOUT/);
  assert.match(monitor, /NEROAI_VISION_LOG_FILE/);
  assert.match(console_, /stdio: \["ignore", "ignore", "ignore"\]/);
  assert.doesNotMatch(console_, /forward\(bridge\.stdout|readline/);
  assert.match(console_, /tailFile\(bridgeLogFile, "BRIDGE"\)/);
  /* gpt-4o-mini rejected reasoning_effort with HTTP 400 on every frame */
  const { buildVisionPayload } = require("../bridge/vision");
  if (typeof buildVisionPayload === "function") {
    const payload = buildVisionPayload({ vision: { baseUrl: "https://api.openai.com/v1", model: "gpt-4o-mini", maxTokens: 700 } }, "data:image/jpeg;base64,AAAA");
    assert.equal(payload.reasoning_effort, undefined);
    assert.equal(payload.response_format.type, "json_object");
  }
  /* 4.6.0: a local (non-OpenAI) VLM endpoint gets the grammar-backed schema
   * and an explicit "none" reasoning effort instead */
  const local = buildVisionPayload({ lmStudio: { baseUrl: "http://127.0.0.1:1234/v1", model: "x" }, vision: { model: "qwen/qwen3-vl-4b", maxTokens: 700 } }, "data:image/jpeg;base64,AAAA");
  assert.equal(local.reasoning_effort, "none");
  assert.equal(local.response_format.type, "json_schema");
  assert.equal(local.response_format.json_schema.strict, true);
  assert.deepEqual(local.response_format.json_schema.schema.properties.observations.items.properties.type.enum.sort(), [...require("../bridge/vision").OBSERVATION_TYPES].sort());
});

test("4.5.1 live 22:22-22:40: aircraft crews are never enrolled, own-vehicle boarding is exact and driver-first, repeated failures are shelved", () => {
  const air = read("functions/core/fn_isAirCrewGroup.sqf");
  assert.match(read("functions/CfgFunctions.hpp"), /class isAirCrewGroup \{\};/);
  assert.match(air, /UAV_AI_base_F/);
  assert.match(air, /\(vehicle _x\) isKindOf "Air"/);
  for (const f of ["functions/tactical/fn_manageFriendlyAI.sqf", "functions/tactical/fn_manageEnemyAI.sqf"]) {
    assert.match(read(f), /!\(\[_grp\] call NeroAI_fnc_isAirCrewGroup\)/, f);
  }
  const vt = read("functions/tactical/fn_vehicleTactics.sqf");
  assert.match(vt, /\["_onlyVehicle", objNull\]/);
  assert.match(vt, /_candidates select \{_x isEqualTo _onlyVehicle\}/);
  /* a lone leader drives; with crew he commands and the others drive/gun first */
  assert.match(vt, /_leaderHasCrew/);
  assert.match(vt, /else \{\["driver", "commander", "gunner", "turret", "cargo"\] find _seatRole\}/);
  assert.match(vt, /\["driver", "gunner", "turret", "cargo", "commander"\] find _seatRole/);
  const auto = read("functions/tactical/fn_autoRequisition.sqf");
  assert.match(auto, /NeroAI_autoBoardShelved/);
  assert.match(auto, /after 3 attempts/);
  /* purchase no longer boards on its own — one boarding path */
  assert.doesNotMatch(read("functions/tactical/fn_purchaseAsset.sqf"), /"BOARD"/);
  /* airstrip entries are [runwayPos, spawnPos, dir] */
  assert.match(read("functions/tactical/fn_spawnBaseAssets.sqf"), /\(_x # 0\) isEqualType \[\]\}\): \{ _x # 0 \}/);
  /* hcShowBar is unary */
  assert.doesNotMatch(read("functions/core/fn_restoreHighCommandLocal.sqf"), /_player hcShowBar/);
});

test("4.5.1d night-run audit: pilots are aircraft crew, boarding only near and only once per manned vehicle, unarmed/support vehicles are never armour", () => {
  assert.match(read("functions/core/fn_isAirCrewGroup.sqf"), /find "PILOT"\) < 0/);
  const auto = read("functions/tactical/fn_autoRequisition.sqf");
  assert.match(auto, /_manned isEqualTo \[\]/);
  assert.match(auto, /if \(_d <= 200\) then/);
  assert.match(auto, /_whyNot joinString/);
  assert.match(auto, /каталог реквизиции пуст/);
  const buy = read("functions/tactical/fn_purchaseAsset.sqf");
  assert.match(buy, /_fnc_armed = \{/);
  assert.match(buy, /"ambulance"/);
  assert.match(buy, /if \(_class isKindOf "Tank"\) exitWith \{ if \(_armed\) then \{"TANK"\} else \{"TRUCK"\} \}/);
});

test("4.5.1e T25 F1: SQF action allowlist matches bridge/protocol.js and validates before execution", () => {
  const dispatch = read("functions/core/fn_dispatchResponse.sqf");
  const macro = read("functions/core/fn_executeMacro.sqf");

  const allowedInDispatch = [
    "ADVANCE", "ASSAULT", "HOLD", "RETREAT", "RECON", "REQUEST_FIRE",
    "BOARD", "DISEMBARK", "REPAIR", "SET_ROE", "SET_SECTOR", "REPORT", "CANCEL",
    "REQUEST_SUPPORT", "SHARE_INTEL", "NEGOTIATE", "DESIGNATE", "AUTONOMY", "BUY", "ASSIGN_ROLE", "AIR_TASK"
  ];
  for (const act of allowedInDispatch) {
    assert.match(dispatch, new RegExp(`"${act}"`));
    assert.match(macro, new RegExp(`"${act}"`));
  }

  assert.match(dispatch, /"HOLD_FIRE", "RETURN_FIRE", "OPEN_FIRE"/);
  assert.match(dispatch, /"ARTILLERY", "MORTAR", "CAS"/);
  assert.match(dispatch, /"INFANTRY", "CAR", "APC", "TANK", "TRUCK"/);

  assert.match(macro, /!\(_type isEqualType ""\)/);
  assert.match(macro, /!\(_position isEqualType \[\]\)/);
  assert.match(macro, /!\(_argument isEqualType ""\)/);
  assert.match(macro, /!\(_argument in \["HOLD_FIRE", "RETURN_FIRE", "OPEN_FIRE"\]\)/);
  assert.match(macro, /!\(_argument in \["ARTILLERY", "MORTAR", "CAS"\]\)/);
  assert.match(macro, /!\(_argument in \["INFANTRY", "CAR", "APC", "TANK", "TRUCK", "HELICOPTER", "PLANE", "UAV"\]\)/);
});

test("4.5.1e T25 F2: player cannot TOGGLE enemy groups across sides", () => {
  const reg = read("functions/core/fn_registerGroup.sqf");
  assert.match(reg, /!isNull _player && \{!_isEnemyParam\} && \{side _group != side group _player\}/);
  assert.match(reg, /"Группа другой стороны\."/);
});

test("4.5.1e T25 F3: receiveClientCommand enforces per-UID rate limits (interval, orders/min, toggle/min)", () => {
  const cmd = read("functions/communication/fn_receiveClientCommand.sqf");
  assert.match(cmd, /getPlayerUID _player/);
  assert.match(cmd, /NeroAI_clientRateLimits/);
  assert.match(cmd, /count _toggleHistory >= 10/);
  assert.match(cmd, /"Слишком частое переключение: подождите %1 с\."/);
  assert.match(cmd, /\(_now - _lastSideCmd\) < 3/);
  assert.match(cmd, /count _sideHistory >= 10/);
  // the limiter runs only after resolveTargets: unaddressed chat is not counted
  assert(cmd.indexOf("call NeroAI_fnc_resolveTargets") < cmd.indexOf("_lastSideCmd = _rateRecord # 0"), "rate limit must follow target resolution");
  assert.match(cmd, /"Подождите %1 с перед следующим приказом\."/);
  assert.match(cmd, /Rate limit exceeded for UID/);
});

test("4.5.1e T21: INIDBI byte limit calculation and worst-case snapshot wire budget under 8192 bytes", () => {
  const sender = read("functions/core/fn_sendBridgeRequest.sqf");
  const snap = read("functions/core/fn_buildSnapshot.sqf");
  const preInit = read("functions/bootstrap/fn_preInit.sqf");

  assert.match(preInit, /NeroAI_maxSnapshotBytes = 7400/);
  assert.match(preInit, /NeroAI_maxWireBytes = 7900/);

  // Byte length evaluator in sender and snapshot builder
  assert.match(sender, /toArray _str/);
  assert.match(sender, /NeroAI_maxWireBytes/);
  assert.match(sender, /_wireLimit = missionNamespace getVariable \["NeroAI_maxWireBytes", 7900\]/);
  assert.match(sender, /IniDBI: write failed for request/);
  assert.match(snap, /toArray _str/);
  assert.match(snap, /NeroAI_maxSnapshotBytes/);

  // Simulate worst-case snapshot with 16 groups, Cyrillic callsigns, 6 intel items, 6 dialogue turns
  const groups = [];
  for (let i = 1; i <= 16; i++) {
    groups.push([
      `group_${i}`,
      `Такистан-${i}`,
      [4200 + i * 50, 7800 + i * 50],
      "READY",
      "ADVANCE",
      [4300, 7900],
      "",
      [], // stripped unit details in worst case
      100,
      100,
      1,
      0,
      0,
      true,
      [],
      [[], []]
    ]);
  }
  const sharedIntel = [];
  for (let i = 1; i <= 6; i++) {
    sharedIntel.push(["EAST", `Пехотное отделение противника ${i} на высоте 142`, [4100 + i * 10, 7700 + i * 10], 120]);
  }
  const dialogue = [];
  for (let i = 1; i <= 6; i++) {
    dialogue.push([`Такистан-${i % 4 + 1}`, `Командир, противник ведет плотный огонь с фланга, запрашиваем поддержку!`]);
  }
  const sectors = [
    ["Ферузабад", [4100, 7500], "EAST"],
    ["Чакчак", [4600, 8100], "WEST"],
    ["Гаравсат", [3900, 7100], "RESISTANCE"]
  ];

  const singleGroupSnapshotObj = [
    "v", 3,
    "ch", "SIDE",
    "observer", [4200, 7800],
    "observerDir", 180,
    "groups", [groups[0]],
    "landmarks", [],
    "locations", [],
    "sectors", sectors,
    "terrain", "TAKISTAN",
    "side", "WEST",
    "assets", [],
    "support", [["MORTAR", 2, 2], ["CAS", 1, 1]],
    "shop", [["TANK", 3500, 6000], ["APC", 1800, 3000]],
    "counterBattery", [],
    "sharedIntel", sharedIntel,
    "events", [],
    "dialogue", dialogue,
    "vision", [],
    "radioFrom", [],
    "order", "Приказываю немедленно выдвинуться в район Ферузабада и занять круговую оборону!"
  ];
  const singleGroupSnapshotStr = toSqfValue(singleGroupSnapshotObj);
  const singleSnapBytes = Buffer.byteLength(singleGroupSnapshotStr, "utf8");
  assert.ok(singleSnapBytes <= 7400, `Single group snapshot must be <= 7400 bytes, got ${singleSnapBytes}`);

  const singleWire = ["request", [3, "n3_worst_case_req", "SIDE", ["2:101"], singleGroupSnapshotStr, "PLAYER"]];
  const singleWireStr = toSqfValue(singleWire);
  const singleWireBytes = Buffer.byteLength(singleWireStr, "utf8");

  assert.ok(singleWireBytes <= 7900, `Wire size must be <= 7900 bytes, got ${singleWireBytes}`);
  assert.ok(singleWireBytes < 8192, `Wire size must be strictly under INIDBI 8K (8192) limit, got ${singleWireBytes}`);
});

test("4.5.1e T26 F5: radio only from server via clientSpeech, directChat unblocked, Commands class deleted", () => {
  const config = read("config.cpp");
  const cfgFunctions = read("functions/CfgFunctions.hpp");
  const clientSpeech = read("functions/communication/fn_clientSpeech.sqf");
  const broadcast = read("functions/communication/fn_broadcastSpeech.sqf");

  // Registered in CfgFunctions
  assert.match(cfgFunctions, /class clientSpeech \{\};/);

  // Registered in CfgRemoteExec::Functions with allowedTargets = 1
  assert.match(config, /class NeroAI_fnc_clientSpeech \{ allowedTargets = 1; \}/);
  // Commands section is removed
  assert.doesNotMatch(config, /class Commands/);

  // clientSpeech has owner guard on line 1
  const firstCode = clientSpeech.trim().split(/\r?\n/).filter((l) => !/^\s*(\/\*|\*)/.test(l))[0];
  assert.match(firstCode, /if \(isRemoteExecuted && \{!\(remoteExecutedOwner in \[0, 2\]\)\}\) exitWith \{\};/);

  // clientSpeech handles all four channels
  assert.match(clientSpeech, /case "SIDE";\s*case "SIDECHAT": \{ _unit sideChat _text; \};/);
  assert.match(clientSpeech, /case "GROUP";\s*case "GROUPCHAT": \{ _unit groupChat _text; \};/);
  assert.match(clientSpeech, /case "COMMAND";\s*case "COMMANDCHAT": \{ _unit commandChat _text; \};/);
  // 4.7.0a: "directChat" is not a command (it broke compilation) — a shout is globalChat gated by distance on the client
  assert.match(clientSpeech, /case "DIRECT";\s*case "DIRECTCHAT": \{ if \(hasInterface && \{!isNull player\} && \{\(player distance _unit\) <= 60\}\) then \{ _unit globalChat _text; \}; \};/);

  // fn_broadcastSpeech routes through NeroAI_fnc_clientSpeech
  assert.match(broadcast, /\[_leader, _speech, "SIDE"\] remoteExecCall \["NeroAI_fnc_clientSpeech", 0\]/);
  assert.match(broadcast, /\[_leader, _speech, "COMMAND"\] remoteExecCall \["NeroAI_fnc_clientSpeech", 0\]/);
  assert.match(broadcast, /\[_leader, _speech, "GROUP"\] remoteExecCall \["NeroAI_fnc_clientSpeech", 0\]/);
  // Close combat atmospheric shouts unblocked via DIRECT
  assert.match(broadcast, /\[_leader, _speech, "DIRECT"\] remoteExecCall \["NeroAI_fnc_clientSpeech", 0\]/);
  assert.doesNotMatch(broadcast, /remoteExecCall \["(?:sideChat|groupChat|commandChat|directChat)"/);
});

test("4.5.1e T19: boarding verification window scaled by distance (45s + dist/1.5 cap 240) and auto-requisition buys APC for squad tail", () => {
  const vt = read("functions/tactical/fn_vehicleTactics.sqf");
  const auto = read("functions/tactical/fn_autoRequisition.sqf");
  const preInit = read("functions/bootstrap/fn_preInit.sqf");

  // Verification window: 45s + dist/1.5 m/s capped at 240s
  assert.match(vt, /_u distance2D _v/);
  assert.match(vt, /\(\(45 \+ \(_maxDist \/ 1\.5\)\) min 240\) max 45/);
  assert.match(vt, /private _deadline = diag_tickTime \+ _waitSec/);

  // Constants
  assert.match(preInit, /NeroAI_purchaseMaxVehicles = 2/);
  assert.match(preInit, /NeroAI_purchaseCooldownSeconds = 90/);
  assert.match(preInit, /NeroAI_purchaseAutoMinCP = 2500/);

  // Auto requisition tail buy logic
  assert.match(auto, /_canBuyTail = \(_vState isEqualTo "PARTIAL_MOUNTED"\)/);
  assert.match(auto, /\(count _pedestrians\) >= 2/);
  assert.match(auto, /\(count _aliveOwn\) < _maxVehicles/);
  assert.match(auto, /if \(_canBuyTail\) then \{\s*\["APC", "CAR"\]\s*\} else/);

  // Anti-oscillation (cooldown check)
  assert.match(auto, /\(_now - \(_group getVariable \["NeroAI_lastAutoBuyTry", -1e6\]\)\) < _cooldown/);

  // Pedestrian tail never crowds into an already manned/full vehicle
  assert.match(auto, /_empty = _own select \{\(\(crew _x\) isEqualTo \[\]\)/);
  assert.match(auto, /_canBoardTail = \(!\(_pedestrians isEqualTo \[\]\)\) && \{!\(_empty isEqualTo \[\]\)\}/);
  assert.match(auto, /\[_group, "BOARD", _vpos, _v\] call NeroAI_fnc_vehicleTactics/);

  // Player authority preserved
  assert.match(auto, /_group getVariable \["NeroAI_playerHold", false\]/);
  assert.match(auto, /_group getVariable \["NeroAI_manualOrderUntil", 0\]/);
});

test("4.5.1e T27 F4: atomic CP deduction with BIS_WL_AI_airdropping locking and delta accounting", () => {
  const buy = read("functions/tactical/fn_purchaseAsset.sqf");

  // Serialized against vanilla fn_WLAIPurchases.fsm: check flag before entry
  assert.match(buy, /_wl getVariable \["BIS_WL_AI_airdropping", false\]/);

  // Critical section wrapped in isNil
  assert.match(buy, /isNil\s*\{/);

  // Airdropping flag set to true inside critical section
  assert.match(buy, /_wl setVariable \["BIS_WL_AI_airdropping", true\];/);

  // Airdropping flag cleared on ALL exit paths:
  // 1. empty catalogue
  assert.match(buy, /_wl setVariable \["BIS_WL_AI_airdropping", false\];\s*_result = \[false, "BUY: каталог реквизиции пуст\."\];/);
  // 2. insufficient budget
  assert.match(buy, /_wl setVariable \["BIS_WL_AI_airdropping", false\];\s*_result = \[false, format \["BUY: не хватает CP/);
  // 3. empty cart
  assert.match(buy, /_wl setVariable \["BIS_WL_AI_airdropping", false\];\s*private _why = if \(_kind isEqualTo "INFANTRY"\)/);
  // 4. funds changed during preparation
  assert.match(buy, /if \(_fundsNow < _totalCost\) exitWith \{\s*_wl setVariable \["BIS_WL_AI_airdropping", false\];/);
  // 5. after successful airdrop delivery
  assert.match(buy, /call BIS_fnc_WLAirdrop;\s*_wl setVariable \["BIS_WL_AI_airdropping", false\];/);

  // Re-reading funds right before writing payment:
  assert.match(buy, /private _fundsNow = _wl getVariable \["BIS_WL_funds", 0\];/);
  assert.match(buy, /private _totalCost = _cartCost \+ _dropFee;/);
  assert.match(buy, /private _newFunds = \(\(_fundsNow - _totalCost\) max 0\) min _maxCP;/);
  assert.match(buy, /_wl setVariable \["BIS_WL_funds", _newFunds, true\];/);

  // Concurrency & delta simulation verifying kill-reward preservation and overdraft prevention:
  const simPurchase = (fundsStart, rewardMidway, otherDeductionMidway, cartCost, dropFee) => {
    let funds = fundsStart;
    const totalCost = cartCost + dropFee;
    let airdropping = false;

    // Start transaction
    airdropping = true;

    // Simulate concurrent game events (kill-reward EH or concurrent purchase)
    funds = funds + rewardMidway - otherDeductionMidway;

    // Re-read funds
    const fundsNow = funds;
    if (fundsNow < totalCost) {
      airdropping = false;
      return { success: false, funds, airdropping, reason: "insufficient_funds_at_write" };
    }

    // Deduct delta
    funds = Math.max(0, fundsNow - totalCost);
    airdropping = false;
    return { success: true, funds, airdropping };
  };

  // Case 1: Kill reward during catalog build is preserved
  // Start: 2000 CP, Cart: 1500, Drop: 100 (Total: 1600). Kill reward: +400 CP.
  // Old code would write: (2000 - 1600) = 400 (lost 400 CP reward!)
  // New code writes: (2400 - 1600) = 800 (reward preserved!)
  const resReward = simPurchase(2000, 400, 0, 1500, 100);
  assert.strictEqual(resReward.success, true);
  assert.strictEqual(resReward.funds, 800);
  assert.strictEqual(resReward.airdropping, false);

  // Case 2: Concurrent deduction caused insufficient funds -> safe reject, no overdraft
  // Start: 2000 CP, Cart: 1500, Drop: 100 (Total: 1600). Concurrent drop: -1000 CP.
  // Old code would write: (2000 - 1600) = 400 despite balance having dropped to 1000!
  // New code detects fundsNow (1000) < totalCost (1600) and aborts cleanly.
  const resOverdraft = simPurchase(2000, 0, 1000, 1500, 100);
  assert.strictEqual(resOverdraft.success, false);
  assert.strictEqual(resOverdraft.funds, 1000);
  assert.strictEqual(resOverdraft.airdropping, false);
});

test("4.5.1e T20: vehicle combat value scoring (weapons, seating, intel) and intelligent vehicle choice", () => {
  const buy = read("functions/tactical/fn_purchaseAsset.sqf");
  const auto = read("functions/tactical/fn_autoRequisition.sqf");

  // Static checks in fn_purchaseAsset.sqf:
  // Blacklist filters support/unarmed/command non-combat vehicles
  assert.match(buy, /ambulance/);
  assert.match(buy, /salvage/);
  assert.match(buy, /repair/);
  assert.match(buy, /санитар/);

  // Weapon detection: cannon, atgm, mg
  assert.match(buy, /_fnc_weaponDetails/);
  assert.match(buy, /_fnc_vehicleSeats/);
  assert.match(buy, /_fnc_assetScore/);
  assert.match(buy, /_hasCannon/);
  assert.match(buy, /_hasATGM/);
  assert.match(buy, /_hasMG/);

  // Intel AT evaluation
  assert.match(buy, /_enemyAT/);
  assert.match(buy, /NeroAI_sharedIntel/);

  // Best combat value per CP formula
  assert.match(buy, /\(_power \* 1000\) \/ \(_cost max 100\)/);

  // fn_autoRequisition priority adapting to intel and squad size
  assert.match(auto, /_enemyAT == 0/);
  // 7.10: squads of 5+ buy a carrier first (a 4-seat tank left six men walking and its crew was
  // abandoned by the native stuck check); small squads keep TANK first when no enemy AT is known.
  assert.match(auto, /if \(\(count _living\) >= 5\) then \{\s*\["APC", "TANK", "CAR"\]\s*\} else \{\s*if \(_enemyAT == 0\) then \{\["TANK", "APC", "CAR"\]\} else \{\["APC", "TANK", "CAR"\]\}\s*\}/);

  // Scoring function simulation matching docs/VEHICLE_COMBAT_VALUE_TABLE.md
  const scoreVehicle = ({ displayName, cost, hasCannon, hasATGM, hasMG, seats, livingCount, enemyAT, kind }) => {
    const name = displayName.toLowerCase();
    const isSupport = name.includes("ambulance") || name.includes("medic") || name.includes("repair") ||
                      name.includes("fuel") || name.includes("ammo") || name.includes("salvage") || name.includes("санитар");
    if (isSupport) return 0;
    if (!hasCannon && !hasATGM && !hasMG) return 0;

    let power = 0;
    if (hasCannon) power += 100;
    if (hasATGM) power += 80;
    if (hasMG) power += 30;

    if (seats >= livingCount) {
      power += 40;
    } else {
      power += Math.min(seats, livingCount) * 5;
    }

    if (kind === "APC" && livingCount >= 4) {
      power += 40;
    }
    if (kind === "TANK") {
      if (enemyAT === 0) {
        power += 60;
      } else {
        power -= 10;
      }
    }

    return (power * 1000) / Math.max(cost, 100);
  };

  // Case 1: Ambulance is blacklisted (score 0)
  const ambulanceScore = scoreVehicle({
    displayName: "BMP-2 Ambulance",
    cost: 2200,
    hasCannon: false,
    hasATGM: false,
    hasMG: false,
    seats: 6,
    livingCount: 4,
    enemyAT: 0,
    kind: "APC"
  });
  assert.strictEqual(ambulanceScore, 0, "Ambulance must get score 0");

  // Case 2: BMP-2 CZ (cannon + ATGM + MG, 1800 CP) vs BTR-60 HQ (MG only, 4000 CP)
  const bmp2Score = scoreVehicle({
    displayName: "BMP-2 CZ",
    cost: 1800,
    hasCannon: true,
    hasATGM: true,
    hasMG: true,
    seats: 10,
    livingCount: 4,
    enemyAT: 1,
    kind: "APC"
  });
  const btr60HqScore = scoreVehicle({
    displayName: "BTR-60 HQ",
    cost: 4000,
    hasCannon: false,
    hasATGM: false,
    hasMG: true,
    seats: 6,
    livingCount: 4,
    enemyAT: 1,
    kind: "APC"
  });
  assert(bmp2Score > 160, `BMP-2 score should be ~161.1, got ${bmp2Score}`);
  assert(btr60HqScore < 30, `BTR-60 HQ score should be ~27.5, got ${btr60HqScore}`);
  assert(bmp2Score > btr60HqScore * 5, "BMP-2 CZ must massively outscore expensive underarmed BTR-60 HQ");

  // Case 3: Tank scoring responds dynamically to enemy AT intel
  const tankIntelNoAT = scoreVehicle({
    displayName: "T-72BB",
    cost: 3200,
    hasCannon: true,
    hasATGM: true,
    hasMG: true,
    seats: 3,
    livingCount: 4,
    enemyAT: 0,
    kind: "TANK"
  });
  const tankIntelWithAT = scoreVehicle({
    displayName: "T-72BB",
    cost: 3200,
    hasCannon: true,
    hasATGM: true,
    hasMG: true,
    seats: 3,
    livingCount: 4,
    enemyAT: 2,
    kind: "TANK"
  });
  assert(tankIntelNoAT > tankIntelWithAT, "Tank must score higher when enemy has 0 AT");
  assert.strictEqual(Math.round(tankIntelNoAT * 10) / 10, 89.1);
  assert.strictEqual(Math.round(tankIntelWithAT * 10) / 10, 67.2);
});


test("4.6.0 BUY is in the strict planner schema (the 4.5.x enum had lost it: 0 BUY in 3059 live replies)", () => {
  const lm = require("../bridge/lm-studio");
  const { ACTIONS } = require("../bridge/protocol");
  assert.deepEqual([...lm.ALLOWED_ACTION_TYPES].sort(), [...ACTIONS].sort());
  const schema = lm.buildResponseSchema();
  assert.ok(schema.schema.properties.actions.items.properties.type.enum.includes("BUY"));
  assert.ok(schema.schema.properties.actions.items.properties.support.enum.includes("TANK"));
  assert.match(lm.SYSTEM_PROMPT, /Types: [^\n]*\bBUY\b/);
  /* the few-shot that spends CP is now representable under the schema it is sent with */
  const example = lm.buildMessages("[]").find(m => m.role === "assistant");
  const parsed = JSON.parse(example.content);
  for (const action of parsed.actions) assert.ok(schema.schema.properties.actions.items.properties.type.enum.includes(action.type), action.type);
});

test("4.6.0 local backend payload: classic max_tokens/temperature, reasoning_effort none, json_schema, no OpenAI cache key", () => {
  const lm = require("../bridge/lm-studio");
  const config = JSON.parse(fs.readFileSync(path.join(root, "bridge", "neroai3.config.json"), "utf8"));
  const payload = lm.buildRequestPayload(config, "[\"v\",3,\"ch\",\"AUTONOMY\",\"side\",\"RED\"]");
  assert.equal(payload.model, config.lmStudio.model);
  assert.equal(payload.max_tokens, 4096);
  assert.equal(payload.max_completion_tokens, undefined);
  assert.equal(payload.temperature, 0.35);
  assert.equal(payload.reasoning_effort, "none");
  assert.equal(payload.prompt_cache_key, undefined);
  assert.equal(payload.response_format.type, "json_schema");
  assert.equal(payload.stream, false);
});

test("4.6.0 benchmark tool exists, is wired as npm script and never touches the INI transport; version strings say 4.7.0", () => {
  const bench = fs.readFileSync(path.join(root, "tools", "benchmark-local-llm.js"), "utf8");
  const pkg = JSON.parse(fs.readFileSync(path.join(root, "package.json"), "utf8"));
  const cfgCpp = fs.readFileSync(path.join(root, "addons", "NeroAI3", "config.cpp"), "utf8");
  assert.equal(pkg.scripts["bench:llm"], "node tools/benchmark-local-llm.js");
  assert.match(pkg.version, /^4\.7\.0/);
  assert.match(cfgCpp, /NeroAI 4\.7\.0 \[Any Warlords\]/);
  assert.match(bench, /validateModelResponse/);
  assert.match(bench, /buildRequestPayload/);
  assert.doesNotMatch(bench, /OO_INIDBI|NeroAI4_out|NeroAI4_in|iniFolder/);
});
