"use strict";
// 8.10: behaviour templates as tools — the LLM picks ASSAULT/HOLD/RECON + a
// template, NeroAI marches on roads, LAMBS Danger.fsm (separate mod) fights.
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const root = path.join(__dirname, "..");
const read = file => fs.readFileSync(path.join(root, file), "utf8");
const fn = name => read(`addons/NeroAI3/functions/${name}`);

test("bridge offers the template menu and degrades unknown templates to the plain order", () => {
  const { validateModelResponse } = require("../bridge/protocol");
  const { buildResponseSchema, SYSTEM_PROMPT } = require("../bridge/lm-studio");
  const support = buildResponseSchema().schema.properties.actions.items.properties.support.enum;
  for (const t of ["CQB", "RUSH", "GARRISON", "DEFEND", "HUNT", "CREEP"]) assert(support.includes(t), t);
  assert.match(SYSTEM_PROMPT, /BEHAVIOUR TEMPLATES/);
  assert.equal((read("bridge/system-prompt.js").match(/BEHAVIOUR TEMPLATES/g) || []).length, 2, "both buildSystemPrompt copies");
  const r = validateModelResponse(JSON.stringify({ version: 3, speech: "", actions: [
    { type: "ASSAULT", position: [1000, 2000], roe: "", support: "CQB" },
    { type: "HOLD", position: [], roe: "", support: "GARRISON" },
    { type: "RECON", position: [1000, 2000], roe: "", support: "RUSH" }
  ] }), { maxActions: 5 });
  assert.deepEqual(r.actions, [["ASSAULT", [1000, 2000], "CQB"], ["HOLD", [], "GARRISON"], ["RECON", [1000, 2000], ""]]);
});

test("templates march first, start LAMBS on arrival or contact, and are optional", () => {
  const order = fn("tactical/fn_tacticOrder.sqf");
  assert.match(order, /if \(isNil "lambs_wp_fnc_taskCQB"\) exitWith/);
  assert.match(order, /\[_group, "MOVE", _position\] call NeroAI_fnc_vehicleTactics;/);
  assert.match(order, /distance2D _position\) < 350/);
  assert.match(order, /targets \[true, 400, \[\], 20\]/);
  assert.match(order, /lambs_wp_fnc_taskCQB/);
  assert.match(order, /\[_group, 500, 15, \[\], _position, false, false, 0\] spawn lambs_wp_fnc_taskHunt/, "hunt AI enemies, not only players");
  assert.match(order, /\[_group, 400, 15, \[\], _position, false\] spawn lambs_wp_fnc_taskRush/);
  assert.match(order, /_tactic in \["CQB", "GARRISON"\] && \{count _houses < 2\}/, "building templates need buildings");
  assert.match(order, /NeroWL_routeEpoch/);
  const cfg = fn("CfgFunctions.hpp");
  assert.match(cfg, /class tacticOrder \{\};/);
  assert.match(cfg, /class tacticStop \{\};/);
});

test("any new order terminates the LAMBS loop and soft-resets without replacing the group", () => {
  const stop = fn("tactical/fn_tacticStop.sqf");
  assert.match(stop, /terminate _h/);
  assert.match(stop, /\[_group, true, false\] call lambs_wp_fnc_taskReset/);
  const macro = fn("core/fn_executeMacro.sqf");
  assert.match(macro, /\[_group\] call NeroAI_fnc_tacticStop;\s*\[_group\] call NeroAI_fnc_routeStop/);
  for (const t of ["ASSAULT", "HOLD", "RECON"]) assert(macro.includes(`[_group, "${t}", _tactic,`), t);
});

test("LAMBS is off on road marches and on in contact; busy groups are not replanned or re-tasked", () => {
  const route = fn("tactical/fn_vehicleRoute.sqf");
  assert.match(route, /"NeroWL_routeMode","ROAD"\];\s*\/\*[^*]*\*\/\s*_group setVariable \["lambs_danger_disableGroupAI", true\];/);
  assert.match(route, /"NeroWL_routeMode","CONTACT"\];\s*\/\*[^*]*\*\/\s*_group setVariable \["lambs_danger_disableGroupAI", nil\];/);
  assert.match(fn("tactical/fn_autoRequisition.sqf"), /NeroWL_tactic", \[\]\]\) param \[3, ""\]\)\) isEqualTo "EXEC"\) exitWith \{\};/);
  assert.match(fn("tactical/fn_tacticalAutonomy.sqf"), /NeroAI_tacticReplanSeconds", 240/);
  assert.match(fn("core/fn_buildSnapshot.sqf"), /\[_t # 0, _t # 3, round \(diag_tickTime - \(_t # 2\)\)\]/);
  const launch = JSON.parse(read("tools/warlords-launch.json").replace(/^﻿/, ""));
  assert(launch.mods.some(m => m.endsWith("\\@LAMBS_Danger.fsm")));
});

test("AI-to-AI orders without a template get the obvious one; the player's orders stay literal", () => {
  const macro = fn("core/fn_executeMacro.sqf");
  assert.match(macro, /if \(_tactic isEqualTo "" && \{_autonomousSource\} && \{missionNamespace getVariable \["NeroAI_tacticDefaults", true\]\}\) then \{/);
  assert.match(macro, /_type isEqualTo "ASSAULT" && \{_hasPosition\}[^\n]*>= 6\}\) then \{_tactic = "CQB";\};/);
  assert.match(macro, /if \(_type isEqualTo "HOLD"\) then \{_tactic = "GARRISON";\};/);
  assert.match(read("bridge/system-prompt.js"), /prefer a template whenever one fits/);
});
