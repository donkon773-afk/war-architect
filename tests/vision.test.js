"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { validateVisionResponse, buildVisionPayload } = require("../bridge/vision");

test("vision accepts bounded evidence observations and normalizes boxes", () => {
  const result = validateVisionResponse(JSON.stringify({
    version: 1,
    summary: "Two vehicles near a barrier.",
    observations: [
      { type: "collision_risk", confidence: 0.88, bbox: [10.2, 20.4, 400.8, 500.1], evidence: "Vehicles overlap near the road barrier." },
      { type: "enemy_visible", confidence: 0.2, bbox: [1, 1, 10, 10], evidence: "uncertain" }
    ]
  }), { minConfidence: 0.65, maxObservations: 12, maxEvidenceChars: 160 });
  assert.equal(result.observations.length, 1);
  assert.deepEqual(result.observations[0].bbox, [10, 20, 401, 500]);
  assert.equal(result.observations[0].type, "COLLISION_RISK");
});

test("vision rejects any model attempt to return executable actions", () => {
  assert.throws(() => validateVisionResponse(JSON.stringify({ version: 1, summary: "", observations: [], actions: [{ type: "MOVE" }] })), /executable directive/);
});

test("vision rejects markdown and malformed boxes", () => {
  assert.throws(() => validateVisionResponse("```json\n{}\n```"), /raw JSON/);
  const result = validateVisionResponse(JSON.stringify({ version: 1, observations: [{ type: "STUCK_UNIT", confidence: 0.9, bbox: [5, 5, 4, 4], evidence: "bad" }] }));
  assert.deepEqual(result.observations, []);
});

test("vision payload sends a local image data URL without game commands", () => {
  const payload = buildVisionPayload({ lmStudio: { model: "text-test" }, vision: { model: "vision-test", maxTokens: 500 } }, "data:image/jpeg;base64,AA==", "single frame");
  assert.equal(payload.model, "vision-test");
  assert.equal(payload.messages[1].content[1].type, "image_url");
  assert.match(payload.messages[0].content, /Never return commands/);
  assert.equal(payload.max_tokens, 500);
});

test("Arma vision capture is opt-in, rate-limited, and registered in CfgFunctions", () => {
  const root = path.resolve(__dirname, "..");
  const capture = fs.readFileSync(path.join(root, "addons", "NeroAI3", "functions", "communication", "fn_visionCaptureLoop.sqf"), "utf8");
  const config = fs.readFileSync(path.join(root, "addons", "NeroAI3", "functions", "CfgFunctions.hpp"), "utf8");
  assert.match(config, /class visionCaptureLoop/);
  assert.match(capture, /NeroAI_visionCaptureEnabled/);
  assert.match(capture, /max 10/);
  assert.match(capture, /screenshot "NeroAI_vision\.png"/);
  assert.doesNotMatch(capture, /remoteExec|compile|execVM/);
});
