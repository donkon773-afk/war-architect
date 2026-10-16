"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { createBridge, radioReplyFor, validateRequest, appendEntry } = require("../bridge/server");
const { parseIniEntries } = require("../bridge/protocol");

function config(iniFolder) {
  return {
    lmStudio: { baseUrl: "http://127.0.0.1:1234/v1", model: "mock", apiKey: "lm-studio", timeoutMs: 1000, temperature: 0.2, maxTokens: 64, reasoningEffort: "none" },
    transport: { iniFolder, outboxDb: "NeroAI4_out", inboxDb: "NeroAI4_in", pollMs: 100, maxPending: 1 },
    limits: { maxSnapshotChars: 3600, maxSpeechChars: 420, maxActions: 3 }
  };
}

async function waitForResponse(folder, id) {
  const file = path.join(folder, "NeroAI4_in.ini");
  const deadline = Date.now() + 2000;
  while (Date.now() < deadline) {
    if (fs.existsSync(file)) {
      const response = parseIniEntries(fs.readFileSync(file, "utf8"), "NeroAI4_in").get(id);
      if (response) return response;
    }
    await new Promise(resolve => setTimeout(resolve, 10));
  }
  throw new Error(`Bridge did not finish response ${id} within two seconds`);
}

test("concurrent response writes preserve every entry and create one INI section", async t => {
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), "neroai3-test-"));
  t.after(() => fs.rmSync(folder, { recursive: true, force: true }));
  const file = path.join(folder, "NeroAI4_in.ini");
  await Promise.all(Array.from({ length: 20 }, (_, i) => appendEntry(file, "NeroAI4_in", `r_${i}`, ["response", ["ok", `r_${i}`, "Принял.", []]])));
  const text = fs.readFileSync(file, "utf8");
  assert.equal((text.match(/^\[NeroAI4_in\]$/gm) || []).length, 1);
  const entries = parseIniEntries(text, "NeroAI4_in");
  assert.equal(entries.size, 20);
  for (let i = 0; i < 20; i++) assert.equal(entries.get(`r_${i}`)[1][1], `r_${i}`);
});

test("bridge writes one safe SQF response for a validated local-model result", async t => {
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), "neroai3-test-"));
  t.after(() => fs.rmSync(folder, { recursive: true, force: true }));
  const cfg = config(folder);
  const bridge = createBridge({
    config: cfg,
    completion: async () => JSON.stringify({ version: 3, speech: "Alpha 1-2 will advance and report status.", actions: [{ type: "ADVANCE", position: [120, 340] }] })
  });
  await bridge.processRequest({ id: "n3_100", channel: "SIDE", targetIds: ["group-id"], snapshot: "[\"v\",3]" });
  const output = fs.readFileSync(path.join(folder, "NeroAI4_in.ini"), "utf8");
  const response = parseIniEntries(output, "NeroAI4_in").get("n3_100");
  assert.deepEqual(response, ["response", ["ok", "n3_100", "Alpha 1-2 will advance and report status.", [["ADVANCE", [120, 340], ""]]]]);
});

test("radio acknowledgements are deterministic Russian combat replies", () => {
  assert.equal(radioReplyFor([["RETREAT", [120, 340], ""]]), "Приказ принят. Отходим к указанной точке.");
  assert.equal(radioReplyFor([["REPORT", [], ""]]), "Приказ принят. Наблюдаем, доклад готовим.");
  assert.match(radioReplyFor([]), /не исполнен/);
  assert.equal(
    radioReplyFor([["BOARD", [], ""], ["ADVANCE", [120, 340], ""], ["SET_ROE", [], "HOLD_FIRE"]]),
    "Приказ принят: занимаем технику, выдвигаемся к указанной точке, огонь не открываем."
  );
});

test("bridge honours an explicit boarding order even when the model proposes movement", async t => {
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), "neroai3-test-"));
  t.after(() => fs.rmSync(folder, { recursive: true, force: true }));
  const bridge = createBridge({
    config: config(folder),
    completion: async () => JSON.stringify({ version: 3, speech: "Move to cover.", actions: [{ type: "ADVANCE", position: [120, 340] }] })
  });
  await bridge.processRequest({
    id: "n3_board",
    channel: "GROUP",
    targetIds: ["group-id"],
    snapshot: '["v",3,"order","Альфа 1-2 займите танки на взлетной полосе"]'
  });
  const response = parseIniEntries(fs.readFileSync(path.join(folder, "NeroAI4_in.ini"), "utf8"), "NeroAI4_in").get("n3_board");
  assert.deepEqual(response[1].slice(2), ["Move to cover.", [["BOARD", [], ""]]]);
});

test("bridge answers a question in the model's voice and only ever a REPORT, never a retask", async t => {
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), "neroai3-test-"));
  t.after(() => fs.rmSync(folder, { recursive: true, force: true }));
  const bridge = createBridge({
    config: config(folder),
    completion: async () => JSON.stringify({ version: 3, speech: "Гроза-1 — идём по маршруту на Бастам, контактов нет.", actions: [{ type: "ADVANCE", position: [9000, 9000] }] })
  });
  await bridge.processRequest({ id: "n3_question", channel: "SIDE", targetIds: ["group-id"], snapshot: '["v",3,"order","Альфа 1-4 куда вы выдвигаетесь?"]' });
  const response = parseIniEntries(fs.readFileSync(path.join(folder, "NeroAI4_in.ini"), "utf8"), "NeroAI4_in").get("n3_question");
  assert.deepEqual(response[1][3], [["REPORT", [], ""]]);
  assert.equal(response[1][2], "Гроза-1 — идём по маршруту на Бастам, контактов нет.");
});

test("bridge acknowledges situational information in character and invents no action", async t => {
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), "neroai3-test-"));
  t.after(() => fs.rmSync(folder, { recursive: true, force: true }));
  const bridge = createBridge({
    config: config(folder),
    completion: async () => JSON.stringify({ version: 3, speech: "Принял, наблюдаем за воздухом, продолжаем движение.", actions: [{ type: "ASSAULT", position: [5687, 8947] }] })
  });
  await bridge.processRequest({ id: "n3_info", channel: "SIDE", targetIds: ["group-id"], snapshot: '["v",3,"order","Альфа 1-4 взлетает наш беспилотник"]' });
  const response = parseIniEntries(fs.readFileSync(path.join(folder, "NeroAI4_in.ini"), "utf8"), "NeroAI4_in").get("n3_info");
  assert.deepEqual(response[1][3], []);
  assert.equal(response[1][2], "Принял, наблюдаем за воздухом, продолжаем движение.");
});

test("bridge holds a short role-play conversation without touching the task", async t => {
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), "neroai3-test-"));
  t.after(() => fs.rmSync(folder, { recursive: true, force: true }));
  const bridge = createBridge({
    config: config(folder),
    completion: async () => JSON.stringify({ version: 3, speech: "Спасибо, командир, держимся. Работаем дальше.", actions: [{ type: "HOLD" }] })
  });
  await bridge.processRequest({ id: "n3_chat", channel: "SIDE", targetIds: ["group-id"], snapshot: '["v",3,"order","молодцы бойцы, так держать"]' });
  const response = parseIniEntries(fs.readFileSync(path.join(folder, "NeroAI4_in.ini"), "utf8"), "NeroAI4_in").get("n3_chat");
  assert.deepEqual(response[1][3], []);
  assert.equal(response[1][2], "Спасибо, командир, держимся. Работаем дальше.");
});

test("an INTERGROUP request is answered like an autonomous plan and can send real help", async t => {
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), "neroai3-test-"));
  t.after(() => fs.rmSync(folder, { recursive: true, force: true }));
  const bridge = createBridge({
    config: config(folder),
    completion: async () => JSON.stringify({
      version: 3,
      speech: "Гроза-1, я Гроза-2, выдвигаюсь к вам, три минуты.",
      actions: [{ type: "ADVANCE", position: [4790, 9295] }]
    })
  });
  await bridge.processRequest({
    id: "n3_ig",
    channel: "INTERGROUP",
    origin: "AUTONOMY",
    targetIds: ["group-2"],
    snapshot: '["v",3,"observer",[4700,9400],"groups",[["Гроза-2","VANILLA",[4700,9400],8,8,0,10,[],90]],"sharedIntel",[["Enemy",[4790,9295],40,"Гроза-1"]],"radioFrom",["Гроза-1",[4790,9295],[4790,9295]],"order","INTERGROUP от Гроза-1: запрос подмоги, контакт 4790 9295."]'
  });
  const response = parseIniEntries(fs.readFileSync(path.join(folder, "NeroAI4_in.ini"), "utf8"), "NeroAI4_in").get("n3_ig");
  assert.equal(response[1][2], "Гроза-1, я Гроза-2, выдвигаюсь к вам, три минуты.");
  assert.deepEqual(response[1][3], [["ADVANCE", [4790, 9295], ""]]);
});

test("bridge turns a missing final response into a safe no-action reply", async t => {
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), "neroai3-test-"));
  t.after(() => fs.rmSync(folder, { recursive: true, force: true }));
  const cfg = config(folder);
  const bridge = createBridge({ config: cfg, completion: async () => { throw new Error("reasoning_content only"); } });
  await bridge.processRequest({ id: "n3_101", channel: "GROUP", targetIds: ["group-id"], snapshot: "[\"v\",3]" });
  const response = parseIniEntries(fs.readFileSync(path.join(folder, "NeroAI4_in.ini"), "utf8"), "NeroAI4_in").get("n3_101");
  assert.equal(response[1][3].length, 0);
  assert.match(response[1][2], /помехи/);
});

test("invalid model JSON never becomes a false acceptance", async t => {
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), "neroai3-test-"));
  t.after(() => fs.rmSync(folder, { recursive: true, force: true }));
  const bridge = createBridge({ config: config(folder), completion: async () => "not-json" });
  await bridge.processRequest({ id: "n3_invalid", channel: "GROUP", targetIds: ["group-id"], snapshot: '["v",3]' });
  const response = parseIniEntries(fs.readFileSync(path.join(folder, "NeroAI4_in.ini"), "utf8"), "NeroAI4_in").get("n3_invalid");
  assert.equal(response[1][3].length, 0);
  assert.doesNotMatch(response[1][2], /Приказ принят/);
});

test("poller accepts an INIDBI2 outbox row once and does not duplicate its response", async t => {
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), "neroai3-test-"));
  t.after(() => fs.rmSync(folder, { recursive: true, force: true }));
  const cfg = config(folder);
  fs.writeFileSync(
    path.join(folder, "NeroAI4_out.ini"),
    "[NeroAI4_out]\r\nn3_poll = [\"request\",[3,\"n3_poll\",\"SIDE\",[\"group-id\"],\"snapshot\"]]\r\n",
    "utf8"
  );
  const bridge = createBridge({ config: cfg, completion: async () => JSON.stringify({ version: 3, speech: "Принял.", actions: [{ type: "HOLD" }] }) });
  assert.equal(await bridge.pollOnce(), 1);
  await waitForResponse(folder, "n3_poll");
  assert.equal(await bridge.pollOnce(), 0);
  const entries = parseIniEntries(fs.readFileSync(path.join(folder, "NeroAI4_in.ini"), "utf8"), "NeroAI4_in");
  assert.deepEqual(entries.get("n3_poll")[1][3], [["HOLD", [], ""]]);
  assert.equal(entries.size, 1);
});

test("poller accepts a live-format INIDBI2-wrapped outbox row", async t => {
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), "neroai3-test-"));
  t.after(() => fs.rmSync(folder, { recursive: true, force: true }));
  const cfg = config(folder);
  fs.writeFileSync(
    path.join(folder, "NeroAI4_out.ini"),
    '[NeroAI4_out]\r\nn3_wrapped="["request",[3,"n3_wrapped","SIDE",["group-id"],"snapshot"]]"\r\n',
    "utf8"
  );
  const bridge = createBridge({ config: cfg, completion: async () => JSON.stringify({ version: 3, speech: "Принял.", actions: [{ type: "HOLD" }] }) });
  assert.equal(await bridge.pollOnce(), 1);
  await waitForResponse(folder, "n3_wrapped");
  const entries = parseIniEntries(fs.readFileSync(path.join(folder, "NeroAI4_in.ini"), "utf8"), "NeroAI4_in");
  assert.deepEqual(entries.get("n3_wrapped")[1][3], [["HOLD", [], ""]]);
});

test("wire validator accepts an explicit autonomous origin", () => {
  const cfg = config("unused");
  const request = validateRequest(
    "n3_auto_wire",
    ["request", [3, "n3_auto_wire", "AUTONOMY", ["group-id"], '["v",3]', "AUTONOMY"]],
    cfg
  );
  assert.equal(request.origin, "AUTONOMY");
  assert.equal(request.channel, "AUTONOMY");
});

test("response append retries while INIDBI2 holds the inbox lock", async t => {
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), "neroai3-test-"));
  t.after(() => fs.rmSync(folder, { recursive: true, force: true }));
  const original = fs.promises.appendFile;
  let busy = 2;
  fs.promises.appendFile = async (...args) => {
    if (busy-- > 0) throw Object.assign(new Error("locked"), { code: "EBUSY" });
    return original.apply(fs.promises, args);
  };
  t.after(() => { fs.promises.appendFile = original; });
  const file = path.join(folder, "NeroAI4_in.ini");
  await appendEntry(file, "NeroAI4_in", "n3_locked", ["response", ["ok", "n3_locked", "Принял.", []]]);
  assert.equal(busy, -1);
  assert.deepEqual(parseIniEntries(fs.readFileSync(file, "utf8"), "NeroAI4_in").get("n3_locked")[1][1], "n3_locked");
});

test("shipped bridge accepts every snapshot the SQF byte limit lets through", () => {
  // SQF caps snapshots in UTF-8 bytes; the bridge counts UTF-16 chars, so
  // chars <= bytes and the bridge limit must be at least the SQF byte limit.
  const root = path.join(__dirname, "..");
  const shipped = JSON.parse(fs.readFileSync(path.join(root, "bridge", "neroai3.config.json"), "utf8"));
  const preInit = fs.readFileSync(path.join(root, "addons", "NeroAI3", "functions", "bootstrap", "fn_preInit.sqf"), "utf8");
  const sqfBytes = Number(/NeroAI_maxSnapshotBytes\s*=\s*(\d+)/.exec(preInit)[1]);
  assert.ok(shipped.limits.maxSnapshotChars >= sqfBytes, `bridge ${shipped.limits.maxSnapshotChars} < SQF ${sqfBytes}`);
  const ascii = '["v",3,"order","' + "a".repeat(sqfBytes - 18) + '"]';
  assert.equal(Buffer.byteLength(ascii), sqfBytes);
  assert.ok(validateRequest("n3_max", ["request", [3, "n3_max", "AUTONOMY", ["g"], ascii, "AUTONOMY"]], shipped));
});

test("autonomous plan keeps natural radio speech, drops a self-move and rejects invented coordinates", async t => {
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), "neroai3-test-"));
  t.after(() => fs.rmSync(folder, { recursive: true, force: true }));
  const bridge = createBridge({
    config: config(folder),
    completion: async () => JSON.stringify({
      version: 3,
      speech: "Контакт впереди. Обходим справа, затем продолжаем к цели.",
      actions: [
        { type: "RECON" },
        { type: "ADVANCE", position: [120, 340] },
        { type: "REQUEST_FIRE", position: [9000, 9000], support: "MORTAR" }
      ]
    })
  });
  await bridge.processRequest({
    id: "n3_auto",
    channel: "AUTONOMY",
    origin: "AUTONOMY",
    targetIds: ["group-id"],
    snapshot: '["v",3,"observer",[120,340],"groups",[["Альфа 1-2","VANILLA",[120,340]]]]'
  });
  const response = parseIniEntries(fs.readFileSync(path.join(folder, "NeroAI4_in.ini"), "utf8"), "NeroAI4_in").get("n3_auto");
  assert.equal(response[1][2], "Контакт впереди. Обходим справа, затем продолжаем к цели.");
  /* ADVANCE onto the group's own coordinate and the far REQUEST_FIRE are both removed. */
  assert.deepEqual(response[1][3], [["RECON", [], ""]]);
});

test("autonomous plan keeps a grounded march that actually displaces the group", async t => {
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), "neroai3-test-"));
  t.after(() => fs.rmSync(folder, { recursive: true, force: true }));
  const bridge = createBridge({
    config: config(folder),
    completion: async () => JSON.stringify({
      version: 3,
      speech: "Выдвигаемся к контакту.",
      actions: [{ type: "ADVANCE", position: [400, 340] }]
    })
  });
  await bridge.processRequest({
    id: "n3_auto_move",
    channel: "AUTONOMY",
    origin: "AUTONOMY",
    targetIds: ["group-id"],
    snapshot: '["v",3,"observer",[120,340],"groups",[["Альфа 1-2","VANILLA",[120,340],6,6,0,0,[["Enemy",[400,340],120]],90]]]'
  });
  const response = parseIniEntries(fs.readFileSync(path.join(folder, "NeroAI4_in.ini"), "utf8"), "NeroAI4_in").get("n3_auto_move");
  assert.deepEqual(response[1][3], [["ADVANCE", [400, 340], ""]]);
});

test("4.6.0: outbox entries that predate the bridge start are skipped without an LLM call, a reply, or a write to Arma's outbox", async t => {
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), "neroai3-test-"));
  t.after(() => fs.rmSync(folder, { recursive: true, force: true }));
  const cfg = config(folder);
  const stale = "[NeroAI4_out]\r\nn3_old_1 = [\"request\",[3,\"n3_old_1\",\"AUTONOMY\",[\"g1\"],\"[\"\"v\"\",3]\"]]\r\nn3_old_2 = [\"request\",[3,\"n3_old_2\",\"SIDE\",[\"g1\"],\"[\"\"v\"\",3]\"]]\r\n";
  const outboxPath = path.join(folder, "NeroAI4_out.ini");
  fs.writeFileSync(outboxPath, stale, "utf8");
  let calls = 0;
  const logged = [];
  const bridge = createBridge({ config: cfg, log: (...a) => logged.push(a.join(" ")), completion: async () => { calls++; return JSON.stringify({ version: 3, speech: "x", actions: [] }); } });
  assert.equal(await bridge.skipStaleOutbox(), 2);
  assert.equal(await bridge.pollOnce(), 0, "nothing from before the start is processed");
  assert.equal(calls, 0);
  assert.ok(!fs.existsSync(path.join(folder, "NeroAI4_in.ini")), "no reply written for stale requests");
  assert.equal(fs.readFileSync(outboxPath, "utf8"), stale, "Arma's outbox is never written by the bridge");
  assert.ok(logged.some(l => /Stale outbox skipped 2/.test(l)));
  /* a request that arrives after the start is processed normally */
  fs.appendFileSync(outboxPath, "n3_new_1 = [\"request\",[3,\"n3_new_1\",\"AUTONOMY\",[\"g1\"],\"[\"\"v\"\",3]\"]]\r\n", "utf8");
  assert.equal(await bridge.pollOnce(), 1);
  await new Promise(r => setTimeout(r, 50));
  assert.equal(calls, 1);
  const bridgeServer = fs.readFileSync(path.join(__dirname, "..", "bridge", "server.js"), "utf8");
  assert.match(bridgeServer, /await bridge\.skipStaleOutbox\(\);\s*let polling = false;/);
});
