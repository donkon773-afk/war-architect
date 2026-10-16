'use strict';
// 8.10: "after Save it is 100% saved" — durable writes, in-place preset updates,
// stale-window refusal, recoverable delete, one-page editor.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), os = require('node:os'), path = require('node:path'), vm = require('node:vm');
const durable = require('../control-center/durable');
const { createStore } = require('../control-center/map-presets');

function fixture(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'nero-reliable-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  let current = { world: 'Test', title: 'Game map', bases: [{}, {}], sectors: [{ id: 's' }], spawns: [], mode: 'native' };
  const schema = { worlds: () => [{ id: 'Test' }], load: () => structuredClone(current), validate: d => { if (d.world !== 'Test' || !d.sectors.length) throw Error('invalid'); return structuredClone(d); }, save: d => { current = structuredClone(d); return d; } };
  return { dir, store: createStore(dir, schema), current: () => current };
}

test('durable write flushes, renames and reads back; temp files never remain', t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'nero-durable-')); t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const file = path.join(dir, 'a', 'x.json');
  const back = durable.write(file, { b: 1, a: [1, 2, { z: 'я' }] });
  assert.deepEqual(back, { b: 1, a: [1, 2, { z: 'я' }] });
  assert.deepEqual(fs.readdirSync(path.dirname(file)), ['x.json']);
  assert.equal(durable.hash({ a: 1, b: 2 }), durable.hash({ b: 2, a: 1 }), 'key order does not matter');
});

test('a preset is updated in place with a revision; an older window is refused', t => {
  const f = fixture(t);
  const a = f.store.save('Sydney', { ...f.current(), title: 'v1' }, []);
  assert.equal(a.revision, 1); assert.equal(a.verified, true);
  const b = f.store.update(a.id, { design: { ...f.current(), title: 'v2' }, revision: 1 }, []);
  assert.equal(b.revision, 2); assert.equal(f.store.get(a.id).design.title, 'v2');
  assert.equal(f.store.list().length, 1, 'no duplicate preset');
  assert.throws(() => f.store.update(a.id, { design: { ...f.current(), title: 'stale' }, revision: 1 }, []), /другом окне/);
  assert.equal(f.store.get(a.id).design.title, 'v2', 'stale write did not land');
  assert.throws(() => f.store.save('sydney', f.current(), []), /уже есть/, 'duplicate names per map are refused');
  const r = f.store.update(a.id, { name: 'Sydney east', revision: 2 }, []);
  assert.equal(r.name, 'Sydney east');
});

test('the in-game preset stays the game map after an edit; delete goes to a recoverable bin', t => {
  const f = fixture(t);
  const p = f.store.save('Live', { ...f.current(), title: 'Live' }, []);
  assert.equal(f.store.list()[0].inGame, false);
  f.store.apply(p.id, []);
  assert.equal(f.store.list()[0].inGame, true);
  const u = f.store.update(p.id, { design: { ...f.current(), title: 'Live 2' }, revision: 1 }, []);
  assert.equal(u.appliedToGame, true); assert.equal(f.current().title, 'Live 2');
  f.store.remove(p.id, 2);
  assert.equal(f.store.list().length, 0);
  assert.equal(fs.readdirSync(path.join(f.dir, 'deleted')).length, 1);
  assert.throws(() => f.store.get(p.id), /не найден/);
});

test('launch presets: revision guard refuses a stale page, presets can be deleted', () => {
  const core = require('../control-center/core');
  const source = fs.readFileSync(path.join(__dirname, '..', 'control-center', 'core.js'), 'utf8');
  const state = { nodes: [{ id: 'mac', label: 'Mac', baseUrl: 'http://127.0.0.1:1234/v1' }], presets: {} };
  const selected = { scenario: 'warlords', mode: 'single', primaryNode: 'mac', primaryModel: 'm', secondaryNode: 'mac', secondaryModel: 'm', temperature: 0.9, maxTokens: 900, profile: 'donko', map: 'Australia', ace: true, dev: true, parameters: {} };
  let snapshot = { ...structuredClone(state), selected: core.validate(selected, state), revision: 3 };
  const context = vm.createContext({ require, load: () => structuredClone(snapshot), validate: core.validate, publicState: s => ({ ...s, revision: s.revision || 0 }), profileFile: 'isolated', atomic: (file, value) => { snapshot = value; } });
  vm.runInContext(source.slice(source.indexOf('function selectedPresetName('), source.indexOf('function addNode(')), context);
  context.sel = selected;
  assert.throws(() => vm.runInContext('saveSelected(sel,"A",{revision:2})', context), /другом окне/);
  const r = vm.runInContext('saveSelected(sel,"A",{revision:3})', context);
  assert.equal(r.revision, 4); assert(Object.hasOwn(snapshot.presets, 'A'));
  vm.runInContext('deletePreset("A",{revision:4})', context);
  assert.equal(Object.hasOwn(snapshot.presets, 'A'), false); assert.equal(snapshot.revision, 5);
  assert.throws(() => vm.runInContext('deletePreset("A",{revision:5})', context), /не найден/);
});

test('one page: editor embedded in the main tab, same-origin framing only, verified UI saves', () => {
  const server = fs.readFileSync('control-center/server.js', 'utf8');
  assert.match(server, /url\.pathname==='\/designer'\)\{res\.writeHead\(200,\{[^}]*"X-Frame-Options":"SAMEORIGIN","Content-Security-Policy":"frame-ancestors 'self'"/);
  assert.match(server, /url\.pathname==="\/"\)\{res\.writeHead\(200,\{[^}]*"X-Frame-Options":"DENY"/, 'the main page itself is still never framed');
  for (const route of ['/api/map-preset-update', '/api/map-preset-delete', '/api/preset-delete']) assert(server.includes(route), route);
  const main = fs.readFileSync('control-center/index.html', 'utf8');
  assert(main.includes('by("openDesigner").onclick=()=>{showAppTab("maps");}'), 'no page switch');
  assert(main.includes('revision:state.revision'));
  const editor = fs.readFileSync('control-center/designer.html', 'utf8');
  assert(editor.includes('async function verifySaved('));
  assert(editor.includes("✓ Сохранено и проверено"));
  assert(editor.includes("expectedSavedAt:d.savedAt||''"));
  assert(editor.includes("(e.ctrlKey||e.metaKey)&&String(e.key).toLowerCase()==='s'"));
});

test('every catalog faction has a readable Russian name; stored values stay class names', () => {
  const { factionLabel, labels } = require('../control-center/faction-names');
  const inv = require('../control-center/warlords-editor').inventory();
  const l = labels(inv.factions);
  for (const f of inv.factions) { assert.notEqual(l[f], f, f); assert.doesNotMatch(l[f], /^(rhs|cup|b_|BLU_|OPF_)/i, f); }
  assert.equal(factionLabel('rhsgref_faction_cdf_ng'), 'Национальная гвардия Чернаруси (RHS GREF, зелёные)');
  assert.match(factionLabel('rhs_faction_unknown_new'), /\(RHS\)$/, 'fallback for factions added later');
  const server = fs.readFileSync('control-center/server.js', 'utf8');
  assert(server.includes('factionLabels:require("./faction-names").labels(inv.factions)'));
  assert(fs.readFileSync('control-center/index.html', 'utf8').includes('text:catalog?.factionLabels?.[f]||f'));
  assert(fs.readFileSync('control-center/designer.html', 'utf8').includes('function sideNames()'));
});
