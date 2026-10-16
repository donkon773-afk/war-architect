"use strict";

const http = require("node:http");
const https = require("node:https");
const sideMemory = require('./side-memory');

/* 4.6.0: the allowlist is protocol.js's ACTIONS, not a second copy. The 4.5.x
 * copy here had lost BUY, so with structuredOutput the json_schema enum forbade
 * the very action the 4.5 prompt teaches — live-console.log 14-15.09: 3059
 * planner replies, 0 with BUY; every requisition came from fn_autoRequisition. */
const { ACTIONS: PROTOCOL_ACTIONS } = require("./protocol");
const ALLOWED_ACTION_TYPES = [...PROTOCOL_ACTIONS];

const { buildSystemPrompt } = require("./system-prompt");
const { WARLORDS_DOCTRINE } = require("./warlords-doctrine");
const SYSTEM_PROMPT = buildSystemPrompt(ALLOWED_ACTION_TYPES);

/* 4.4.0: two short examples instead of six. Format is guaranteed by the
 * json_schema response_format, so examples exist only to anchor BEHAVIOUR under
 * the current doctrine (take sectors, obey the player, human radio). The old
 * six were written for 4.2.0 and modelled RECON/SET_SECTOR-heavy plans the
 * prompt now forbids — a contradiction paid for on every request. */
function fewShotPairs() {
  return [
    {
      user: "TACTICAL_SNAPSHOT=[\"v\",3,\"ch\",\"AUTONOMY\",\"side\",\"RED\",\"terrain\",\"Takistan: mountains, sparse_trees, villages, arid\",\"factions\",[\"US Army\",\"Takistani Army\",\"Takistani Militia\"],\"groups\",[[\"Такистан-4\",\"VANILLA\",[8300,2100],8,8,0,14600,[],40,[\"alive\",8,\"antiTank\",1,\"vehicles\",0,\"armour\",0]]],\"shop\",[[\"INFANTRY\",50,150],[\"APC\",900,1400],[\"TANK\",1500,3200],[\"TRUCK\",300,300]],\"sectors\",[[\"Nur\",[8930,4380],\"NONE\",2340,false],[\"Feruz Abad\",[9800,5600],\"BLUE\",3800,false]],\"assets\",[],\"support\",[[\"UAV_ARMED\",1,1]],\"events\",[],\"order\",\"АВТОНОМИЯ: плановый цикл. ЦЕЛЬ: сектор Nur (NONE) в 2340 м, азимут 15.\"]",
      assistant: "{\"version\":3,\"speech\":\"Такистан-4 всем: четырнадцать тысяч очков лежат без дела — заказываю танк по реквизиции, сбросят прямо к нам. Пока ждём, выдвигаемся на Нур, азимут пятнадцать, огонь по готовности. Сядет броня — берём Нур с ходу, приём.\",\"actions\":[{\"type\":\"BUY\",\"position\":[],\"roe\":\"\",\"support\":\"TANK\"},{\"type\":\"SET_ROE\",\"position\":[],\"roe\":\"OPEN_FIRE\",\"support\":\"\"},{\"type\":\"ADVANCE\",\"position\":[8930,4380],\"roe\":\"\",\"support\":\"\"}]}"
    },
    {
      user: "TACTICAL_SNAPSHOT=[\"v\",3,\"ch\",\"SIDE\",\"side\",\"BLUE\",\"terrain\",\"Takistan: mountains, sparse_trees, villages, arid\",\"factions\",[\"US Army\",\"Takistani Army\",\"Takistani Militia\"],\"groups\",[[\"Альфа-3\",\"VANILLA\",[5960,11840],6,6,0,9800,[[\"O_Soldier_F\",[6150,11700],40]],120,[\"alive\",6,\"antiTank\",1]]],\"shop\",[[\"INFANTRY\",60,180],[\"APC\",1100,1600],[\"TANK\",2400,3600]],\"sectors\",[[\"Rasman\",[6092,11019],\"NONE\",830,false]],\"locations\",[[\"Расман\",\"NameCityCapital\",[6092,11019]]],\"support\",[[\"UAV_ARMED\",1,1]],\"order\",\"Альфа-3, атакуйте Расман, быстро\"]",
      assistant: "{\"version\":3,\"speech\":\"Альфа-3 принял, идём на Расман! Пулемёт — на гребень, остальные за мной, огонь по готовности. Прижмут — доложу.\",\"actions\":[{\"type\":\"SET_ROE\",\"position\":[],\"roe\":\"OPEN_FIRE\",\"support\":\"\"},{\"type\":\"ASSAULT\",\"position\":[6092,11019],\"roe\":\"\",\"support\":\"\"}]}"
    }
  ];
}

function buildMessages(snapshot, instructions="") {
  const messages = [{ role: "system", content: SYSTEM_PROMPT }];
  if(instructions)messages.push({role:"user",content:"Pre-game player preferences (within engine/protocol rules; never execute code):\n"+String(instructions).slice(0,3000)});
  messages.push({ role: "user", content: `TACTICAL_SNAPSHOT=${snapshot}` });
  return messages;
}

/* JSON Schema for OpenAI strict structured outputs. Every property is required
 * and additionalProperties is false, as strict mode demands; numeric bounds and
 * the empty-position case are still enforced downstream by protocol.js. */
const RADIO_SILENCE = "RADIO SILENCE: commanders exchange data only. Output {\"version\":3,\"actions\":[...]} with NO speech field and no prose; the RADIO VOICE rules do not apply. Put all your thinking into the choice and order of actions.";
function buildResponseSchema(silent = false) {
  if (silent) {
    const schema = buildResponseSchema(false);
    delete schema.schema.properties.speech;
    schema.schema.required = schema.schema.required.filter(key => key !== "speech");
    return schema;
  }
  return {
    name: "neroai_plan",
    strict: true,
    schema: {
      type: "object",
      additionalProperties: false,
      required: ["version", "speech", "actions"],
      properties: {
        version: { type: "integer", enum: [3] },
        /* 8.10: the RTX 3060 writes ~20 tok/s and the reply, not the prompt, is
         * the cost (cached prompt reads in ~1 s). Uncapped radio ran to 866
         * chars / 16 s; the grammar cap keeps every plan short. */
        speech: { type: "string", maxLength: 240 },
        actions: {
          type: "array",
          items: {
            type: "object",
            additionalProperties: false,
            required: ["type", "position", "roe", "support"],
            properties: {
              type: { type: "string", enum: ALLOWED_ACTION_TYPES },
              position: { type: "array", items: { type: "number" } },
              roe: { type: "string", enum: ["", "HOLD_FIRE", "RETURN_FIRE", "OPEN_FIRE"] },
              support: { type: "string", enum: ["", "ARTILLERY", "MORTAR", "CAS", "INFANTRY", "CAR", "APC", "TANK", "TRUCK", "HELICOPTER", "PLANE", "UAV", "MECHANIZED", "ARMOR", "RECON", "AIR_TRANSPORT", "AIR_CAS", "AIR_SUPERIORITY", "TRANSPORT", "INTERCEPT", "ESCORT", "CQB", "RUSH", "GARRISON", "DEFEND", "HUNT", "CREEP"] }
            }
          }
        }
      }
    }
  };
}

function isReasoningModel(model) {
  return /^(?:gpt-5|o\d)/i.test(String(model || ""));
}

function snapshotChannel(snapshot) {
  const value=sideMemory.field(snapshot,'ch');return typeof value==='string'?value:'';
}

function isOpenAiEndpoint(lm) {
  return /(^|\/\/)api\.openai\.com\b/.test(String(lm.baseUrl || ""));
}

function buildRequestPayload(config, snapshot) {
  const lm = config.lmStudio;
  const reasoning = isReasoningModel(lm.model);
  const channel = snapshotChannel(snapshot);
  const payload = {
    model: lm.model,
    messages: buildMessages(snapshot,isGarrisonSnapshot(snapshot)?config.garrisonInstructions:config.preGameInstructions),
    stream: false
  };

  /* 4.4.0 cost: on gpt-5.5 the live log showed only ~1% cached input tokens
   * (vs 61-69% on gpt-4o-mini / gpt-5-mini with the very same prefix), so the
   * ~2k-token constant prefix (system prompt + examples) was billed in full
   * on every request — 68% of the session's cost. A stable prompt_cache_key per
   * side is OpenAI's documented lever for cache routing; harmless elsewhere but
   * only sent to api.openai.com (local backends may reject unknown fields). */
  if (isOpenAiEndpoint(lm)) {
    const side = snapshotSide(snapshot) || "ANY";
    payload.prompt_cache_key = `neroai-4.5-${side}`;
  }

  /* GPT-5 / o-series chat completions reject max_tokens and a non-default
   * temperature; every other backend keeps the classic parameters. */
  if (reasoning) {
    payload.max_completion_tokens = lm.maxTokens;
    if (Number(lm.temperature) === 1) payload.temperature = 1;
  } else {
    payload.max_tokens = lm.maxTokens;
    payload.temperature = lm.temperature;
  }

  /* Reasoning depth per channel: hidden reasoning tokens are billed as output
   * ($30/1M on gpt-5.5, ~16% of session cost at "low"). Routine channels can
   * run cheaper without touching player orders. Config:
   *   lmStudio.reasoningEffortByChannel = { "INTERGROUP": "minimal", "AUTONOMY": "low" } */
  const byChannel = lm.reasoningEffortByChannel && typeof lm.reasoningEffortByChannel === "object" ? lm.reasoningEffortByChannel[channel] : null;
  const effort = typeof byChannel === "string" && byChannel.trim() ? byChannel.trim()
    : (typeof lm.reasoningEffort === "string" && lm.reasoningEffort.trim() ? lm.reasoningEffort.trim() : "");
  if (effort) payload.reasoning_effort = effort;

  /* 8.10 radio silence: commanders exchange data only. The reply is the cost on
   * the RTX 3060 (~20 tok/s) and the radio line was 50-70% of it. */
  const silent = config.radioSpeech === false;
  if (silent) payload.messages[0] = { ...payload.messages[0], content: payload.messages[0].content + "\n\n" + RADIO_SILENCE };
  if (lm.structuredOutput) {
    payload.response_format = { type: "json_schema", json_schema: buildResponseSchema(silent) };
  }
  return payload;
}

/* live 14.09 23:00: 27 requests failed with HTTP 429 (org tokens-per-minute) and
 * each became a canned "помехи" reply. The API states the wait ("try again in
 * 332ms"); one short retry turns most of them into real plans. */
function requestJson(urlText, headers, payload, timeoutMs, retried = false) {
  return requestJsonOnce(urlText, headers, payload, timeoutMs).catch(error => {
    const msg = String(error && error.message || "");
    if (retried || !/HTTP 429/.test(msg)) throw error;
    const m = /try again in (\d+)\s*(ms|s)/i.exec(msg);
    const wait = m ? Math.min(5000, Number(m[1]) * (m[2].toLowerCase() === "s" ? 1000 : 1)) + 250 : 1500;
    return new Promise(resolve => setTimeout(resolve, wait)).then(() => requestJson(urlText, headers, payload, timeoutMs, true));
  });
}

function requestJsonOnce(urlText, headers, payload, timeoutMs) {
  const url = new URL(urlText);
  const client = url.protocol === "https:" ? https : http;
  const body = JSON.stringify(payload);
  return new Promise((resolve, reject) => {
    const request = client.request({
      protocol: url.protocol,
      hostname: url.hostname,
      port: url.port || undefined,
      path: `${url.pathname}${url.search}`,
      method: "POST",
      headers: { "Content-Type": "application/json", "Content-Length": Buffer.byteLength(body), ...headers },
      timeout: timeoutMs
    }, response => {
      let data = "";
      response.setEncoding("utf8");
      response.on("data", part => { data += part; });
      response.on("end", () => {
        let parsed;
        try { parsed = JSON.parse(data); } catch (_) { return reject(new Error(`LM Studio returned non-JSON HTTP ${response.statusCode}`)); }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return reject(new Error(`LM Studio HTTP ${response.statusCode}: ${parsed?.error?.message || data.slice(0, 300)}`));
        }
        resolve(parsed);
      });
    });
    request.on("timeout", () => request.destroy(new Error("LM Studio request timed out")));
    request.on("error", reject);
    request.write(body);
    request.end();
  });
}

/* 4.4.0: per-side model routing (#12) and a model fallback (#13).
 * config.lmStudio.sides = { RED: { baseUrl?, model?, apiKey?, reasoningEffort? }, ... }
 * overrides the base profile for requests whose snapshot carries that side, so
 * RED can be planned by a second model/endpoint entirely. 4.7.0b: the keys may
 * also be ALLIED / ENEMY — resolved against the snapshot's playerSide, so the
 * split "my army here, the enemy there" follows the player's side choice. If the primary model
 * is rejected by the API (unknown model, 4xx mentioning the model), one retry
 * is made with lmStudio.fallbackModel so a wrong model id degrades instead of
 * silencing every group. */
function snapshotSide(snapshot) {
  const value=sideMemory.field(snapshot,'side');return ['BLUE','RED','GREEN'].includes(value)?value:'';
}

function snapshotPlayerSide(snapshot) {
  const value=sideMemory.field(snapshot,'playerSide');return ['BLUE','RED','GREEN','NONE'].includes(value)?value:'';
}

/* 4.7.0b: ALLIED = the player's own army, ENEMY = the other army and the GREEN
 * partisans. Lets the user say "MacBook commands the enemy, the RTX 3060 commands
 * my side" once, without caring whether they picked WEST or EAST this match. */
function sideRelation(side, playerSide) {
  if (!side) return "";
  const mine = playerSide || "BLUE";
  return side === mine ? "ALLIED" : "ENEMY";
}

function effectiveLmConfig(config, snapshot) {
  const base = config.lmStudio || {};
  const side = snapshotSide(snapshot);
  const sides = base.sides && typeof base.sides === "object" ? base.sides : null;
  /* exact side key first (BLUE/RED/GREEN), then the relation key (ALLIED/ENEMY) */
  const override = isGarrisonSnapshot(snapshot)&&base.garrison ? base.garrison : side && sides ? (sides[side] || sides[sideRelation(side, snapshotPlayerSide(snapshot))] || null) : null;
  if (!override || typeof override !== "object") return { lm: base, side, base, overridden: false };
  return { lm: { ...base, ...override }, side, base, overridden: true };
}
function isGarrisonSnapshot(snapshot){try{const s=require('./protocol').parseSqfValue(String(snapshot));if(!Array.isArray(s))return false;for(let i=0;i<s.length;i+=2)if(s[i]==='garrison')return s[i+1]===true;return false;}catch(e){return false;}}

/* A side endpoint that cannot be reached at all (the MacBook over Tailscale is
 * asleep, the link dropped, the server answers 5xx) — as opposed to a model
 * or schema complaint, which the primary would repeat. */
function isEndpointFailure(error) {
  const code = String((error && error.code) || "");
  if (/^(ECONNREFUSED|ECONNRESET|ETIMEDOUT|EHOSTUNREACH|ENETUNREACH|ENOTFOUND|EAI_AGAIN|EPIPE)$/.test(code)) return true;
  const text = String((error && error.message) || error || "");
  return /timed out|ECONNREFUSED|ECONNRESET|EHOSTUNREACH|ENETUNREACH|socket hang up|HTTP 5\d\d/i.test(text);
}

function isModelRejection(error) {
  const text = String((error && error.message) || error || "");
  return /HTTP 4\d\d/.test(text) && /model/i.test(text);
}

// One short MacBook assessment per side, reused for that side's tactical plans.
// 7.10 dual: stale-while-revalidate — after the first intent the tactical queue
// never waits on the strategist; a refresh runs in the background on the other
// machine. A failed strategist is skipped for a minute instead of stalling
// every request on a Tailscale timeout. A fresh bridge process starts a fresh cache.
const STRATEGY_TTL_MS = 120000, STRATEGY_STALE_MS = 600000, STRATEGY_RETRY_MS = 60000, STRATEGY_COLD_WAIT_MS = 20000;
const enemyStrategyCaches = new WeakMap();
const STRATEGIST_PROMPT = "You are the strategic commander of one AI army in an Arma 3 Warlords match; the tactical commanders of your groups follow your intent. Using only the supplied mission facts, write a short Russian strategic intent in exactly four lines:\n" +
  "ЦЕЛЬ: the next sector to seize or hold (a name from the snapshot) and why;\n" +
  "СИЛЫ: concentrate or split, which groups lead, which hold;\n" +
  "ПОКУПКИ: what to spend CP on now (APC/TANK/CAR for squads on foot, transport HELICOPTER for long moves, PLANE for close air support and air superiority) or why to save;\n" +
  "УГРОЗЫ: known enemy contacts and threatened own sectors.\n" +
  "Columns march along roads (roadLinks give road km); prefer objectives with short road distance. Do not invent assets, contacts or sectors. No code. Maximum 600 characters.\n";
function strategyRequest(config, snapshot, profile) {
  const reasoning = profile.reasoningEffort && profile.reasoningEffort !== "none";
  const n = Number(profile.maxTokens) || 900;
  return {
    model: profile.model, stream: false, temperature: Number(profile.temperature ?? 0.8),
    max_tokens: reasoning ? Math.min(2000, Math.max(1500, n)) : Math.min(900, n), reasoning_effort: reasoning ? profile.reasoningEffort : "none",
    messages: [
      { role: "system", content: STRATEGIST_PROMPT + WARLORDS_DOCTRINE + "\nPlayer preferences: " + String(config.preGameInstructions||"").slice(0,3000) },
      { role: "user", content: `OWN_SIDE_MEMORY=${JSON.stringify(sideMemory.recall(config,snapshot))}\nWARLORDS_SNAPSHOT=${String(snapshot).slice(0, 7400)}` }
    ]
  };
}
async function enemyStrategy(config, snapshot, side, playerSide, debugLog) {
  const profile = isGarrisonSnapshot(snapshot)?null:config.dualEnemy?.strategy;
  if (!profile?.baseUrl || !profile?.model) return "";
  let enemyStrategyCache=enemyStrategyCaches.get(config);if(!enemyStrategyCache){enemyStrategyCache=new Map();enemyStrategyCaches.set(config,enemyStrategyCache);}
  const key = `${sideMemory.identity(snapshot)}/${playerSide}`;
  const entry = enemyStrategyCache.get(key) || {};
  const now = Date.now();
  const usable = entry.value && now - entry.at < STRATEGY_STALE_MS ? entry.value : "";
  if (usable && now - entry.at < STRATEGY_TTL_MS) return usable;
  if (entry.failedAt && now - entry.failedAt < STRATEGY_RETRY_MS) return usable;
  if (!entry.pending) {
    const endpoint = `${String(profile.baseUrl).replace(/\/+$/, "")}/chat/completions`;
    const started = Date.now();
    entry.pending = requestJson(endpoint, { Authorization: `Bearer ${profile.apiKey || "lm-studio"}` }, strategyRequest(config, snapshot, profile), Math.min(60000, Number(profile.timeoutMs) || 30000))
      .then(result => {
        const value = String(result?.choices?.[0]?.message?.content || "").trim().slice(0, 700);
        if (!value) { entry.failedAt = Date.now(); debugLog("Enemy strategy unavailable", "empty final message"); return usable; }
        Object.assign(entry, { at: Date.now(), value, failedAt: 0 });
        debugLog("Enemy strategy ready", `side=${side} model=${profile.model} chars=${value.length} ms=${Date.now() - started}`);
        return value;
      }, error => { entry.failedAt = Date.now(); debugLog("Enemy strategy unavailable", String(error?.message || error)); return usable; })
      .finally(() => { entry.pending = null; });
    enemyStrategyCache.set(key, entry);
    while(enemyStrategyCache.size>32)enemyStrategyCache.delete(enemyStrategyCache.keys().next().value);
  }
  if (usable) return usable;
  let timer;
  const cold = new Promise(resolve => { timer = setTimeout(() => resolve(""), STRATEGY_COLD_WAIT_MS); });
  try { return await Promise.race([entry.pending, cold]); } finally { clearTimeout(timer); }
}

async function complete(config, snapshot, debugLog = () => {}) {
  const { lm, side, base, overridden } = effectiveLmConfig(config, snapshot);
  const attempt = async (model, profile = lm, strategicIntent = "") => {
    const endpoint = `${String(profile.baseUrl).replace(/\/+$/, "")}/chat/completions`;
    const payload = buildRequestPayload({ ...config, lmStudio: { ...profile, model } }, snapshot);
    const memory=sideMemory.recall(config,snapshot);
    /* 7.10: one system message only. Qwen3.5 chat templates raise "System message must be at the beginning" on a second system turn (every request failed on the RTX 3060); appending keeps the same text for every backend. */
    payload.messages[0]={...payload.messages[0],content:payload.messages[0].content+"\n\n"+'FOG OF WAR: You command only '+(side||'the addressed side')+'. Other sides have independent memory. Enemy positions come only from your supplied reconnaissance reports; remembered decisions are not proof of current enemy positions. Do not infer hidden units from public sector ownership or from another side. Never invent contacts.'};
    if(memory.length)payload.messages.push({role:'user',content:'OWN_SIDE_MEMORY (previous decisions, not current enemy intelligence)='+JSON.stringify(memory)});
    if (strategicIntent) payload.messages.push({ role: "user", content: `STRATEGIC_INTENT_FROM_MACBOOK=${strategicIntent}\nChoose only legal actions grounded in TACTICAL_SNAPSHOT. Prioritize boarding owned vehicles and affordable CP purchases before marching.` });
    debugLog("LM request", `side=${side || "?"}/${sideRelation(side, snapshotPlayerSide(snapshot)) || "?"} model=${model} endpoint=${profile.baseUrl} ch=${snapshotChannel(snapshot) || "?"} chars=${JSON.stringify(payload.messages).length} effort=${payload.reasoning_effort || "-"} cacheKey=${payload.prompt_cache_key || "-"}`);
    const response = await requestJson(endpoint, { Authorization: `Bearer ${profile.apiKey || "lm-studio"}` }, payload, profile.timeoutMs);
    const message = response?.choices?.[0]?.message || {};
    const content = typeof message.content === "string" ? message.content.trim() : "";
    debugLog("LM raw response", JSON.stringify(response));
    if (!content) {
      const diagnostic = typeof message.reasoning_content === "string" && message.reasoning_content.trim()
        ? "The model returned reasoning_content but no final message.content"
        : "The model returned no final message.content";
      throw new Error(diagnostic);
    }
    sideMemory.remember(config,snapshot,content);
    return content;
  };
  const playerSide = snapshotPlayerSide(snapshot);
  /* 7.10: bothSides — the strategist plans for every AI army, not only the player's enemy. */
  if (side && playerSide && config.dualEnemy?.enabled && (side !== playerSide || config.dualEnemy.bothSides === true)) {
    const intent = await enemyStrategy(config, snapshot, side, playerSide, debugLog);
    return attempt(lm.model, lm, intent);
  }
  try {
    return await attempt(lm.model);
  } catch (error) {
    const fallback = typeof lm.fallbackModel === "string" && lm.fallbackModel.trim();
    if (fallback && fallback !== lm.model && isModelRejection(error)) {
      debugLog("LM model fallback", `${lm.model} rejected (${error.message}); retrying with ${fallback}`);
      return attempt(fallback);
    }
    /* 4.6.0 per-side brains: RED/GREEN live on the MacBook; when that endpoint is
     * unreachable the side is planned by the primary (RTX 3060) instead of falling
     * silent. The primary gets the base profile's own model and timeout. */
    if (overridden && isEndpointFailure(error) && String(base.baseUrl) !== String(lm.baseUrl)) {
      debugLog("LM endpoint fallback", `side=${side} endpoint ${lm.baseUrl} failed (${error.message}); retrying on primary ${base.baseUrl}`);
      return attempt(base.model, base);
    }
    throw error;
  }
}

module.exports = { isGarrisonSnapshot, buildMessages, buildRequestPayload, buildResponseSchema, requestJson, complete, isReasoningModel, effectiveLmConfig, snapshotSide, snapshotChannel, isOpenAiEndpoint, isModelRejection, isEndpointFailure, snapshotPlayerSide, sideRelation, SYSTEM_PROMPT, ALLOWED_ACTION_TYPES };

