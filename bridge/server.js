"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { validateModelResponse, toSqfValue, parseIniEntries, cleanText, fallbackResponse, explicitOrderIntents, bindExplicitOrder, inferIntentPositions, classifyPlayerMessage, extractOrderText, isGroundedPosition, autonomousMoveIsMeaningful } = require("./protocol");
const { complete } = require("./lm-studio");

function loadConfig(configPath) {
  const config = JSON.parse(fs.readFileSync(configPath, "utf8").replace(/^\uFEFF/, ""));
  for (const key of ["lmStudio", "transport", "limits"]) if (!config[key]) throw new Error(`Configuration lacks '${key}'`);
  if (!config.transport.iniFolder || /REPLACE_WITH_YOUR/i.test(config.transport.iniFolder)) throw new Error("Set transport.iniFolder to the isolated INIDBI2 db folder");
  return config;
}

function dbPath(config, dbName) {
  return path.join(config.transport.iniFolder, `${dbName}.ini`);
}

function describeActions(actions) {
  if (!Array.isArray(actions) || actions.length === 0) return "NO_ACTION";
  return actions.map(([type, position, argument]) => {
    const coordinates = Array.isArray(position) && position.length >= 2 ? `@${position[0]},${position[1]}` : "";
    const detail = argument ? `(${argument})` : "";
    return `${type}${coordinates}${detail}`;
  }).join(", ");
}

/*
 * The model is a tactical planner, not an in-game actor.  Its natural-language
 * speech can drift in language and tone, so Arma always receives a short,
 * deterministic Russian radio acknowledgement derived only from the validated
 * action allowlist.
 */
function radioReplyFor(actions) {
  if (!Array.isArray(actions) || actions.length === 0) {
    return "Приказ не исполнен: безопасное тактическое действие не сформировано.";
  }
  if (actions.length > 1) {
    const phrases = actions.slice(0, 3).map(([type, , argument]) => {
      const compound = {
        ADVANCE: "выдвигаемся к указанной точке",
        ASSAULT: "атакуем указанную цель",
        HOLD: "удерживаем позицию",
        RETREAT: "отходим к указанной точке",
        RECON: "ведём разведку",
        REQUEST_FIRE: "запрашиваем огневую поддержку",
        BOARD: "занимаем технику",
        DISEMBARK: "высаживаемся",
        REPAIR: "приступаем к ремонту",
        BUY: "заказываем реквизицию",
        SET_SECTOR: "берём сектор под наблюдение",
        REPORT: "готовим доклад",
        CANCEL: "отменяем предыдущий приказ",
        REQUEST_SUPPORT: "запрашиваем подмогу",
        SHARE_INTEL: "передаём разведданные",
        NEGOTIATE: "устанавливаем связь с союзниками",
        DESIGNATE: "готовим лазерную подсветку",
        AUTONOMY: "действуем самостоятельно по обстановке"
      };
      if (type === "SET_ROE") {
        return argument === "HOLD_FIRE"
          ? "огонь не открываем"
          : argument === "RETURN_FIRE"
            ? "отвечаем только на огонь противника"
            : "разрешён огонь на поражение";
      }
      return compound[type] || "выполняем тактическое действие";
    });
    return "Приказ принят: " + phrases.join(", ") + ".";
  }
  const type = actions[0][0];
  const replies = {
    ADVANCE: "Приказ принят. Выдвигаемся к указанной точке.",
    ASSAULT: "Приказ принят. Атакуем указанную цель.",
    HOLD: "Приказ принят. Удерживаем позицию.",
    RETREAT: "Приказ принят. Отходим к указанной точке.",
    RECON: "Приказ принят. Ведём разведку и докладываем.",
    REQUEST_FIRE: "Приказ принят. Запрашиваем огневую поддержку.",
    BOARD: "Приказ принят. Готовимся к посадке.",
    DISEMBARK: "Приказ принят. Высаживаемся и занимаем позиции.",
    REPAIR: "Приказ принят. Приступаем к ремонту.",
    BUY: "Приказ принят. Заказываем реквизицию за наши очки командования.",
    SET_ROE: "Приказ принят. Правила открытия огня изменены.",
    SET_SECTOR: "Приказ принят. Сектор под наблюдением.",
    REPORT: "Приказ принят. Наблюдаем, доклад готовим.",
    CANCEL: "Приказ принят. Предыдущий приказ отменён.",
    REQUEST_SUPPORT: "Приказ принят. Запрашиваем подмогу у союзников.",
    SHARE_INTEL: "Приказ принят. Передаём разведданные союзникам.",
    NEGOTIATE: "Приказ принят. Координируемся с союзными группами.",
    DESIGNATE: "Приказ принят. Ищем цель и готовим лазерную подсветку.",
    AUTONOMY: "Приказ принят. Дальше действуем самостоятельно по обстановке."
  };
  return replies[type] || "Приказ не исполнен: действие не распознано.";
}

function defaultLogger(debug) {
  const logFile = process.env.NEROAI_LOG_FILE ? path.resolve(process.env.NEROAI_LOG_FILE) : "";
  const quiet = process.env.NEROAI_QUIET_STDOUT === "1";
  if (logFile) { try { fs.mkdirSync(path.dirname(logFile), { recursive: true }); } catch (_) { /* file logging is best effort */ } }
  return (label, data = "") => {
    const time = new Date().toISOString();
    const line = debug ? `[${time}] ${label}${data ? `\n${data}` : ""}` : `[${time}] ${label}`;
    if (logFile) { try { fs.appendFileSync(logFile, line + "\n", "utf8"); } catch (_) { /* never let logging stop the bridge */ } }
    if (!quiet) console.log(line);
  };
}

function validateRequest(id, envelope, config) {
  if (!Array.isArray(envelope) || envelope[0] !== "request" || !Array.isArray(envelope[1])) return null;
  const payload = envelope[1];
  const version = Number(payload[0]);
  const requestId = String(payload[1] || "");
  const channel = String(payload[2] || "");
  const targetIds = payload[3];
  const snapshot = String(payload[4] || "");
  const origin = String(payload[5] || (["AUTONOMY", "INTERGROUP"].includes(channel) ? "AUTONOMY" : "PLAYER")).toUpperCase();
  if (version !== 3 || id !== requestId || !["SIDE", "GROUP", "AUTONOMY", "INTERGROUP"].includes(channel) || !["PLAYER", "AUTONOMY"].includes(origin) || !Array.isArray(targetIds) || targetIds.length === 0) return null;
  if (snapshot.length === 0 || snapshot.length > config.limits.maxSnapshotChars) return null;
  return { id, channel, origin, targetIds: targetIds.map(String).slice(0, 16), snapshot };
}

const appendQueues = new Map();
async function appendEntry(filePath, section, key, value) {
  const target = path.resolve(filePath);
  const prior = appendQueues.get(target) || Promise.resolve();
  const write = prior.catch(() => {}).then(async () => {
    await fs.promises.mkdir(path.dirname(target), { recursive: true });
    let prefix = "";
    try {
      const stat = await fs.promises.stat(target);
      if (stat.size === 0) prefix = `[${section}]\r\n`;
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
      prefix = `[${section}]\r\n`;
    }
    /* INIDBI2 in Arma rewrites this file through kernel32 WritePrivateProfileString,
     * which briefly locks it; a concurrent append then fails with EBUSY. Retry the
     * single-buffer append instead of dropping the reply and re-asking the model. */
    const line = `${prefix}${key} = ${toSqfValue(value)}\r\n`;
    for (let attempt = 1; ; attempt++) {
      try { await fs.promises.appendFile(target, line, "utf8"); break; } catch (error) {
        if (attempt >= 8 || !["EBUSY", "EPERM", "EACCES"].includes(error.code)) throw error;
        await new Promise(resolve => setTimeout(resolve, 15 * attempt));
      }
    }
  });
  appendQueues.set(target, write);
  try { await write; } finally { if (appendQueues.get(target) === write) appendQueues.delete(target); }
}

function createBridge({ config, completion = complete, log = () => {} }) {
  const handled = new Set();
  const queued = new Set();
  let active = 0;

  /* 4.6.0 launcher check 16.09 23:32: the outbox INI still held 15 requests from
   * earlier sessions (Arma only deletes a key when it consumes the reply or
   * times it out at 100 s, and the game had been closed). Every bridge start
   * re-sent them to the model — ~75 s of GPU on a local 9B, with the first real
   * plans of the session queued behind maxPending. Entries that already exist
   * when the bridge starts belong to a previous life of Arma or of this bridge:
   * they are marked handled without an LLM call and without any write (the
   * outbox is Arma's file — rule 3). If the bridge is restarted mid-game, those
   * few in-flight requests time out in Arma after 100 s and are re-planned. */
  async function skipStaleOutbox() {
    const outbox = dbPath(config, config.transport.outboxDb);
    let content = "";
    try { content = await fs.promises.readFile(outbox, "utf8"); } catch (error) { if (error.code !== "ENOENT") throw error; return 0; }
    const entries = parseIniEntries(content, config.transport.outboxDb, () => {});
    let skipped = 0;
    for (const [id] of entries) if (!handled.has(id)) { handled.add(id); skipped++; }
    if (skipped) log("Stale outbox skipped", `${skipped} request(s) left over from a previous session were ignored (no LLM call, no reply).`);
    return skipped;
  }

  async function processRequest(request) {
    active++;
    try {
      log("Accepted request", `${request.id} (${request.channel}; ${request.targetIds.length} groups)`);
      log("Game input",`${request.id}: ${cleanText(extractOrderText(request.snapshot),900)}`);
      const began=Date.now();
      let final;
      try {
        const raw = await completion(config, request.snapshot, log);
        log("LLM final JSON",`${request.id}: ${String(raw).slice(0,10000)}`);
        final = validateModelResponse(raw, config.limits);
        log("LLM elapsed",`${request.id}: ${Date.now()-began} ms`);
      } catch (error) {
        log("Bridge/model failure", error.message || String(error));
        final = fallbackResponse("В эфире помехи: NeroAI не получил безопасный финальный ответ.");
      }
      const autonomous = request.origin === "AUTONOMY" || ["AUTONOMY", "INTERGROUP"].includes(request.channel);
      const message = autonomous ? { kind: "AUTONOMY" } : classifyPlayerMessage(request.snapshot);
      const intents = autonomous ? [] : inferIntentPositions(explicitOrderIntents(request.snapshot), request.snapshot);
      /* A free-form question, situational note or pure chatter must be answered
       * in the model's own role-play voice, but it must never silently retask
       * the group: keep at most a REPORT / SHARE_INTEL and drop every movement. */
      const talkSpeech = (canned) => (final.ok && final.speech && final.speech !== "Вас понял. Исполняю безопасный манёвр." ? final.speech : canned);
      if (message.kind === "QUESTION") {
        const kept = (final.ok ? final.actions : []).filter(action => ["REPORT", "SHARE_INTEL"].includes(action[0])).slice(0, 2);
        final.actions = kept.length > 0 ? kept : [["REPORT", [], ""]];
        final.speech = talkSpeech("Принял запрос. Докладываю обстановку, текущую задачу не меняю.");
        log("Non-order message", `${request.id}: QUESTION`);
      } else if (message.kind === "INFORMATION") {
        final.actions = [];
        final.speech = talkSpeech("Сообщение принято. Учитываем обстановку, текущую задачу не меняем.");
        log("Non-order message", `${request.id}: INFORMATION`);
      } else if (message.kind === "CHATTER") {
        final.actions = [];
        final.speech = talkSpeech("Принял, на связи. Продолжаем выполнять задачу.");
        log("Non-order message", `${request.id}: CHATTER`);
      } else if (intents.length > 0) {
        const literal = bindExplicitOrder(final.actions, intents, request.snapshot);
        final.actions = literal.actions;
        /* 4.4.0: the model's own in-character acknowledgement is kept whenever it
         * is present and safe — a canned "Вас понял" on every order made the
         * radio dead. Canned text only when the model gave none or the order
         * could not be bound to a position. */
        final.speech = literal.unresolved
          ? "Приказ принят частично. Для пространственного действия укажите координаты или направление."
          : (cleanText(final.speech, config.limits.maxSpeechChars) || radioReplyFor(final.actions));
        if (literal.unresolved) log("Literal order needs coordinate", request.id);
      } else if (autonomous && final.ok) {
        const spatial = new Set(["ADVANCE", "ASSAULT", "RETREAT", "REQUEST_FIRE", "SET_SECTOR", "DESIGNATE", "AIR_TASK"]);
        const minMove = Number(config.limits.minAutonomousMoveMeters) || 35;
        final.actions = final.actions.filter(action => {
          if (!spatial.has(action[0])) return true;
          if (!isGroundedPosition(action[1], request.snapshot)) return false;
          return autonomousMoveIsMeaningful(action[0], action[1], request.snapshot, minMove);
        });
        final.speech = cleanText(final.speech, config.limits.maxSpeechChars) || radioReplyFor(final.actions);
        log("Autonomous plan", `${request.id}: ${describeActions(final.actions)}`);
      } else if (final.ok) {
        final.speech = cleanText(final.speech, config.limits.maxSpeechChars) || radioReplyFor(final.actions);
      }
      /* 8.10 radio silence: AI-to-AI planning goes without a radio line (empty
       * speech is never broadcast by fn_broadcastSpeech); a player still gets a
       * deterministic acknowledgement that costs no model tokens. */
      if (config.radioSpeech === false) {
        final.speech = autonomous ? "" : (final.speech && final.speech !== "Вас понял. Исполняю безопасный манёвр." ? final.speech : radioReplyFor(final.actions));
      }
      log("Radio acknowledgement", `${request.id}: ${final.speech}`);
      log("Validated action plan", `${request.id}: ${describeActions(final.actions)}`);
      const inbox = dbPath(config, config.transport.inboxDb);
      await appendEntry(inbox, config.transport.inboxDb, request.id, ["response", ["ok", request.id, final.speech, final.actions]]);
      handled.add(request.id);
      log("Wrote response", `${request.id}; actions=${final.actions.length}`);
    } finally {
      queued.delete(request.id);
      active--;
    }
  }

  async function pollOnce() {
    const outbox = dbPath(config, config.transport.outboxDb);
    let content = "";
    try { content = await fs.promises.readFile(outbox, "utf8"); } catch (error) { if (error.code !== "ENOENT") throw error; return 0; }
    const entries = parseIniEntries(content, config.transport.outboxDb, (id, error) => {
      log("Unreadable outbox entry", `${id}: ${error.message || String(error)}`);
    });
    let started = 0;
    for (const [id, envelope] of entries) {
      if (handled.has(id) || queued.has(id) || active >= config.transport.maxPending) continue;
      const request = validateRequest(id, envelope, config);
      if (!request) { log("Dropped malformed outbox entry", id); handled.add(id); continue; }
      queued.add(id);
      started++;
      void processRequest(request).catch(error => log("Response write failure", error.stack || error.message || String(error)));
    }
    return started;
  }
  return { pollOnce, processRequest, handled, skipStaleOutbox };
}

async function main() {
  const debug = process.argv.includes("--debug");
  const projectRoot = path.resolve(__dirname, "..");
  const configPath = process.env.NEROAI3_CONFIG || path.join(projectRoot, "bridge", "neroai3.config.json");
  const config = loadConfig(configPath);
  const log = defaultLogger(debug);
  const bridge = createBridge({ config, log });
  log(
    "NeroAI 4.7.0 [Any Warlords] autonomous bridge started",
    [
      `outbox=${dbPath(config, config.transport.outboxDb)}`,
      `inbox=${dbPath(config, config.transport.inboxDb)}`,
      `model=${config.lmStudio.model}`,
      `reasoningEffort=${config.lmStudio.reasoningEffort || "provider-default"}`,
      `maxTokens=${config.lmStudio.maxTokens}; timeoutMs=${config.lmStudio.timeoutMs}; maxPending=${config.transport.maxPending}`
    ].join("\n")
  );
  await bridge.skipStaleOutbox();
  let polling = false;
  const tick = async () => {
    if (polling) return;
    polling = true;
    try { await bridge.pollOnce(); } catch (error) { log("Polling error", error.stack || error.message || String(error)); } finally { polling = false; }
  };
  await tick();
  setInterval(tick, Math.max(100, Number(config.transport.pollMs) || 350));
}

if (require.main === module) {
  main().catch(error => { console.error(`[NeroAI 4.7.0 Any Warlords] Fatal bridge error: ${error.stack || error.message}`); process.exitCode = 1; });
}

module.exports = { loadConfig, createBridge, validateRequest, appendEntry, dbPath, cleanText, describeActions, radioReplyFor };
