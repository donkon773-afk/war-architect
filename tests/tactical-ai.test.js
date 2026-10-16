'use strict';
// 11.10: "Тактический ИИ NeroAI — без LLM" — a rule-based side strategist and
// squad tactics inside the addon; no bridge, no INIDBI, no model checks.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.join(__dirname, '..');
const read = rel => fs.readFileSync(path.join(root, rel), 'utf8');
const fn = 'addons/NeroAI3/functions/';

test('rules SQF: every file parses in SQF-VM and the pure decision functions pass their assertions', () => {
  const r = require('../tools/verify-rules-sqf').verify();
  assert.equal(r.parsedFiles, 16);
  assert.equal(r.parsedIntegrationFiles, 11);
  assert.deepEqual(r.executedPureFunctions, ['rulesScoreSector','rulesPosture','rulesAllocate','rulesReadiness','rulesAmmoTier','rulesOperation','rulesAssaultPoint','rulesSupportScore','rulesUniqueIntel','rulesChooseBehaviour']);
  assert(r.assertions >= 99, `assertions ${r.assertions}`);
});

test('registry: the rules folder and CfgFunctions list the same functions', () => {
  const files = fs.readdirSync(path.join(root, fn, 'rules')).filter(n => /^fn_.*\.sqf$/.test(n)).map(n => n.slice(3, -4)).sort();
  const cfg = read(fn + 'CfgFunctions.hpp');
  const start = cfg.indexOf('class rules {'), end = cfg.indexOf('class rulesRadio {};') + 'class rulesRadio {};'.length;
  assert(start > 0 && end > start, 'category registered');
  const block = cfg.slice(start, end);
  assert.match(block, /file = "\\NeroWL\\functions\\rules";/);
  const listed = [...block.matchAll(/class (rules\w+) \{\};/g)].map(m => m[1]).sort();
  assert.deepEqual(listed, files);
});

test('panel: tactical mode needs no model, sets lobby value 2, Warlords only, config marked tacticalAI', () => {
  const core = require('../control-center/core');
  if (!fs.existsSync(core.profileFile)) return; // user data is local
  const state = core.load();
  const base = { ...state.selected, scenario: 'warlords' };
  const v = core.validate({ ...base, mode: 'tactical', primaryNode: 'missing-node', primaryModel: '', allyRoute: 'separate', allyNode: 'missing' }, state);
  assert.equal(v.parameters.NeroWL_VanillaAI, 2);
  assert.equal(v.mode, 'tactical');
  assert.throws(() => core.validate({ ...base, scenario: 'antistasi', mode: 'tactical' }, state), /только для Warlords/);
  const config = core.makeConfig({ ...base, mode: 'tactical' }, state, { lmStudio: {}, transport: {} });
  assert.equal(config.tacticalAI, true);
  assert.equal(config.standardAI, undefined);
  const llm = core.validate({ ...base, mode: 'single', parameters: { ...base.parameters, NeroWL_VanillaAI: 2 } }, state);
  assert.equal(llm.parameters.NeroWL_VanillaAI, undefined, 'LLM mode never carries the switch');
  const server = read('control-center/server.js');
  assert(server.includes('const vanilla=s.mode==="vanilla",tactical=s.mode==="tactical",noLLM=vanilla||tactical;'));
  assert(server.includes('if(!noLLM&&s.scenario==="warlords"&&s.useDesign)'), 'garrison model is not checked either');
});

test('launch: no model check and no bridge; LAMBS is kept (stripped only for the standard-AI mode)', () => {
  const ps = read('control-center/launch.ps1');
  assert.match(ps, /\$tactical=\(\$request\.scenario -eq 'warlords' -and \$request\.mode -eq 'tactical'\)/);
  assert.match(ps, /\$noBridge=\(\$vanilla -or \$tactical\)/);
  assert.equal((ps.match(/if \(-not \$noBridge\) \{/g) || []).length, 2, 'check-brains and bridge start are both skipped');
  assert.match(ps, /if \(\$vanilla -and -not \$request\.vanillaLambs\) \{\$mods=/, 'only the standard-AI mode removes LAMBS');
  assert(ps.includes('tacticalAI=$tactical;'));
});

test('mission: lobby value 2 turns the rules mode on and keeps the NeroAI services', () => {
  const params = read('tools/mission-assets/params.hpp');
  assert.match(params, /class NeroWL_VanillaAI \{title="Кто командует ботами"; values\[\]=\{0,1,2\}; texts\[\]=\{"NeroAI — LLM-командиры","Штатный ИИ Arma \(NeroAI не вмешивается\)","Тактический ИИ NeroAI — без LLM"\}; default=0;\};/);
  const patched = params.replace(new RegExp('(class NeroWL_VanillaAI \\{[^\\n]*default=)[^;]+'), (_, p) => p + 2);
  assert.match(patched, /class NeroWL_VanillaAI \{[^\n]*default=2;/, 'the launcher default patch reaches the class');
  const s = read('tools/mission-assets/fn_applySettings.sqf');
  assert(s.includes('NeroAI_rulesMode = _aiMode == 2;'));
  assert(s.includes('"NeroAI_rulesMode"'), 'published to clients (ready message, menu)');
  assert(s.includes('NeroAI_enemyAIEnabled = !NeroAI_vanillaMode && {'), 'enemy squads are enrolled in the rules mode');
  assert(read('tools/mission-assets/fn_waitReady.sqf').includes('Ботами командует тактический ИИ NeroAI (без LLM)'));
});

test('addon: no INIDBI/bridge in the rules mode; plans are local; vote watcher and strategist run on own threads', () => {
  const init = read(fn + 'bootstrap/fn_initServer.sqf');
  assert(init.indexOf('private _rules = missionNamespace getVariable ["NeroAI_rulesMode", false];') < init.indexOf('waitUntil {\n            if (!isNil "OO_INIDBI")'.replace(/\n/g, init.includes('\r\n') ? '\r\n' : '\n')));
  assert(init.includes('if (!_rules && {isNil "OO_INIDBI"}) exitWith {'));
  assert(init.includes('NeroAI_planSkipUnchanged = false;') && init.includes('NeroAI_intergroupEnabled = false;'));
  const loop = read(fn + 'bootstrap/fn_serverLoop.sqf');
  assert(loop.includes('if (NeroAI_transportReady && {!NeroAI_rulesMode}) then {\n            [] call NeroAI_fnc_pollBridgeResponses;'.replace(/\n/g, loop.includes('\r\n') ? '\r\n' : '\n')));
  assert(loop.includes('[] spawn NeroAI_fnc_rulesVoteWatch;') && loop.includes('[] call NeroAI_fnc_rulesCommander;'));
  assert(read(fn + 'bootstrap/fn_preInit.sqf').includes('NeroAI_rulesMode = false;'));
  const auto = read(fn + 'tactical/fn_tacticalAutonomy.sqf');
  assert(auto.includes('[_planGroup, _reason, _intelRows] call NeroAI_fnc_rulesGroupPlan;'));
  assert(auto.indexOf('NeroAI_fnc_rulesGroupPlan') < auto.indexOf('NeroAI_fnc_sendBridgeRequest'), 'the bridge request sits in the else branch');
  assert(auto.includes('{!_rulesTasked}'), 'a tasked squad is not sent back to the native waypoint');
  assert(read(fn + 'core/fn_sendBridgeRequest.sqf').includes('if (missionNamespace getVariable ["NeroAI_rulesMode", false]) exitWith {[false,'));
  assert(read(fn + 'communication/fn_handleChat.sqf').includes('if (missionNamespace getVariable ["NeroAI_rulesMode", false]) exitWith {false};'));
  assert(read(fn + 'communication/fn_receiveClientCommand.sqf').includes('Тактический ИИ без LLM: текстовые приказы не разбираются.'));
});

test('guards: own-sector targets are allowed only in the rules mode; the vote never touches a player', () => {
  const m = read(fn + 'core/fn_executeMacro.sqf');
  assert(m.includes('private _ownSectorTarget = NeroAI_rulesMode && {_hasPosition} && {'));
  assert(m.includes('{_type in ["ADVANCE", "ASSAULT", "RETREAT"]} && {!_ownSectorTarget} &&'));
  assert(m.indexOf('private _hasPosition') < m.indexOf('private _ownSectorTarget'), 'position is resolved first');
  const vote = read(fn + 'rules/fn_rulesVoteWatch.sqf');
  assert(vote.includes('private _ai = _wls select {!isPlayer _x};'));
  assert(vote.includes('} forEach _ai;'), 'votes are written for AI commanders only');
  assert(vote.includes('((missionNamespace getVariable ["BIS_WL_AICanVote", 1]) isEqualTo 1) || {_humans isEqualTo []}'), 'native AI-voting rule kept');
  assert(vote.includes('_source = "голос игрока"'), "a player's vote leads the AI commanders");
  assert(vote.includes('NeroWL_threeSides'), 'three-side missions keep their own vote');
  const plan = read(fn + 'rules/fn_rulesGroupPlan.sqf');
  assert(plan.includes('[_group, _type, _pos, _arg, "AUTONOMY"] call NeroAI_fnc_executeMacro'), 'every order goes through the whitelist and its guards');
  for (const f of fs.readdirSync(path.join(root, fn, 'rules'))) {
    const code = read(fn + 'rules/' + f).replace(/\/\*[\s\S]*?\*\//g, '');
    assert.doesNotMatch(code, /\b(?:compile|execVM|createUnit|createVehicle|setPos(?:ATL|ASL)?)\b/, `${f}: no code generation, spawning or teleport`);
    assert.doesNotMatch(code, /setVariable\s*\[\s*"BIS_WL_funds"/, `${f}: CP is never written directly`);
  }
});

test('UI: third choice "Тактический ИИ NeroAI — без LLM"; model and instruction pages are off for it', () => {
  const h = read('control-center/index.html');
  assert(h.includes('id="aiTactical" value="tactical"'));
  assert(h.includes("function aiTactical(){return by('aiTactical').checked&&by('scenario').value==='warlords';}"));
  assert(h.includes('s.mode=aiVanilla()?"vanilla":aiTactical()?"tactical":by("mode").value;'));
  assert(h.includes('by("aiTactical").checked=s.mode==="tactical";'));
  assert(h.includes('mb.disabled=noLLM;') && h.includes('ib.disabled=anti||noLLM;'));
  assert(h.includes('for(const id of ["aiLLM","aiVanilla","aiTactical","vanillaLambs"])'));
});
