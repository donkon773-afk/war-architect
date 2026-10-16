"use strict";

const fs = require("node:fs");
const { requestJson, isReasoningModel, isOpenAiEndpoint } = require("./lm-studio");

const OBSERVATION_TYPES = new Set([
  "STUCK_UNIT",
  "STUCK_VEHICLE",
  "COLLISION_RISK",
  "FORMATION_BROKEN",
  "ENEMY_VISIBLE",
  "FRIENDLY_VISIBLE",
  "EMPTY_VEHICLE_VISIBLE",
  "OBSTACLE_VISIBLE",
  /* 4.2.0: descriptive localisation cues so the commander's-eye frame helps the
   * group place itself on the terrain. Still no map coordinates or allegiance. */
  "LANDMARK_VISIBLE",
  "COMPOUND_VISIBLE",
  "RIDGE_VISIBLE",
  "ROAD_VISIBLE",
  "OPEN_GROUND",
  "SMOKE_VISIBLE",
  "FIRE_VISIBLE",
  "UNKNOWN"
]);

function boundedText(value, limit) {
  return String(value ?? "").replace(/[\u0000-\u001f\u007f]/g, " ").replace(/\s+/g, " ").trim().slice(0, limit);
}

function validBox(value) {
  if (!Array.isArray(value) || value.length !== 4) return null;
  const box = value.map(Number);
  if (box.some(number => !Number.isFinite(number) || number < 0 || number > 1000)) return null;
  const rounded = box.map(Math.round);
  if (rounded[2] <= rounded[0] || rounded[3] <= rounded[1]) return null;
  return rounded;
}

function validateVisionResponse(raw, limits = {}) {
  if (typeof raw !== "string" || !raw.trim() || raw.includes("```")) throw new Error("Vision model did not return one raw JSON object");
  let parsed;
  try { parsed = JSON.parse(raw); } catch (_) { throw new Error("Vision model returned invalid JSON"); }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed) || Number(parsed.version) !== 1) throw new Error("Unsupported vision response schema");
  if ("action" in parsed || "actions" in parsed || "command" in parsed || "sqf" in parsed) throw new Error("Vision response attempted to include an executable directive");

  const maxObservations = Math.max(1, Math.min(24, Number(limits.maxObservations) || 12));
  const minConfidence = Math.max(0, Math.min(1, Number(limits.minConfidence) || 0.65));
  const maxEvidenceChars = Math.max(40, Math.min(300, Number(limits.maxEvidenceChars) || 160));
  const output = { version: 1, summary: boundedText(parsed.summary, 240), observations: [] };
  if (!Array.isArray(parsed.observations)) return output;

  for (const item of parsed.observations.slice(0, maxObservations)) {
    if (!item || typeof item !== "object" || Array.isArray(item)) continue;
    const type = String(item.type || "").toUpperCase();
    const confidence = Number(item.confidence);
    const bbox = validBox(item.bbox);
    if (!OBSERVATION_TYPES.has(type) || !Number.isFinite(confidence) || confidence < minConfidence || confidence > 1 || !bbox) continue;
    output.observations.push({
      type,
      confidence: Math.round(confidence * 1000) / 1000,
      bbox,
      evidence: boundedText(item.evidence, maxEvidenceChars)
    });
  }
  return output;
}

function buildVisionPayload(config, dataUrl, frameContext = "") {
  const vision = config.vision || {};
  const payload = {
    model: vision.model || config.lmStudio.model,
    messages: [
      {
        role: "system",
        content: [
          "You are the read-only visual observer for NeroAI in Arma 3.",
          "Analyze only what is visibly supported by this single frame.",
          "Do not infer units outside the camera, map coordinates, identities, allegiance, intent, or motion from one image unless visually explicit.",
          "Never return commands, actions, SQF, scripts, paths, or tactical orders.",
          "Return exactly one raw JSON object with schema: {\"version\":1,\"summary\":string,\"observations\":[{\"type\":string,\"confidence\":number,\"bbox\":[x1,y1,x2,y2],\"evidence\":string}]}.",
          "Bounding boxes use integer coordinates normalized from 0 to 1000.",
          "Allowed types: STUCK_UNIT, STUCK_VEHICLE, COLLISION_RISK, FORMATION_BROKEN, ENEMY_VISIBLE, FRIENDLY_VISIBLE, EMPTY_VEHICLE_VISIBLE, OBSTACLE_VISIBLE, LANDMARK_VISIBLE, COMPOUND_VISIBLE, RIDGE_VISIBLE, ROAD_VISIBLE, OPEN_GROUND, SMOKE_VISIBLE, FIRE_VISIBLE, UNKNOWN.",
          "summary: one short sentence describing the terrain and what the squad is looking at, to help it place itself (e.g. 'edge of a walled compound with an orchard to the left and a dirt road ahead').",
          "A still image cannot prove that something is stuck. Use STUCK_UNIT or STUCK_VEHICLE only when the supplied temporal context says the same tracked object remained stationary across multiple frames.",
          "Prefer an empty observations array over speculation. Keep evidence short and concrete."
        ].join(" ")
      },
      {
        role: "user",
        content: [
          { type: "text", text: `FRAME_CONTEXT=${boundedText(frameContext, 800) || "single uncorrelated frame"}` },
          { type: "image_url", image_url: { url: dataUrl } }
        ]
      }
    ],
    stream: false
  };
  const cap = Math.max(128, Math.min(1200, Number(vision.maxTokens) || 700));
  if (isReasoningModel(payload.model)) {
    payload.max_completion_tokens = cap;
    payload.reasoning_effort = "minimal";
  } else if (isOpenAiEndpoint({ baseUrl: vision.baseUrl || (config.lmStudio || {}).baseUrl })) {
    /* live 14.09: gpt-4o-mini answered HTTP 400 "Unrecognized request argument
     * supplied: reasoning_effort" on every frame — a plain chat model gets no
     * reasoning field at all. */
    payload.max_tokens = cap;
    payload.temperature = 0.1;
    /* live 14.09 22:17: gpt-4o-mini wrapped every answer in a ```json fence and
     * 27/27 frames were rejected — JSON mode makes the reply one raw object. */
    payload.response_format = { type: "json_object" };
  } else {
    /* 4.6.0 local VLM (LM Studio, qwen3-vl): the grammar-backed json_schema is
     * what LM Studio enforces reliably (json_object is not a grammar there),
     * and a Qwen3 family model must be told not to think or it spends the whole
     * budget in reasoning_content — same lever as the planner. */
    payload.max_tokens = cap;
    payload.temperature = 0.1;
    payload.reasoning_effort = typeof vision.reasoningEffort === "string" && vision.reasoningEffort.trim() ? vision.reasoningEffort.trim() : "none";
    payload.response_format = { type: "json_schema", json_schema: buildVisionSchema() };
  }
  return payload;
}

/* Strict schema mirroring validateVisionResponse; bbox bounds and the type
 * allowlist are still re-checked downstream so a lax backend cannot slip past. */
function buildVisionSchema() {
  return {
    name: "neroai_vision",
    strict: true,
    schema: {
      type: "object",
      additionalProperties: false,
      required: ["version", "summary", "observations"],
      properties: {
        version: { type: "integer", enum: [1] },
        summary: { type: "string" },
        observations: {
          type: "array",
          maxItems: 12,
          items: {
            type: "object",
            additionalProperties: false,
            required: ["type", "confidence", "bbox", "evidence"],
            properties: {
              type: { type: "string", enum: [...OBSERVATION_TYPES] },
              confidence: { type: "number" },
              bbox: { type: "array", items: { type: "integer" }, minItems: 4, maxItems: 4 },
              evidence: { type: "string" }
            }
          }
        }
      }
    }
  };
}

/* Compact, SQF-serialisable form of a vision result for the tactical snapshot:
 * [summary, [[type, confidencePercent, x1, y1, x2, y2, evidence], ...]]. */
function foldObservations(result) {
  const summary = boundedText(result && result.summary, 240);
  const rows = ((result && result.observations) || []).slice(0, 8).map(observation => [
    String(observation.type || "UNKNOWN"),
    Math.round((Number(observation.confidence) || 0) * 100),
    ...(Array.isArray(observation.bbox) ? observation.bbox.slice(0, 4).map(Number) : [0, 0, 0, 0]),
    boundedText(observation.evidence, 120)
  ]);
  return [summary, rows];
}

async function analyzeFrame(config, imagePath, frameContext = "", debugLog = () => {}) {
  const vision = config.vision || {};
  const bytes = await fs.promises.readFile(imagePath);
  const maxBytes = Math.max(131072, Number(vision.maxImageBytes) || 4194304);
  if (bytes.length > maxBytes) throw new Error(`Prepared vision frame is too large: ${bytes.length} > ${maxBytes}`);
  const extension = imagePath.toLowerCase().endsWith(".png") ? "png" : "jpeg";
  const payload = buildVisionPayload(config, `data:image/${extension};base64,${bytes.toString("base64")}`, frameContext);
  const endpoint = `${String(vision.baseUrl || config.lmStudio.baseUrl).replace(/\/+$/, "")}/chat/completions`;
  debugLog("Vision LM Studio request", `imageBytes=${bytes.length}; model=${payload.model}`);
  const response = await requestJson(endpoint, { Authorization: `Bearer ${vision.apiKey || config.lmStudio.apiKey || "lm-studio"}` }, payload, Number(vision.timeoutMs) || 60000);
  const content = response?.choices?.[0]?.message?.content;
  if (typeof content !== "string" || !content.trim()) throw new Error("Vision model returned no final message.content");
  debugLog("Vision LM Studio raw response", JSON.stringify(response));
  return validateVisionResponse(content.trim(), vision);
}

module.exports = { OBSERVATION_TYPES, validBox, validateVisionResponse, buildVisionPayload, buildVisionSchema, foldObservations, analyzeFrame };
