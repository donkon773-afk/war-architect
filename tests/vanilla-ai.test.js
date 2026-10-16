'use strict';
// 9.10: "Штатный ИИ Arma" — the launch can switch fully to standard Arma/Warlords AI:
// no bridge, no model check, NeroAI leaves every group alone.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const root = path.join(__dirname, '..');
const read = rel => fs.readFileSync(path.join(root, rel), 'utf8');

test('panel validation: vanilla needs no model, sets the lobby switch, keeps the LLM settings intact', () => {
  const core = require('../control-center/core');
  if (!fs.existsSync(core.profileFile)) return; // user data is local
  const state = core.load();
  const base = { ...state.selected, scenario: 'warlords', vanillaLambs: undefined };
  const v = core.validate({ ...base, mode: 'vanilla', primaryNode: 'missing-node', primaryModel: '', allyRoute: 'separate', allyNode: 'missing' }, state);
  assert.equal(v.parameters.NeroWL_VanillaAI, 1);
  assert.equal(v.vanillaLambs, false);
  assert.equal(v.parameters.NeroWL_LLM, base.parameters?.NeroWL_LLM, 'the LLM lobby value is not overwritten — switching back restores it');
  const llm = core.validate({ ...base, mode: 'single', parameters: { ...base.parameters, NeroWL_VanillaAI: 1 } }, state);
  assert.equal(llm.parameters.NeroWL_VanillaAI, undefined, 'LLM mode never carries the standard-AI switch');
  assert.throws(() => core.validate({ ...base, scenario: 'antistasi', mode: 'vanilla' }, state), /только для Warlords/);
  assert.throws(() => core.validate({ ...base, mode: 'vanilla', vanillaLambs: 'yes' }, state), /LAMBS/);
  const config = core.makeConfig({ ...base, mode: 'vanilla' }, state, { lmStudio: {}, transport: {} });
  assert.equal(config.standardAI, true);
});

test('launch: no model check, no bridge and (by default) no LAMBS in the standard-AI mode', () => {
  const ps = read('control-center/launch.ps1');
  assert.match(ps, /\$vanilla=\(\$request\.scenario -eq 'warlords' -and \$request\.mode -eq 'vanilla'\)/);
  assert.match(ps, /\$noBridge=\(\$vanilla -or \$tactical\)\s*if \(-not \$noBridge\) \{\s*& \$node \(Join-Path \$projectPath 'tools\\check-brains\.js'\)/);
  assert.match(ps, /if \(\$vanilla -and -not \$request\.vanillaLambs\) \{\$mods=@\(\$mods \| Where-Object \{\(Split-Path -Leaf \$_\) -ne '@LAMBS_Danger\.fsm'\}\)\}/);
  assert.match(ps, /if \(-not \$noBridge\) \{\s*\$bridgePath=/);
  assert(ps.indexOf("Stop-Process -Id $processInfo.ProcessId") < ps.indexOf('$bridgePid=$null'), 'old bridges are still stopped first');
  const server = read('control-center/server.js');
  assert(server.includes('for(const prefix of noLLM?[]:s.mode==="dual"'), 'node models are not queried');
});

test('mission: lobby switch disables LLM, friendly enrolment, ambush/counter-battery and the skill override', () => {
  const params = read('tools/mission-assets/params.hpp');
  assert.match(params, /class NeroWL_VanillaAI \{title="Кто командует ботами"; values\[\]=\{0,1,2\};[^\n]*default=0;\};/);
  // the launcher's default patch (build-australia-mission) must hit the new class
  const patched = params.replace(new RegExp('(class NeroWL_VanillaAI \\{[^\\n]*default=)[^;]+'), (_, p) => p + 1);
  assert.match(patched, /class NeroWL_VanillaAI \{[^\n]*default=1;/);
  const s = read('tools/mission-assets/fn_applySettings.sqf');
  assert(s.includes('private _aiMode = ["NeroWL_VanillaAI",0,[0,1,2]] call _param;') && s.includes('NeroAI_vanillaMode = _aiMode == 1;'));
  assert(s.includes('NeroAI_enemyAIEnabled = !NeroAI_vanillaMode && {'));
  assert(s.includes('NeroWL_friendlyMode=if (NeroAI_vanillaMode) then {0}'));
  assert(s.indexOf('if (NeroAI_vanillaMode) exitWith {};') < s.indexOf('_x setSkill'), 'difficulty profile skills stay standard');
  assert(read('tools/designer-assets/fn_observer.sqf').includes('!(missionNamespace getVariable ["NeroAI_vanillaMode",false])'));
});

test('addon: server never starts the bridge/planner; menu, chat and enrolment are inert', () => {
  const fn = 'addons/NeroAI3/functions/';
  const init = read(fn + 'bootstrap/fn_initServer.sqf');
  const exit = init.indexOf('if (missionNamespace getVariable ["NeroAI_vanillaMode", false]) exitWith {');
  assert(exit > 0 && exit < init.indexOf('OO_INIDBI') && exit < init.indexOf('NeroAI_fnc_serverLoop'));
  assert(init.indexOf('NeroWL_settingsApplied') < exit, 'waits (bounded) for the mission settings first');
  assert(read(fn + 'bootstrap/fn_preInit.sqf').includes('NeroAI_vanillaMode = false;'));
  assert(read(fn + 'core/fn_registerGroup.sqf').includes('if (missionNamespace getVariable ["NeroAI_vanillaMode", false]) exitWith {[false,'));
  assert.equal((read(fn + 'communication/fn_installPlayerActions.sqf').match(/NeroAI_vanillaMode/g) || []).length, 2);
  assert(read(fn + 'communication/fn_handleChat.sqf').includes('if (missionNamespace getVariable ["NeroAI_vanillaMode", false]) exitWith {false};'));
  assert(read(fn + 'communication/fn_openControlMenu.sqf').includes('NeroAI_vanillaMode'));
});

test('observer host: native sound messages and scan reveal have inert defaults (RPT 9.10: undefined bis_wl_voice / bis_wl_revealarr)', () => {
  const v = read('addons/NeroAI3/functions/native/fn_WLVarsInit.sqf');
  assert(v.includes('if (!isDedicated && {(missionNamespace getVariable ["NeroWL_localObserver", getNumber (missionConfigFile >> "NeroWL_observer") == 1])}) then {BIS_WL_revealArr = []; BIS_WL_voice = 0; BIS_WL_music = 0;};'));
  assert.equal(v, require('../tools/adapt-vars-init').adapt(read('research/native/Warlords/fn_WLVarsInit.sqf')));
});

test('observer mission: a WEST/EAST slot (host playing for a side) gets the full Warlords UI; only Civilian observes', () => {
  const init = read('addons/NeroAI3/functions/native/fn_WLInit.sqf');
  assert(init.includes('if (!isNull player && {(side group player) in [WEST, EAST]}) then {_neroObserver = false;};'));
  assert(init.indexOf('NeroWL_localObserver = _neroObserver;') < init.indexOf('_logic call BIS_fnc_WLVarsInit;'), 'decided before the client variables');
  assert(init.indexOf('NeroWL_localObserver = _neroObserver;') < init.indexOf('if !(isDedicated || _neroObserver) then {'));
  assert.equal(init, require('../tools/adapt-observer-init').adapt(read('research/native/Warlords/fn_WLInit.sqf')));
  const ready = read('tools/mission-assets/fn_waitReady.sqf');
  assert(ready.includes('private _observer = _observerMission && {missionNamespace getVariable ["NeroWL_localObserver"'));
  assert(!read('tools/designer-assets/fn_observer.sqf').includes('Для наблюдения выберите'));
});

test('UI: one switch "who commands the bots"; LLM pages and parameters hide in the standard mode', () => {
  const h = read('control-center/index.html');
  assert(h.includes('id="aiVanilla" value="vanilla"') && h.includes('id="aiLLM" value="llm"') && h.includes('id="vanillaLambs"'));
  assert(h.includes('s.mode=aiVanilla()?"vanilla":aiTactical()?"tactical":by("mode").value;s.vanillaLambs=by("vanillaLambs").checked;'));
  assert(h.includes('by("mode").value=s.mode==="vanilla"||s.mode==="tactical"?"single":s.mode;by("aiVanilla").checked=s.mode==="vanilla";'));
  assert(h.includes("const LLM_PARAMS=['NeroWL_LLM','NeroWL_FriendlyLLM','NeroWL_FriendlyLimit']"));
  assert(h.includes(".vanilla-ai .llm-only,.vanilla-ai [data-llm]{display:none!important}"));
});
