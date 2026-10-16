"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const addonRoot = path.join(__dirname, "..", "addons", "NeroAI3");

function filesIn(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
    const full = path.join(directory, entry.name);
    return entry.isDirectory() ? filesIn(full) : [full];
  });
}

function stripSqfStringsAndComments(text) {
  return text
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .replace(/\/\/.*$/gm, "")
    .replace(/"(?:""|[^"])*"/g, '""');
}

test("addon source has no dynamic SQF execution primitive", () => {
  const sourceFiles = filesIn(addonRoot).filter(file => /\.(?:sqf|hpp|cpp)$/i.test(file));
  assert.ok(sourceFiles.length >= 20, "expected a substantive addon source tree");
  for (const file of sourceFiles) {
    if (file === path.join(addonRoot,"functions","native","fn_WLVarsInit.sqf")) {
      // BI's native initializer compiles trusted mission-config presets/group
      // paths. Require the exact bounded adaptation; never exempt arbitrary SQF.
      const original=fs.readFileSync(path.join(__dirname,"..","research","native","Warlords","fn_WLVarsInit.sqf"),"utf8");
      assert.equal(fs.readFileSync(file,"utf8"),require("../tools/adapt-vars-init").adapt(original));
      continue;
    }
    const code = stripSqfStringsAndComments(fs.readFileSync(file, "utf8"));
    assert.doesNotMatch(code, /\bcompile\b/i, file);
    assert.doesNotMatch(code, /\bexecVM\b/i, file);
    assert.doesNotMatch(code, /\bpreprocessFile/i, file);
  }
});

test("no .sqf file uses backslash-quote escaping, which SQF does not support", () => {
  /* Live incident: fn_spawnBaseAssets.sqf used \"%2\" inside a format string.
   * SQF strings escape an embedded quote by DOUBLING it (""), not with a
   * backslash — a backslash-quote just ends the string early and corrupts
   * everything after it on that line. The engine caught it at runtime
   * ("Error Потеряна ]"), but it broke base-position resolution for the
   * whole mission (both sides' base assets/armour silently skipped), and the
   * balance-checker below missed it too: its string-stripping regex assumes
   * correct "" escaping, so a stray backslash-quote desyncs its string
   * boundaries — the resulting bracket count only happened to still balance
   * by coincidence. This check looks for the literal mistake directly. */
  const sourceFiles = filesIn(addonRoot).filter(file => /\.sqf$/i.test(file));
  for (const file of sourceFiles) {
    const code = fs.readFileSync(file, "utf8");
    assert.doesNotMatch(code, /\\"/, `${file}: backslash-quote is not valid SQF string escaping — use "" instead`);
  }
});

test("SQF and configuration delimiters are balanced after comments and strings are stripped", () => {
  const sourceFiles = filesIn(addonRoot).filter(file => /\.(?:sqf|hpp|cpp)$/i.test(file));
  const matching = { ")": "(", "]": "[", "}": "{" };
  for (const file of sourceFiles) {
    const stack = [];
    const code = stripSqfStringsAndComments(fs.readFileSync(file, "utf8"));
    for (const character of code) {
      if ("([{ ".includes(character) && character !== " ") stack.push(character);
      if (Object.hasOwn(matching, character)) {
        assert.equal(stack.pop(), matching[character], `${file}: unexpected ${character}`);
      }
    }
    assert.equal(stack.length, 0, `${file}: unclosed delimiter(s) ${stack.join("")}`);
  }
});

test("network surface is a small CfgRemoteExec allowlist without command spoofing", () => {
  const config = fs.readFileSync(path.join(addonRoot, "config.cpp"), "utf8");
  assert.match(config, /class CfgRemoteExec/);
  assert.match(config, /mode = 1/);
  assert.match(config, /class NeroAI_fnc_receiveClientCommand \{ allowedTargets = 2; \}/);
  assert.match(config, /class NeroAI_fnc_clientNotice \{ allowedTargets = 1; \}/);
  assert.match(config, /class NeroAI_fnc_clientSpeech \{ allowedTargets = 1; \}/);
  /* T26 F5: Commands section deleted entirely to prevent client radio spoofing */
  assert.doesNotMatch(config, /class Commands/);
  assert.doesNotMatch(config, /class sideChat|class groupChat|class commandChat|class directChat/);

  /* No SQF file may remoteExec chat commands directly */
  const sourceFiles = filesIn(addonRoot).filter(file => /\.sqf$/i.test(file));
  for (const file of sourceFiles) {
    const code = fs.readFileSync(file, "utf8");
    assert.doesNotMatch(code, /remoteExec(?:Call)?\s*\[\s*"(?:sideChat|groupChat|commandChat|directChat)"/i, `${file}: chat commands must not be called via remoteExec directly`);
  }

  /* clientSpeech has server owner guard */
  const clientSpeech = fs.readFileSync(path.join(addonRoot, "functions", "communication", "fn_clientSpeech.sqf"), "utf8");
  const speechCode = clientSpeech.trim().split(/\r?\n/).filter((l) => !/^\s*(\/\*|\*)/.test(l));
  assert.match(speechCode[0], /^if \(isRemoteExecuted && \{!\(remoteExecutedOwner in \[0, 2\]\)\}\) exitWith \{\};/, "owner guard must be the first statement");
});

test("reconnaissance and fire support are throttled per group", () => {
  const preInit = fs.readFileSync(path.join(addonRoot, "functions", "bootstrap", "fn_preInit.sqf"), "utf8");
  const recon = fs.readFileSync(path.join(addonRoot, "functions", "tactical", "fn_uavRecon.sqf"), "utf8");
  const fireSupport = fs.readFileSync(path.join(addonRoot, "functions", "tactical", "fn_requestFireSupport.sqf"), "utf8");

  assert.match(preInit, /NeroAI_reconCooldownSeconds\s*=\s*15/);
  assert.match(preInit, /NeroAI_fireSupportCooldownSeconds\s*=\s*150/);
  assert.match(recon, /getVariable \["NeroAI_lastRecon", -_cooldown\]/);
  assert.match(recon, /\(_now - _lastRecon\) < _cooldown/);
  assert.match(fireSupport, /getVariable \["NeroAI_lastFireSupport", -_cooldown\]/);
  assert.match(fireSupport, /\(_now - _lastFireSupport\) < _cooldown/);
});

test("bridge and Arma request timeouts leave a response-delivery margin", () => {
  const config = JSON.parse(fs.readFileSync(path.join(__dirname, "..", "bridge", "neroai3.config.json"), "utf8"));
  const dispatch = fs.readFileSync(path.join(addonRoot, "functions", "core", "fn_dispatchResponse.sqf"), "utf8");
  const poller = fs.readFileSync(path.join(addonRoot, "functions", "core", "fn_pollBridgeResponses.sqf"), "utf8");
  const sender = fs.readFileSync(path.join(addonRoot, "functions", "core", "fn_sendBridgeRequest.sqf"), "utf8");

  /* 4.2.0 runs on a cloud model: a bounded non-"none" reasoning effort is allowed,
   * but the Arma-side wait must still comfortably outlast the request timeout. */
  assert.ok(["", "none", "minimal", "low", "medium", "high", "undefined"].includes(String(config.lmStudio.reasoningEffort)));
  assert.ok(config.lmStudio.timeoutMs < 90_000);
  assert.ok(config.transport.maxPending >= 1 && config.transport.maxPending <= 4);
  assert.match(dispatch, /> 95/);
  assert.match(poller, /> 100/);
  assert.match(sender, /_origin isEqualTo "AUTONOMY".*count NeroAI_pending\) >= _autonomyBudget/s);
  assert.match(sender, /_origin isEqualTo "PLAYER".*count NeroAI_pending\)/s);
  assert.match(sender, /NeroAI_playerRequestsPending/);
  assert.match(sender, /_guardTokens/);
});

test("V2 keeps vanilla groups and capability-driven autonomy server-side", () => {
  const tactical = path.join(addonRoot, "functions", "tactical");
  const cfgFunctions = fs.readFileSync(path.join(addonRoot, "functions", "CfgFunctions.hpp"), "utf8");
  const register = fs.readFileSync(path.join(addonRoot, "functions", "core", "fn_registerGroup.sqf"), "utf8");
  const vehicle = fs.readFileSync(path.join(tactical, "fn_vehicleTactics.sqf"), "utf8");
  const autonomy = fs.readFileSync(path.join(tactical, "fn_tacticalAutonomy.sqf"), "utf8");
  const recon = fs.readFileSync(path.join(tactical, "fn_uavRecon.sqf"), "utf8");
  const sharedIntel = fs.readFileSync(path.join(tactical, "fn_shareIntel.sqf"), "utf8");
  const negotiate = fs.readFileSync(path.join(tactical, "fn_negotiate.sqf"), "utf8");
  const designate = fs.readFileSync(path.join(tactical, "fn_laserDesignate.sqf"), "utf8");
  const snapshot = fs.readFileSync(path.join(addonRoot, "functions", "core", "fn_buildSnapshot.sqf"), "utf8");

  assert.match(cfgFunctions, /class analyzeGroupCapabilities/);
  /* The removed group-rebuild doctrine system stays gone, and since 4.5.0 so
   * does the per-side posture reflex: vanilla AI owns posture between plans. */
  assert.doesNotMatch(cfgFunctions, /class doctrine\b|class applyDoctrine\w*|class auditDoctrine\b|class rebuildGroupForDoctrine\b/);
  assert.match(cfgFunctions, /class purchaseAsset/);
  assert.match(cfgFunctions, /class ambushWatch/);
  assert.match(cfgFunctions, /class intergroupRelay/);
  assert.match(register, /NeroAI_controlMode", "VANILLA_AUTONOMOUS"/);
  assert.match(register, /NeroAI_initialStrength/);
  assert.doesNotMatch(register, /NeroAI_doctrine|rebuildGroupForDoctrine/);
  assert.match(vehicle, /private _isUsableVehicle/);
  assert.match(vehicle, /NO_FREE_VEHICLE_NEARBY/);
  assert.doesNotMatch(vehicle, /NeroAI_role|NeroAI_doctrine|private _isLightArmour|private _isPersonnelArmour/);
  assert.match(vehicle, /boarding verified: %2\/%3 members actually mounted/);
  assert.match(vehicle, /allowGetIn true/);
  assert.match(vehicle, /vehicle \(_x # 0\) isEqualTo \(_x # 1\)/);
  assert.match(vehicle, /NeroAI_fnc_getVehicleSide/);
  assert.match(autonomy, /NeroAI_fnc_shareIntel/);
  assert.match(autonomy, /NeroAI_fnc_requestSupport/);
  assert.match(autonomy, /NeroAI_fnc_analyzeGroupCapabilities/);
  assert.match(autonomy, /"AUTONOMY"\] call NeroAI_fnc_sendBridgeRequest/);
  assert.match(autonomy, /_target isKindOf "Man"/);
  assert.match(autonomy, /_target isKindOf "LandVehicle"/);
  assert.match(vehicle, /Посадка уже выполняется/);
  assert.match(recon, /param \[4, objNull\]/);
  assert.match(sharedIntel, /param \[4, objNull\]/);
  assert.match(autonomy, /param \[4, objNull\]/);
  assert.match(negotiate, /NeroAI_negotiationState/);
  assert.doesNotMatch(negotiate, /NeroAI_fnc_requestSupport/);
  assert.match(designate, /forceWeaponFire/);
  assert.match(designate, /checkVisibility/);
  assert.match(designate, /laserTarget/);
  assert.match(designate, /SEARCHING/);
  assert.match(snapshot, /"assets"/);
  assert.match(snapshot, /"sharedIntel"/);
  assert.match(snapshot, /"observerDir"/);
  assert.match(snapshot, /NeroAI_lastLlmDecision/);
  assert.match(snapshot, /NeroAI_lastActionResult/);
  assert.match(snapshot, /getFatigue _x/);
  assert.doesNotMatch(snapshot, /select \[0,\s*\d+\]/);
});

test("faction chat routes only an exact NeroAI callsign or the explicit all-groups token", () => {
  const routing = fs.readFileSync(path.join(addonRoot, "functions", "communication", "fn_resolveTargets.sqf"), "utf8");
  const chat = fs.readFileSync(path.join(addonRoot, "functions", "communication", "fn_handleChat.sqf"), "utf8");
  const receiver = fs.readFileSync(path.join(addonRoot, "functions", "communication", "fn_receiveClientCommand.sqf"), "utf8");
  assert.match(routing, /private _containsCompleteCallsign/);
  assert.match(routing, /"все"/);
  assert.match(routing, /"всем"/);
  assert.match(routing, /private _index = _message find _callsign/);
  assert.match(routing, /_nextCode in \[45, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57\]/);
  assert.doesNotMatch(routing, /groupId _x/);
  assert.doesNotMatch(routing, /name leader _x/);
  assert.match(chat, /if !\(_channel isEqualTo 1\) exitWith/);
  assert.doesNotMatch(chat, /"COMMAND"/);
  assert.match(receiver, /if !\(_mode isEqualTo "SIDE"\) exitWith/);
});

test("command submenu preserves the deferred engine-safe group reference", () => {
  const menu = fs.readFileSync(path.join(addonRoot, "functions", "communication", "fn_openControlMenu.sqf"), "utf8");
  assert.match(menu, /NeroAI4_AvailableGroups select %1/);
  assert.match(menu, /spawn \{ uiSleep 0\.05;/);
  assert.doesNotMatch(menu, /groupFromNetId/);
});

test("respawn rebuilds player actions instead of trusting the copied guard", () => {
  const initClient = fs.readFileSync(path.join(addonRoot, "functions", "communication", "fn_initClient.sqf"), "utf8");
  assert.match(initClient, /params \["_newEntity", "_oldEntity"\]/);
  assert.match(initClient, /_newEntity setVariable \["NeroAI_actionsInstalled", false\]/);
  assert.match(initClient, /\[_newEntity\] call NeroAI_fnc_installPlayerActions/);
});

test("vanilla autonomy and mobility watchdog preserve the Warlords safety contract", () => {
  const tactical = path.join(addonRoot, "functions", "tactical");
  const vehicle = fs.readFileSync(path.join(tactical, "fn_vehicleTactics.sqf"), "utf8");
  const mobility = fs.readFileSync(path.join(tactical, "fn_mobilityWatchdog.sqf"), "utf8");
  const tacticalAutonomy = fs.readFileSync(path.join(tactical, "fn_tacticalAutonomy.sqf"), "utf8");
  const warlordsAutonomy = fs.readFileSync(path.join(tactical, "fn_warlordsAutonomy.sqf"), "utf8");
  const serverLoop = fs.readFileSync(path.join(addonRoot, "functions", "bootstrap", "fn_serverLoop.sqf"), "utf8");
  assert.match(vehicle, /_vehicle isKindOf "LandVehicle"/);
  assert.match(vehicle, /_vehicle isKindOf "Air"/);
  assert.match(vehicle, /_vehicle isKindOf "Ship"/);
  assert.doesNotMatch(vehicle, /case "INFANTRY"|case "RECON"|case "MECHANIZED"|case "ARMORED"/);
  assert.match(mobility, /mobility watchdog reissued/);
  assert.doesNotMatch(mobility, /limitSpeed\s+\d/);
  assert.match(mobility, /NeroAI_mobilityWindow/);
  assert.match(mobility, /MOBILITY_RETRY/);
  assert.match(serverLoop, /NeroAI_fnc_mobilityWatchdog/);
  assert.match(tacticalAutonomy, /NeroAI_fnc_warlordsAutonomy/);
  /* 4.4.0: Warlords presence = real sector objects (NeroAI_fnc_warlordsSectors). */
  assert.match(warlordsAutonomy, /call NeroAI_fnc_warlordsSectors\) isEqualTo \[\]/);
  assert.doesNotMatch(warlordsAutonomy, /BIS_WL_owner/);
  assert.match(warlordsAutonomy, /currentWaypoint _group/);
  assert.match(warlordsAutonomy, /NeroAI_warlordsIdleSeconds/);
  assert.match(warlordsAutonomy, /WARLORDS_AUTONOMY/);
  assert.doesNotMatch(warlordsAutonomy, /deleteWaypoint|clearWaypoints|BIS_WL_funds\s*(?:=|set)/);
});

test("autonomous marches re-check live distance and respect fatigue", () => {
  const preInit = fs.readFileSync(path.join(addonRoot, "functions", "bootstrap", "fn_preInit.sqf"), "utf8");
  const macro = fs.readFileSync(path.join(addonRoot, "functions", "core", "fn_executeMacro.sqf"), "utf8");
  assert.match(preInit, /NeroAI_autonomyMinAdvanceMeters\s*=\s*35/);
  assert.match(macro, /NeroAI_autonomyMinAdvanceMeters/);
  assert.match(macro, /_autonomousSource/);
  assert.match(macro, /NeroAI_lastAutonomyMove/);
  assert.match(macro, /getFatigue _x/);
  assert.match(macro, /setSpeedMode _marchSpeed/);
  assert.doesNotMatch(macro, /_group setSpeedMode "FULL"/);
});


test("group housekeeping never rewrites skills, posture or formation", () => {
  const hk = fs.readFileSync(path.join(addonRoot, "functions", "core", "fn_groupHousekeeping.sqf"), "utf8");
  assert.match(hk, /NeroAI_forcePlan/);
  assert.doesNotMatch(hk, /setSkill|setUnitTrait|setFormation|setCombatBehaviour|NeroAI_doctrine|NeroAI_psyche/);
});


test("bridge response polling is isolated from housekeeping and autonomy failures", () => {
  const serverLoop = fs.readFileSync(path.join(addonRoot, "functions", "bootstrap", "fn_serverLoop.sqf"), "utf8");
  assert.match(serverLoop, /\[\] spawn \{[\s\S]*?NeroAI_fnc_pollBridgeResponses/);
  assert.match(serverLoop, /\[\] spawn \{[\s\S]*?NeroAI_fnc_groupHousekeeping/);
  assert.match(serverLoop, /while \{true\} do \{[\s\S]*?NeroAI_fnc_tacticalAutonomy/);
});

test("empty vehicle allegiance comes from mission ownership or CfgVehicles", () => {
  const resolver = fs.readFileSync(path.join(addonRoot, "functions", "core", "fn_getVehicleSide.sqf"), "utf8");
  const repair = fs.readFileSync(path.join(addonRoot, "functions", "tactical", "fn_repairVehicle.sqf"), "utf8");
  assert.match(resolver, /NeroAI_ownerSide/);
  assert.match(resolver, /CfgVehicles/);
  assert.match(repair, /NeroAI_fnc_getVehicleSide/);
});

test("player requests supersede stale autonomous plans", () => {
  const dispatch = fs.readFileSync(path.join(addonRoot, "functions", "core", "fn_dispatchResponse.sqf"), "utf8");
  const poller = fs.readFileSync(path.join(addonRoot, "functions", "core", "fn_pollBridgeResponses.sqf"), "utf8");
  assert.match(dispatch, /NeroAI_playerRequestsPending/);
  assert.match(dispatch, /NeroAI_opToken/);
  assert.match(dispatch, /autonomous plan superseded by player intent/);
  assert.match(dispatch, /NeroAI_playerHold/);
  assert.match(poller, /NeroAI_playerRequestsPending/);
});

test("4.7.0 [Any Warlords]: nothing map- or faction-specific is hardwired — profile, faction pools, callsigns, sector names", () => {
  const read = (p) => fs.readFileSync(path.join(addonRoot, "functions", ...p.split("/")), "utf8");
  const balanced = (src, name) => {
    const code = src.replace(/\/\*[\s\S]*?\*\//g, "").replace(/\/\/.*$/gm, "").replace(/"(?:[^"]|"")*"/g, '""');
    for (const [o, c] of [["{", "}"], ["[", "]"], ["(", ")"]]) {
      const open = (code.match(new RegExp("\\" + o, "g")) || []).length;
      const close = (code.match(new RegExp("\\" + c, "g")) || []).length;
      assert.equal(open, close, `${name}: unbalanced ${o}${c} (${open}/${close})`);
    }
  };
  const cfg = fs.readFileSync(path.join(addonRoot, "functions", "CfgFunctions.hpp"), "utf8");
  for (const fn of ["scenarioProfile", "factionAssets", "callsignPrefix"]) assert.match(cfg, new RegExp(`class ${fn} \{\};`));

  const profile = read("core/fn_scenarioProfile.sqf");
  balanced(profile, "fn_scenarioProfile");
  assert.match(profile, /BIS_WL_factionsPool/);
  assert.match(profile, /BIS_WL_base_WEST/); assert.match(profile, /BIS_WL_base_EAST/);
  assert.match(profile, /nearestTerrainObjects \[_p, \["TREE"\], 50, false\]/);
  assert.match(profile, /surfaceIsWater _p/);
  assert.match(profile, /NeroAI_terrainLine/);
  assert.doesNotMatch(profile, /toLower worldName\) in \[/, "no map list");
  for (const tag of ["ISLANDS", "COAST", "MOUNTAINS", "HILLS", "FLAT", "DENSE_FOREST", "FOREST", "OPEN", "URBAN", "VILLAGES", "ARID"]) {
    assert.match(profile, new RegExp(`"${tag}"`), `terrain tag ${tag}`);
  }

  const assets = read("core/fn_factionAssets.sqf");
  balanced(assets, "fn_factionAssets");
  assert.match(assets, /BIS_WL_grpPool_motorized/); assert.match(assets, /BIS_WL_grpPool_armored/);
  assert.match(assets, /getText \(_x >> 'faction'\) == '%1'/, "CfgVehicles scan keyed by the faction tag");
  assert.match(assets, /isKindOf "StaticMortar"/); assert.match(assets, /"isUav"/);
  assert.doesNotMatch(assets, /\bcompile\b|execVM|createVehicle|deleteVehicle/);

  const callsign = read("core/fn_callsignPrefix.sqf");
  balanced(callsign, "fn_callsignPrefix");
  assert.match(callsign, /\["takistan",\s+"Такистан-"\]/);
  assert.match(callsign, /case "GREEN": \{"Партизан-"\}/);
  assert.match(read("core/fn_registerGroup.sqf"), /\[_grpSide\] call NeroAI_fnc_callsignPrefix/);
  assert.doesNotMatch(read("core/fn_registerGroup.sqf"), /"Такистан-"|"Моджахеды-"/);
  assert.doesNotMatch(read("communication/fn_openControlMenu.sqf"), /Талибан \/ Армия Такистана/);

  const garrison = read("tactical/fn_spawnGreenGarrison.sqf");
  balanced(garrison, "fn_spawnGreenGarrison");
  assert.match(garrison, /\["GREEN", _x\] call NeroAI_fnc_factionAssets/);
  assert.match(garrison, /\["MORTAR"\] call _fnc_pickRole/); assert.match(garrison, /\["UAV_RECON"\] call _fnc_pickRole/);

  const base = read("tactical/fn_spawnBaseAssets.sqf");
  balanced(base, "fn_spawnBaseAssets");
  assert.match(base, /"BIS_WL_base_WEST"\} else \{"BIS_WL_base_EAST"\}/, "base hub before marker guesses");
  assert.match(base, /\[_sideKey, "UAV_ARMED"\] call NeroAI_fnc_factionAssets\) select \{_x isKindOf "Air"\}/);

  const snap = read("core/fn_buildSnapshot.sqf");
  assert.match(snap, /"NeroAI_terrainLine"/); assert.match(snap, /"factions", _factions,/);
  const sectors = read("core/fn_warlordsSectors.sqf");
  balanced(sectors, "fn_warlordsSectors");
  assert.match(sectors, /mapGridPosition _p/); assert.doesNotMatch(sectors, /_name = str _x;/);
  const init = read("bootstrap/fn_initServer.sqf");
  assert.ok(init.indexOf("call NeroAI_fnc_scenarioProfile") < init.indexOf("call NeroAI_fnc_spawnBaseAssets"), "profile before the spawners");
  assert.match(read("bootstrap/fn_preInit.sqf"), /NeroAI_terrainProfile = "AUTO"/);
});

test("4.7.0a live 19.09 (Altis/RHS): no directChat (not a command — clientSpeech failed to compile, radio dead since T26); no pipe reaches INIDBI2", () => {
  const read = (p) => fs.readFileSync(path.join(addonRoot, "functions", ...p.split("/")), "utf8");
  const speech = read("communication/fn_clientSpeech.sqf");
  assert.doesNotMatch(speech, /\bdirectChat\b/, "directChat is not an Arma 3 scripting command");
  assert.match(speech, /\(player distance _unit\) <= 60\}\) then \{ _unit globalChat _text; \}/);
  // the four channels still exist and every case is a real command
  for (const cmd of ["sideChat", "groupChat", "commandChat", "globalChat"]) assert.match(speech, new RegExp(`_unit ${cmd} _text`));
  const snap = read("core/fn_buildSnapshot.sqf");
  assert.match(snap, /if \(\(_encoded find "\|"\) >= 0\) then \{ _encoded = \(_encoded splitString "\|"\) joinString "\/"; \};\s*_encoded\s*$/, "pipe scrub must be the last step before the snapshot is returned");
  const profile = read("core/fn_scenarioProfile.sqf");
  assert.match(profile, /format \["%1: %2", _worldDisplay/, "terrain line uses ':' not '|'");
  assert.match(profile, /entities "ModuleWLBase_F"/, "base hubs read from the module entities, not only BIS_WL_base_*");
  assert.match(profile, /nearestTerrainObjects \[_p, \["TREE"\], 50, false\]/, "trees only, no bushes");
  assert.match(profile, /entities "ModuleWLSector_F"\) \+ \(entities "ModuleWLBase_F"\)\) apply \{ getPosATL _x \}/, "survey inside the sector envelope");
  assert.match(read("core/fn_warlordsSectors.sqf"), /isEqualTo "STR_"\) then \{ _name = localize _name; \}/);
  const prompt = require("../bridge/lm-studio").SYSTEM_PROMPT;
  assert.doesNotMatch(prompt, /<map> \| tags/);
  const few = fs.readFileSync(path.join(addonRoot, "..", "..", "bridge", "lm-studio.js"), "utf8");
  assert.doesNotMatch(few, /Takistan \| mountains/);
});
