"use strict";
/* NeroAI 4.6.0 [Local LLM] — load every configured brain before a session.
 *
 *   node tools/preload-brains.js            load 3060 (lms) + every remote side endpoint (REST)
 *   node tools/preload-brains.js --check    report only, load nothing
 *
 * bridge/neroai3.config.json: lmStudio = the primary (LM Studio on this PC, RTX 3060),
 * lmStudio.sides.<SIDE> = per-side overrides; a side whose baseUrl is not this PC is a
 * remote brain (the MacBook over Tailscale) and is loaded through LM Studio's REST API
 * (POST /api/v1/models/load), which needs the endpoint's own API token.
 *
 * Live incident 18.09: LM Studio had BOTH GPUs disabled for the Vulkan runtime
 * (.lmstudio/.internal/hardware-config.json disabledGpus [1,0]) — the 9B planner
 * loaded on the CPU, every plan took 30–85 s and the bridge timed out. A load is
 * therefore not "OK" until the RTX 3060 actually holds the weights (nvidia-smi). */
const fs = require("node:fs");
const path = require("node:path");
const http = require("node:http");
const https = require("node:https");
const { spawnSync } = require("node:child_process");

const root = path.resolve(__dirname, "..");
const config = JSON.parse(fs.readFileSync(path.join(root, "bridge", "neroai3.config.json"), "utf8"));
const checkOnly = process.argv.includes("--check");
const lm = config.lmStudio || {};
const CONTEXT = 8192;
const PARALLEL = 2;

function isLocal(baseUrl) { return /^https?:\/\/(127\.0\.0\.1|localhost|0\.0\.0\.0)(:|\/|$)/i.test(String(baseUrl || "")); }
function apiRoot(baseUrl) { return String(baseUrl || "").replace(/\/+$/, "").replace(/\/v1$/, ""); }

function request(method, url, apiKey, body, timeoutMs) {
  return new Promise(resolve => {
    let target;
    try { target = new URL(url); } catch (error) { return resolve({ error: error.message }); }
    const client = target.protocol === "https:" ? https : http;
    const data = body ? JSON.stringify(body) : null;
    const headers = { Authorization: `Bearer ${apiKey || "lm-studio"}` };
    if (data) { headers["Content-Type"] = "application/json"; headers["Content-Length"] = Buffer.byteLength(data); }
    const started = Date.now();
    const req = client.request(target, { method, headers, timeout: timeoutMs }, res => {
      let text = "";
      res.setEncoding("utf8");
      res.on("data", part => { text += part; });
      res.on("end", () => {
        let json = null;
        try { json = JSON.parse(text); } catch (_) { /* keep raw */ }
        resolve({ status: res.statusCode, json, text, ms: Date.now() - started });
      });
    });
    req.on("error", error => resolve({ error: error.code || error.message, ms: Date.now() - started }));
    req.on("timeout", () => { req.destroy(); resolve({ error: "timeout", ms: Date.now() - started }); });
    if (data) req.write(data);
    req.end();
  });
}

async function modelState(baseUrl, apiKey, model) {
  const r = await request("GET", `${apiRoot(baseUrl)}/api/v0/models`, apiKey, null, 8000);
  if (r.error) return { reachable: false, error: r.error };
  if (r.status !== 200 || !r.json) return { reachable: false, error: `HTTP ${r.status}` };
  const rows = Array.isArray(r.json.data) ? r.json.data : [];
  const row = rows.find(x => x.id === model);
  return { reachable: true, ms: r.ms, listed: Boolean(row), state: row ? row.state : "not-listed", ctx: row ? row.loaded_context_length : undefined,
    loaded: rows.filter(x => x.state === "loaded").map(x => x.id) };
}

function gpuMemoryMiB() {
  const out = spawnSync("nvidia-smi", ["--query-gpu=name,memory.used", "--format=csv,noheader,nounits"], { encoding: "utf8" });
  if (out.status !== 0) return null;
  return out.stdout.trim().split(/\r?\n/).map(line => { const [name, used] = line.split(",").map(s => s.trim()); return { name, usedMiB: Number(used) }; });
}

function stamp(label, text) { process.stdout.write(`[${label}] ${text}\n`); }

async function loadLocal() {
  const before = await modelState(lm.baseUrl, lm.apiKey, lm.model);
  if (!before.reachable) { stamp("3060", `LM Studio at ${lm.baseUrl} is not answering (${before.error}). Start LM Studio and its local server (lms server start).`); return false; }
  if (!before.listed) { stamp("3060", `LM Studio does not list "${lm.model}" — check lmStudio.model in bridge/neroai3.config.json (lms ls).`); return false; }
  if (before.state !== "loaded" && !checkOnly) {
    stamp("3060", `loading ${lm.model} (GPU max, context ${CONTEXT}, ${PARALLEL} slots)…`);
    const out = spawnSync("lms", ["load", JSON.stringify(lm.model), "--gpu", "max", "--context-length", String(CONTEXT), "--parallel", String(PARALLEL), "-y"], { encoding: "utf8", shell: true, timeout: 180000 });
    const tail = String(out.stdout || "").split(/\r/).pop().trim();
    if (out.status !== 0) { stamp("3060", `lms load failed: ${tail || out.stderr}`); return false; }
    stamp("3060", tail || "loaded");
  }
  /* the listing can lag a second behind lms load — poll briefly before judging */
  let after = await modelState(lm.baseUrl, lm.apiKey, lm.model);
  for (let i = 0; i < 5 && after.state !== "loaded"; i++) { await new Promise(r => setTimeout(r, 1500)); after = await modelState(lm.baseUrl, lm.apiKey, lm.model); }
  const gpus = gpuMemoryMiB();
  const rtx = gpus ? gpus.find(g => /3060/.test(g.name)) : null;
  const onGpu = rtx ? rtx.usedMiB > 4500 : null;
  stamp("3060", `${lm.model}: ${after.state}${after.ctx ? ` ctx=${after.ctx}` : ""}${rtx ? `; RTX 3060 VRAM in use ${rtx.usedMiB} MiB` : ""}`);
  if (after.state === "loaded" && onGpu === false) {
    stamp("3060", "WARNING: the model is loaded but the RTX 3060 holds almost nothing — it is running on the CPU (30–85 s per plan).");
    stamp("3060", "Fix: LM Studio → Settings → Hardware → enable the RTX 3060 for the Vulkan runtime (keep the GTX 1060 off), then re-run this script.");
    return false;
  }
  return after.state === "loaded";
}

async function loadRemote(side, cfg) {
  const label = `${side}@${new URL(cfg.baseUrl).host}`;
  const before = await modelState(cfg.baseUrl, cfg.apiKey, cfg.model);
  if (!before.reachable) { stamp(label, `unreachable (${before.error}) — the bridge will plan ${side} on the RTX 3060 instead.`); return false; }
  if (!before.listed) { stamp(label, `endpoint answers (${before.ms} ms) but does not list "${cfg.model}"; loaded there: ${before.loaded.join(", ") || "nothing"}.`); return false; }
  if (before.state === "loaded") { stamp(label, `${cfg.model}: loaded (ctx=${before.ctx}, ${before.ms} ms round trip)`); return true; }
  if (checkOnly) { stamp(label, `${cfg.model}: ${before.state}`); return false; }
  stamp(label, `loading ${cfg.model} through REST…`);
  const r = await request("POST", `${apiRoot(cfg.baseUrl)}/api/v1/models/load`, cfg.apiKey, { model: cfg.model, context_length: CONTEXT }, 180000);
  if (r.error || r.status !== 200) {
    stamp(label, `REST load refused (${r.error || `HTTP ${r.status}: ${r.text.slice(0, 120)}`}); trying a JIT warm-up request…`);
    const warm = await request("POST", `${apiRoot(cfg.baseUrl)}/v1/chat/completions`, cfg.apiKey, { model: cfg.model, messages: [{ role: "user", content: "ok" }], max_tokens: 1 }, 180000);
    if (warm.error || warm.status !== 200) { stamp(label, `warm-up failed (${warm.error || `HTTP ${warm.status}`}).`); return false; }
  }
  const after = await modelState(cfg.baseUrl, cfg.apiKey, cfg.model);
  stamp(label, `${cfg.model}: ${after.state}${after.ctx ? ` ctx=${after.ctx}` : ""} (${r.ms} ms)`);
  return after.state === "loaded";
}

(async () => {
  stamp("brains", checkOnly ? "check only — nothing will be loaded" : "preloading every configured brain");
  const results = {};
  results.primary = await loadLocal();
  const sides = lm.sides && typeof lm.sides === "object" ? lm.sides : {};
  const seen = new Map();
  for (const [side, cfg] of Object.entries(sides)) {
    const baseUrl = cfg.baseUrl || lm.baseUrl;
    if (isLocal(baseUrl) || baseUrl === lm.baseUrl) { stamp(side, `planned on the primary (${baseUrl})${cfg.label ? " — " + cfg.label : ""}`); continue; }
    const key = `${baseUrl}|${cfg.model || lm.model}`;
    if (seen.has(key)) { stamp(side, `same brain as ${seen.get(key)}`); continue; }
    seen.set(key, side);
    results[side] = await loadRemote(side, { baseUrl, model: cfg.model || lm.model, apiKey: cfg.apiKey || lm.apiKey });
  }
  const remoteOk = Object.entries(results).filter(([k]) => k !== "primary");
  stamp("brains", `primary ${results.primary ? "READY" : "NOT READY"}` + (remoteOk.length ? `; remote: ${remoteOk.map(([k, v]) => `${k} ${v ? "READY" : "fallback→3060"}`).join(", ")}` : ""));
  process.exitCode = results.primary ? 0 : 1;
})();
