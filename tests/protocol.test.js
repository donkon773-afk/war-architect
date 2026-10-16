"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { validateModelResponse, parseJsonObject, explicitOrderIntent, explicitOrderIntents, bindExplicitOrder, isGroundedPosition, parseOrderPosition, inferIntentPositions, classifyPlayerMessage, autonomousMoveIsMeaningful } = require("../bridge/protocol");

test("accepts bounded NeroAI macro actions", () => {
  const result = validateModelResponse(JSON.stringify({
    version: 3,
    speech: "Браво, выдвигаемся к посадке.",
    actions: [
      { type: "advance", position: [4319.4, 7655.9] },
      { type: "set_roe", roe: "return_fire" }
    ]
  }));
  assert.equal(result.ok, true);
  assert.deepEqual(result.actions, [["ADVANCE", [4319, 7656], ""], ["SET_ROE", [], "RETURN_FIRE"]]);
});

test("drops unsafe, unknown, and ungrounded actions", () => {
  const result = validateModelResponse(JSON.stringify({
    version: 3,
    speech: "Держим позицию.",
    actions: [
      { type: "SQF", command: "player setDamage 1" },
      { type: "ADVANCE", position: [-1, 20] },
      { type: "REQUEST_FIRE", position: [300, 400], support: "NUKE" },
      { type: "HOLD" }
    ]
  }));
  assert.equal(result.ok, true);
  assert.deepEqual(result.actions, [["HOLD", [], ""]]);
});

test("rejects malformed final model output and thought-only output", () => {
  assert.equal(validateModelResponse("<think>long private reasoning</think>").ok, false);
  assert.equal(validateModelResponse('{"version":2,"speech":"old"}').ok, false);
  assert.equal(parseJsonObject("```json\n{\"version\":3}\n``` ").version, 3);
});

test("never allows code-like speech through the protocol", () => {
  const result = validateModelResponse(JSON.stringify({
    version: 3,
    speech: "call compile something",
    actions: []
  }));
  assert.equal(result.speech, "Вас понял. Исполняю безопасный манёвр.");
});

test("binds explicit Russian player imperatives ahead of an unrelated model plan", () => {
  const board = explicitOrderIntent('["v",3,"order","Альфа 1-2 займите танки на взлетной полосе"]');
  assert.deepEqual(board, { type: "BOARD" });
  assert.deepEqual(bindExplicitOrder([["ADVANCE", [100, 200], ""]], board), {
    actions: [["BOARD", [], ""]], unresolved: false
  });

  const roe = explicitOrderIntent('["v",3,"order","Альфа 1-2 не открывать огонь"]');
  assert.deepEqual(bindExplicitOrder([], roe), {
    actions: [["SET_ROE", [], "HOLD_FIRE"]], unresolved: false
  });
});

test("never invents a coordinate for an explicit spatial order; a vague assault becomes recon, not silence", () => {
  const assault = explicitOrderIntent('["v",3,"order","Альфа 1-2 начать штурм"]');
  /* 4.4.0: no target anywhere → RECON rather than an empty plan and a canned apology */
  assert.deepEqual(bindExplicitOrder([], assault), { actions: [["RECON", [], ""]], unresolved: false });
  const advance = explicitOrderIntent('["v",3,"order","Альфа 1-2 выдвигайтесь"]');
  assert.deepEqual(bindExplicitOrder([], advance), { actions: [], unresolved: true });
  assert.deepEqual(bindExplicitOrder([["ASSAULT", [4319, 7656], ""]], assault), {
    actions: [["ASSAULT", [4319, 7656], ""]], unresolved: false
  });
});

test("distinguishes fire support, group support, and an observed sector", () => {
  assert.deepEqual(
    explicitOrderIntent('["v",3,"order","Альфа 1-2 запросите артиллерийскую поддержку по координатам 4319,7656"]'),
    { type: "REQUEST_FIRE", position: [4319, 7656], argument: "ARTILLERY" }
  );
  assert.deepEqual(
    explicitOrderIntent('["v",3,"order","Альфа 1-2 запросите подмогу"]'),
    { type: "REQUEST_SUPPORT", position: null }
  );
  assert.deepEqual(
    explicitOrderIntent('["v",3,"order","Альфа 1-2 наблюдайте сектор 4319,7656"]'),
    { type: "SET_SECTOR", position: [4319, 7656] }
  );
  assert.deepEqual(
    explicitOrderIntent('["v",3,"order","Альфа 1-2 подсветите лазером цель 4319,7656"]'),
    { type: "DESIGNATE", position: [4319, 7656] }
  );
});

test("keeps literal direction relative to each addressed group", () => {
  const intent = explicitOrderIntent('["v",3,"order","Альфа 1-2 идите на север на 500 метров"]');
  assert.deepEqual(intent, {
    type: "ADVANCE",
    position: null,
    relative: { mode: "DIR", bearing: 0, distance: 500 }
  });
  assert.deepEqual(bindExplicitOrder([], intent), {
    actions: [["ADVANCE", [], "DIR:0:500"]],
    unresolved: false
  });
});

test("preserves up to three explicit clauses instead of discarding a compound order", () => {
  const intents = explicitOrderIntents('["v",3,"order","Альфа 1-2 займите БТР и выдвигайтесь к 4319,7656 и огонь не открывать"]');
  assert.deepEqual(bindExplicitOrder([], intents), {
    actions: [
      ["BOARD", [], ""],
      ["ADVANCE", [4319, 7656], ""],
      ["SET_ROE", [], "HOLD_FIRE"]
    ],
    unresolved: false
  });

  const commaSeparated = explicitOrderIntents('["v",3,"order","всем группам выдвигаться на север на 10 метров, в бой не вступать"]');
  assert.deepEqual(bindExplicitOrder([], commaSeparated), {
    actions: [
      ["ADVANCE", [], "DIR:0:10"],
      ["SET_ROE", [], "HOLD_FIRE"]
    ],
    unresolved: false
  });
});

test("an autonomous march must displace the group, not point at its own position", () => {
  const snapshot = '["v",3,"observer",[4000,5000],"groups",[["Альфа","VANILLA",[4000,5000],8,8,0,0,[],90]]]';
  assert.equal(autonomousMoveIsMeaningful("ADVANCE", [4005, 5000], snapshot), false);
  assert.equal(autonomousMoveIsMeaningful("ADVANCE", [4200, 5000], snapshot), true);
  assert.equal(autonomousMoveIsMeaningful("ASSAULT", [4000, 5000], snapshot), false);
  assert.equal(autonomousMoveIsMeaningful("ADVANCE", [4020, 5000], snapshot, 5), true);
  /* Non-move spatial actions may legitimately reference the group's own grid. */
  assert.equal(autonomousMoveIsMeaningful("SET_SECTOR", [4000, 5000], snapshot), true);
  assert.equal(autonomousMoveIsMeaningful("REPORT", [], snapshot), true);
  /* With no derivable group origin the guard must not over-block. */
  assert.equal(autonomousMoveIsMeaningful("ADVANCE", [4000, 5000], '["v",3]'), true);
  assert.equal(autonomousMoveIsMeaningful("ADVANCE", "bad", snapshot), false);
});

test("accepts only model-derived coordinates grounded near snapshot facts", () => {
  const snapshot = '["v",3,"groups",[["Альфа","INFANTRY",[4000,5000],8,0,[],0]],"order","атакуйте обнаруженную цель"]';
  assert.equal(isGroundedPosition([4120, 5100], snapshot), true);
  assert.equal(isGroundedPosition([9000, 9000], snapshot), false);
  const intent = explicitOrderIntent(snapshot);
  /* an ungrounded model coordinate is still refused; the order degrades to recon */
  assert.deepEqual(bindExplicitOrder([["ASSAULT", [9000, 9000], ""]], intent, snapshot), {
    actions: [["RECON", [], ""]],
    unresolved: false
  });
});

test("decodes common space-separated Arma grids without breaking world coordinates", () => {
  assert.deepEqual(parseOrderPosition("атакуйте сектор 057 090"), [5700, 9000]);
  assert.deepEqual(parseOrderPosition("наблюдайте квадрат 54 93"), [5400, 9300]);
  assert.deepEqual(parseOrderPosition("выдвигайтесь к 4319,7656"), [4319, 7656]);
  assert.deepEqual(
    explicitOrderIntent('["v",3,"order","Альфа 1-5 атакуйте цель по координатам 057 090"]'),
    { type: "ASSAULT", position: [5700, 9000] }
  );
});

test("grounds approximate goals in observed vehicles, locations, and enemy intel", () => {
  const snapshot = '["v",3,"player",[5969,11843],"groups",[["Альфа 1-3","MECHANIZED",[5726,10535],20,0,[["CUP_O_T72",[5750,9000],35,"2:1"]],180]],"locations",[["Бастам","NameCity",[5990,8977]]],"assets",[["CUP_B_M1126_ICV_M2_Woodland","APC",[5962,11834],0,9,0,100,false]],"sharedIntel",[],"order","Альфа 1-3 займите М11126 на базе"]';
  assert.deepEqual(inferIntentPositions(explicitOrderIntents(snapshot), snapshot), [
    { type: "BOARD", position: [5962, 11834] }
  ]);

  const city = snapshot.replace("займите М11126 на базе", "выдвигайтесь к городу Бастам");
  assert.deepEqual(inferIntentPositions(explicitOrderIntents(city), city), [
    { type: "ADVANCE", position: [5990, 8977] }
  ]);

  const enemy = snapshot.replace("займите М11126 на базе", "атакуйте обнаруженного противника");
  assert.deepEqual(inferIntentPositions(explicitOrderIntents(enemy), enemy), [
    { type: "ASSAULT", position: [5750, 9000] }
  ]);

  /* 4.4.0: with nothing to attack the intent is left OPEN so bindExplicitOrder
   * can adopt the model's own grounded plan first (it used to be downgraded to
   * RECON here, before the model's answer was even considered) */
  const noEnemy = '["v",3,"groups",[["Альфа 1-5","ARMORED",[5900,11800],9,0,[],0]],"sharedIntel",[],"order","Альфа 1-5 атакуйте противника"]';
  assert.deepEqual(inferIntentPositions(explicitOrderIntents(noEnemy), noEnemy), [{ type: "ASSAULT", position: null }]);
  /* Warlords sectors are a target source: a named sector, or the nearest sector we do not hold */
  const sectors = '["v",3,"side","BLUE","groups",[["Альфа 1-5","ARMORED",[5900,11800],9,0,[],0]],"sectors",[["Nur",[8930,4380],"NONE",7800,false],["Base",[5937,11868],"BLUE",70,true]],"order","Альфа 1-5 атакуйте сектор"]';
  assert.deepEqual(inferIntentPositions(explicitOrderIntents(sectors), sectors), [{ type: "ASSAULT", position: [8930, 4380] }]);
  const named = sectors.replace("атакуйте сектор", "выдвигайтесь на Nur");
  assert.deepEqual(inferIntentPositions(explicitOrderIntents(named), named), [{ type: "ADVANCE", position: [8930, 4380] }]);
});

test("separates questions and information from orders and supports explicit autonomy", () => {
  assert.equal(classifyPlayerMessage('["v",3,"order","Альфа 1-4 куда вы выдвигаетесь?"]').kind, "QUESTION");
  assert.equal(classifyPlayerMessage('["v",3,"order","Альфа 1-4 взлетает наш беспилотник"]').kind, "INFORMATION");
  assert.equal(classifyPlayerMessage('["v",3,"order","Альфа 1-4 выдвигайтесь к городу"]').kind, "ORDER");
  assert.deepEqual(
    explicitOrderIntent('["v",3,"order","Альфа 1-4 действуйте самостоятельно по обстановке"]'),
    { type: "AUTONOMY" }
  );
  assert.deepEqual(
    explicitOrderIntent('["v",3,"order","Альфа 1-4 разберитесь с угрозой"]'),
    { type: "AUTONOMY" }
  );
});

test("4.5.0 BUY: the model spends the group's CP through the strict schema, and player purchase orders map to a kind", () => {
  const { validateModelResponse, explicitOrderIntent, bindExplicitOrder } = require("../bridge/protocol");
  const ok = validateModelResponse(JSON.stringify({ version: 3, speech: "Заказываю танк.", actions: [{ type: "BUY", position: [], roe: "", support: "TANK" }] }), { maxActions: 5, maxSpeechChars: 700 });
  assert.ok(ok.ok);
  assert.deepEqual(ok.actions[0], ["BUY", [], "TANK"]);
  /* an unknown kind is dropped, not passed to the engine */
  const bad = validateModelResponse(JSON.stringify({ version: 3, speech: "x", actions: [{ type: "BUY", position: [], roe: "", support: "NUKE" }] }), { maxActions: 5, maxSpeechChars: 700 });
  assert.equal(bad.actions.length, 0);
  /* default kind is armour */
  const dflt = validateModelResponse(JSON.stringify({ version: 3, speech: "x", actions: [{ type: "BUY", position: [], roe: "", support: "" }] }), { maxActions: 5, maxSpeechChars: 700 });
  assert.deepEqual(dflt.actions[0], ["BUY", [], "TANK"]);
  /* player orders */
  assert.deepEqual(explicitOrderIntent('["v",3,"order","Альфа-1, купите танк"]'), { type: "BUY", argument: "TANK" });
  assert.deepEqual(explicitOrderIntent('["v",3,"order","Альфа-1 закажите БТР"]'), { type: "BUY", argument: "APC" });
  assert.deepEqual(explicitOrderIntent('["v",3,"order","Альфа-1 закажите пополнение, двух бойцов"]'), { type: "BUY", argument: "INFANTRY" });
  assert.deepEqual(explicitOrderIntent('["v",3,"order","Альфа-1 запросите по реквизиции грузовик"]'), { type: "BUY", argument: "TRUCK" });
  const bound = bindExplicitOrder([], { type: "BUY", argument: "APC" }, '["v",3]');
  assert.deepEqual(bound, { actions: [["BUY", [], "APC"]], unresolved: false });
  /* "займите БТР" is still boarding, not buying */
  assert.equal(explicitOrderIntent('["v",3,"order","Альфа-1 займите БТР"]').type, "BOARD");
});
