"use strict";
// Live 7.10: buying RHS infantry said "Категория покупки не готова" — RHS units
// have no editorPreview, and splitString "|" drops the empty field, so the
// category slid out of index 5.
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const root = path.join(__dirname, "..");
const read = file => fs.readFileSync(path.join(root, file), "latin1");

test("purchase list never stores an empty field, so the category stays at index 5", () => {
  const { adapt } = require("../tools/adapt-purchase-items");
  const generated = read("addons/NeroAI3/functions/native/fn_WLSubroutine_purchaseMenuSetItemsList.sqf");
  assert.equal(adapt(read("research/native/Warlords/fn_WLSubroutine_purchaseMenuSetItemsList.sqf")), generated);
  assert(generated.includes('[4, "\\A3\\Data_F_Warlords\\Data\\preview_empty.jpg"]'));
  assert.doesNotMatch(generated, /format \["%1\|%2\|%3\|%4\|%5\|%6", _x # 0/);
  assert(read("addons/NeroAI3/functions/CfgFunctions.hpp").includes('class WLSubroutine_purchaseMenuSetItemsList {file="\\NeroWL\\functions\\native\\fn_WLSubroutine_purchaseMenuSetItemsList.sqf";};'));
  assert.match(fs.readFileSync(path.join(root, "tools/build-australia-mission.js"), "utf8"), /require\("\.\/adapt-purchase-items"\)\.write\(root\);/);
});

test("availability falls back to the player's catalog row for the category", () => {
  const { adapt } = require("../tools/adapt-purchase-availability");
  const utf = file => fs.readFileSync(path.join(root, file), "utf8");
  const generated = utf("addons/NeroAI3/functions/native/fn_WLSubroutine_purchaseMenuAssetAvailability.sqf");
  assert.equal(adapt(utf("research/native/Warlords/fn_WLSubroutine_purchaseMenuAssetAvailability.sqf")), generated);
  assert.match(generated, /forEach \(player getVariable \["BIS_WL_purchasable",\[\]\]\)/);
});

// Mirrors SQF splitString: empty segments vanish.
test("model of the bug: an empty preview shifts the category, the stand-in keeps it", () => {
  const split = s => s.split("|").filter(Boolean);
  const row = ["rhsusf_army_ocp_rifleman", 60, [], "Rifleman", "", " ", "Infantry"];
  const data = r => `${r[0]}|[]|${r[3]}|${r[4]}|${r[5]}|${r[6]}`;
  assert.notEqual(split(data(row))[5], "Infantry");
  const fixed = [...row]; fixed[4] = "\\A3\\Data_F_Warlords\\Data\\preview_empty.jpg";
  assert.equal(split(data(fixed))[5], "Infantry");
});
