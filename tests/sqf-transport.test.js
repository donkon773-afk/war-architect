"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { toSqfValue, parseSqfValue, parseIniEntries } = require("../bridge/protocol");

test("SQF transport serializer round-trips controlled nested values", () => {
  const source = ["response", ["ok", "n3_10_2", "Командир сказал \"вижу\".", [["ADVANCE", [100, 200], ""]]]];
  const encoded = toSqfValue(source);
  assert.deepEqual(parseSqfValue(encoded), source);
});

test("INI reader keeps only a requested database section", () => {
  const ini = [
    "[Other]",
    "ignored = [\"response\",[\"ok\"]]",
    "[NeroAI4_out]",
    "n3_1 = [\"request\",[3,\"n3_1\",\"SIDE\",[\"group-id\"],\"snapshot\"]]"
  ].join("\r\n");
  const entries = parseIniEntries(ini, "NeroAI4_out");
  assert.equal(entries.size, 1);
  assert.deepEqual(entries.get("n3_1").slice(0, 1), ["request"]);
});

test("INI reader accepts the outer wrapper observed in the live INIDBI2 outbox", () => {
  const ini = [
    "[NeroAI4_out]",
    'n3_live="["request",[3,"n3_live","SIDE",["2:443"],"[""v"",3,""ch"",""SIDE""]"]]"'
  ].join("\r\n");
  const entries = parseIniEntries(ini, "NeroAI4_out");
  assert.deepEqual(entries.get("n3_live"), ["request", [3, "n3_live", "SIDE", ["2:443"], '["v",3,"ch","SIDE"]']]);
});

test("INI reader accepts an INIDBI2 wrapper with every inner quote doubled", () => {
  const ini = [
    "[NeroAI4_out]",
    'n3_escaped="[""request"",[3,""n3_escaped"",""SIDE"",[""1:2""],""snapshot""]]"'
  ].join("\r\n");
  const entries = parseIniEntries(ini, "NeroAI4_out");
  assert.deepEqual(entries.get("n3_escaped"), ["request", [3, "n3_escaped", "SIDE", ["1:2"], "snapshot"]]);
});
