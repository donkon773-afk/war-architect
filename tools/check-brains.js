"use strict";

const fs = require("node:fs");
const path = require("node:path");
const arg = process.argv.indexOf("--config");
const configPath = arg >= 0 && process.argv[arg + 1] ? path.resolve(process.argv[arg + 1]) : process.env.NEROAI3_CONFIG || path.join(__dirname, "..", "bridge", "neroai3.config.json");
const config = JSON.parse(fs.readFileSync(configPath, "utf8").replace(/^\uFEFF/, ""));

async function verify(label, profile) {
  if (!profile?.baseUrl || !profile?.model) throw new Error(`${label}: endpoint/model missing`);
  const root = profile.baseUrl.replace(/\/+$/, "");
  const headers = { Authorization: `Bearer ${profile.apiKey || "lm-studio"}` };
  const list = await fetch(`${root}/models`, { headers, signal: AbortSignal.timeout(10000) });
  if (!list.ok) throw new Error(`${label}: model listing HTTP ${list.status}`);
  const models = await list.json();
  if (!models.data?.some(entry => entry.id === profile.model)) throw new Error(`${label}: configured model not listed by endpoint`);
  const response = await fetch(`${root}/chat/completions`, {
    method: "POST",
    headers: { ...headers, "Content-Type": "application/json" },
    body: JSON.stringify({ model: profile.model, messages: [{ role: "user", content: "Ответь одним словом: готов" }], max_tokens: Math.min(900, profile.maxTokens || 900), reasoning_effort: "none", temperature: 0, stream: false }),
    signal: AbortSignal.timeout(Math.min(60000, profile.timeoutMs || 60000))
  });
  if (!response.ok) throw new Error(`${label}: completion HTTP ${response.status}`);
  const body = await response.json();
  if (!String(body.choices?.[0]?.message?.content || "").trim()) throw new Error(`${label}: no final message`);
  process.stdout.write(`${label}: ready (${profile.model})\n`);
}

(async () => {
  await verify(config.dualEnemy?.enabled ? "Tactical LLM" : "Mac strategy + tactics", config.lmStudio);
  if (config.dualEnemy?.enabled) await verify("Mac strategic", config.dualEnemy.strategy);
  if(config.lmStudio.garrison) await verify("Garrison LLM",config.lmStudio.garrison);
  if (config.lmStudio.sides?.ALLIED) await verify("Allied LLM",{...config.lmStudio,...config.lmStudio.sides.ALLIED});
})().catch(error => { process.stderr.write(`${error.message}\n`); process.exitCode = 1; });
