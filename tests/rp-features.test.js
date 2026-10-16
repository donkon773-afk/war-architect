"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { classifyPlayerMessage, autonomousMoveIsMeaningful } = require("../bridge/protocol");
const { validateRequest } = require("../bridge/server");

const addonRoot = path.join(__dirname, "..", "addons", "NeroAI3");
const read = rel => fs.readFileSync(path.join(addonRoot, rel), "utf8");

function cfg() {
  return {
    lmStudio: { baseUrl: "x", model: "m", apiKey: "k", timeoutMs: 1000, maxTokens: 64 },
    transport: { iniFolder: "x", outboxDb: "NeroAI4_out", inboxDb: "NeroAI4_in", pollMs: 100, maxPending: 3 },
    limits: { maxSnapshotChars: 12000, maxSpeechChars: 700, maxActions: 5 }
  };
}

test("player message classifier separates questions, information, chatter and orders", () => {
  assert.equal(classifyPlayerMessage('["v",3,"order","Альфа 1-4 куда вы выдвигаетесь?"]').kind, "QUESTION");
  assert.equal(classifyPlayerMessage('["v",3,"order","Гроза-1 доложите обстановку"]').kind, "QUESTION");
  assert.equal(classifyPlayerMessage('["v",3,"order","Альфа 1-4 взлетает наш беспилотник"]').kind, "INFORMATION");
  assert.equal(classifyPlayerMessage('["v",3,"order","молодцы бойцы, так держать"]').kind, "CHATTER");
  assert.equal(classifyPlayerMessage('["v",3,"order","спасибо, конец связи"]').kind, "CHATTER");
  assert.equal(classifyPlayerMessage('["v",3,"order","Альфа 1-4 выдвигайтесь к городу"]').kind, "ORDER");
  /* An imperative wins even if a chatter/question word is also present. */
  assert.equal(classifyPlayerMessage('["v",3,"order","бойцы, атакуйте высоту"]').kind, "ORDER");
});

test("the wire validator accepts the INTERGROUP channel as an autonomous origin", () => {
  const request = validateRequest(
    "n3_ig_wire",
    ["request", [3, "n3_ig_wire", "INTERGROUP", ["group-2"], '["v",3]', "AUTONOMY"]],
    cfg()
  );
  assert.ok(request, "INTERGROUP must be an accepted channel");
  assert.equal(request.channel, "INTERGROUP");
  assert.equal(request.origin, "AUTONOMY");
});

test("INTERGROUP moves obey the same self-move guard as autonomy", () => {
  const snap = '["v",3,"groups",[["Гроза-2","VANILLA",[4700,9400],8,8,0,0,[],90]]]';
  assert.equal(autonomousMoveIsMeaningful("ADVANCE", [4705, 9400], snap), false);
  assert.equal(autonomousMoveIsMeaningful("ADVANCE", [4790, 9295], snap), true);
});


test("4.5.0 there is no scripted posture doctrine and no stress model: vanilla AI is authoritative between plans", () => {
  const fs = require("fs");
  const path = require("path");
  for (const gone of [["tactical", "fn_applyDoctrineStance.sqf"], ["core", "fn_updatePsyche.sqf"], ["tactical", "fn_spawnBaseArmor.sqf"]]) {
    assert.ok(!fs.existsSync(path.join(addonRoot, "functions", ...gone)), gone.join("/") + " must be gone");
  }
  const cfg = read("functions/CfgFunctions.hpp");
  assert.doesNotMatch(cfg, /applyDoctrineStance|updatePsyche|spawnBaseArmor/);
  assert.match(cfg, /class groupHousekeeping \{\};/);
  /* nothing in the addon manipulates a unit's psychology, skill or posture on a timer */
  const all = fs.readdirSync(path.join(addonRoot, "functions"), { recursive: true })
    .filter(f => String(f).endsWith(".sqf"))
    .map(f => fs.readFileSync(path.join(addonRoot, "functions", String(f)), "utf8")).join("\n");
  assert.doesNotMatch(all, /NeroAI_psyche|setSkill|setUnitTrait|allowFleeing|setUnitPos/);
  /* the autonomy tick no longer calls a posture reflex */
  assert.doesNotMatch(read("functions/tactical/fn_tacticalAutonomy.sqf"), /applyDoctrineStance/);
  /* the housekeeping tick keeps the useful parts of the old psyche loop */
  const hk = read("functions/core/fn_groupHousekeeping.sqf");
  assert.match(hk, /NeroAI_lastLeaderVehicle/);
  assert.match(hk, /NeroAI_forcePlan/);
  assert.match(hk, /NeroAI_fnc_installUnitWatchers/);
  assert.match(hk, /NeroAI_activeGroups deleteAt _x/);
  /* the casualty watcher stays: radio report + replan, nothing else */
  const w = read("functions/core/fn_installUnitWatchers.sqf");
  assert.match(w, /addEventHandler \["Killed"/);
  assert.doesNotMatch(w, /"Suppressed"|"FiredNear"/);
  assert.match(w, /есть потери/);
});

test("ambush watch latches once, reports on the radio and forces a replan without moving units", () => {
  const ambush = read("functions/tactical/fn_ambushWatch.sqf");
  const serverLoop = read("functions/bootstrap/fn_serverLoop.sqf");
  assert.match(serverLoop, /NeroAI_fnc_ambushWatch/);
  assert.match(ambush, /NeroAI_ambushState/);
  assert.match(ambush, /NeroAI_ambushPending/);
  assert.match(ambush, /NeroAI_forcePlan/);
  assert.match(ambush, /Засада/);
  assert.match(ambush, /remoteExecCall \["NeroAI_fnc_clientSpeech", 0\]/);
  assert.doesNotMatch(ambush, /doMove|deleteWaypoint|setDamage|createVehicle|createUnit/);
});

test("inter-group relay is one hop, cooldowned and never chains from an INTERGROUP reply", () => {
  const relay = read("functions/tactical/fn_intergroupRelay.sqf");
  const macro = read("functions/core/fn_executeMacro.sqf");
  const dispatch = read("functions/core/fn_dispatchResponse.sqf");
  assert.match(relay, /"INTERGROUP", _command, "AUTONOMY"\] call NeroAI_fnc_sendBridgeRequest/);
  assert.match(relay, /NeroAI_intergroupPairCooldown/);
  assert.match(relay, /NeroAI_intergroupMaxConcurrent/);
  assert.match(macro, /_source != "INTERGROUP".*NeroAI_fnc_intergroupRelay/s);
  assert.match(dispatch, /_execSource = if \(_channel isEqualTo "INTERGROUP"\) then \{"INTERGROUP"\}/);
});

test("re-enrolled groups get unique monotonic callsigns, not count+1", () => {
  const preInit = fs.readFileSync(path.join(addonRoot, "functions", "bootstrap", "fn_preInit.sqf"), "utf8");
  const register = read("functions/core/fn_registerGroup.sqf");
  assert.match(preInit, /NeroAI_callsignSeq\s*=\s*0/);
  assert.match(register, /NeroAI_callsignSeq = NeroAI_callsignSeq \+ 1/);
  assert.match(register, /_callsign in _taken/);
  /* the callsign must no longer be derived from the current active-group count */
  assert.doesNotMatch(register, /(?:Альфа|Такистан|Моджахеды)-%1", count NeroAI_activeGroups \+ 1/);
});

test("faction routing tolerates a duplicate callsign by taking the freshest enrolment", () => {
  const routing = read("functions/communication/fn_resolveTargets.sqf");
  assert.match(routing, /NeroAI_active", false/);
  assert.match(routing, /count _matches\) > 1/);
  assert.match(routing, /NeroAI_enrolledAt", 0/);
  assert.doesNotMatch(routing, /groupId _x/);
});

test("autonomy backs a group off when it keeps producing plans with no manoeuvre", () => {
  const dispatch = read("functions/core/fn_dispatchResponse.sqf");
  const autonomy = read("functions/tactical/fn_tacticalAutonomy.sqf");
  assert.match(dispatch, /NeroAI_idlePlanStreak/);
  assert.match(dispatch, /"ADVANCE", "ASSAULT", "RETREAT", "BOARD", "DISEMBARK"/);
  assert.match(autonomy, /NeroAI_idlePlanStreak/);
  assert.match(autonomy, /NeroAI_idlePlanBackoffAfter/);
  assert.match(autonomy, /_dueInterval/);
});

test("ambush also fires on first blood shortly after first contact", () => {
  const ambush = read("functions/tactical/fn_ambushWatch.sqf");
  assert.match(ambush, /NeroAI_engagementStart/);
  assert.match(ambush, /_freshEngagement/);
  assert.match(ambush, /_freshEngagement\} && \{_casualties >= 1\}/);
});

test("the planner prompt forbids repeating an unchanged comms/recon plan", () => {
  const { SYSTEM_PROMPT } = require("../bridge/lm-studio");
  assert.match(SYSTEM_PROMPT, /Do NOT repeat yourself/);
  assert.match(SYSTEM_PROMPT, /MANOEUVRE/);
});


test("the adversary is enrolled from match start: army without a distance gate, partisans inside the 2.5 km ring", () => {
  const preInit = fs.readFileSync(path.join(addonRoot, "functions", "bootstrap", "fn_preInit.sqf"), "utf8");
  const initServer = read("functions/bootstrap/fn_initServer.sqf");
  const manage = read("functions/tactical/fn_manageEnemyAI.sqf");
  /* constants that guarantee RED/GREEN presence and a start seed */
  assert.match(preInit, /NeroAI_enemySeeded\s*=\s*false/);
  assert.match(preInit, /NeroAI_maxEnemyGroups\s*=\s*6/);
  /* a regular army has its own cap (equal to the friendly cap) and NO distance
   * gate; only partisans keep the ring, now 2.5 km */
  assert.match(preInit, /NeroAI_maxEnemyArmyGroups\s*=\s*16/);
  assert.match(preInit, /NeroAI_enemyMaxDistanceMeters\s*=\s*2500/);
  /* the bridge-ready hook kicks a manage pass instead of waiting a full 8 s tick */
  assert.match(initServer, /NeroAI_transportReady = true;[\s\S]*?NeroAI_fnc_manageEnemyAI/);
  /* first pass reaches wide, guarantees a per-side minimum, then latches the seed */
  assert.match(manage, /_seeding = !\(missionNamespace getVariable \["NeroAI_enemySeeded", false\]\)/);
  assert.match(manage, /_fnc_isArmy = \{ params \["_s"\]; \(_s isEqualTo east\) \|\| \{_s isEqualTo west\} \}/);
  assert.match(manage, /if \(\[side _grp\] call _fnc_isArmy\) then \{\s*_armyCandidates pushBack \[_d, _grp\];/);
  assert.match(manage, /if \(_d <= _activationDist\) then \{ _partisanCandidates pushBack/);
  assert.match(manage, /if \(!_isArmy\) then \{\s*_tooFar =/);
  assert.match(manage, /NeroAI_enemySeeded = true/);
  /* base asset crews are never candidates */
  assert.match(manage, /NeroAI_isBaseAssetCrew", false\]/);
  /* still no unit spawning or waypoint surgery in the enemy manager */
  assert.doesNotMatch(manage, /createVehicle|createUnit|createGroup|deleteWaypoint|setDamage/);
});

test("machine vision stays a commander's-eye note: player-only, fresh, coordinate-free", () => {
  const snapshot = read("functions/core/fn_buildSnapshot.sqf");
  const poller = read("functions/core/fn_pollBridgeResponses.sqf");
  const capture = read("functions/communication/fn_visionCaptureLoop.sqf");
  assert.match(snapshot, /"vision", _vision/);
  assert.match(snapshot, /COMMANDER_CAM/);
  assert.match(snapshot, /if \(!isNull _player\) then \{[\s\S]*?NeroAI_visionLatest/);
  assert.match(poller, /isEqualTo "vision"\}\) then \{[\s\S]*?NeroAI_visionLatest/);
  assert.match(capture, /NeroAI_visionCaptureEnabled/);
});
