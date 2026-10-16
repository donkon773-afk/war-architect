"use strict";

const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

const projectRoot = path.resolve(__dirname, "..");
const inspectOnly = process.argv.includes("--inspect");
const missionPbo = process.argv.includes("--mission");
const positional = process.argv.slice(2).filter(value => !value.startsWith("--"));
const pboPath = path.resolve(positional[0] || path.join(projectRoot, "dist", "NeroWL.pbo"));
const sourceRoot = path.resolve(positional[1] || path.join(projectRoot, "addons", "NeroAI3"));
const expectedPrefix = positional[2] || "NeroWL";

function fail(message) {
  throw new Error(`PBO verification failed: ${message}`);
}

function readCString(buffer, state) {
  const end = buffer.indexOf(0, state.offset);
  if (end < 0) fail(`unterminated string at byte ${state.offset}`);
  const value = buffer.subarray(state.offset, end).toString("ascii");
  state.offset = end + 1;
  return value;
}

function readUInt32(buffer, state) {
  if (state.offset + 4 > buffer.length) fail(`truncated uint32 at byte ${state.offset}`);
  const value = buffer.readUInt32LE(state.offset);
  state.offset += 4;
  return value;
}

function listFiles(root, relative = "") {
  const directory = path.join(root, relative);
  const result = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const child = relative ? path.join(relative, entry.name) : entry.name;
    if (entry.isDirectory()) result.push(...listFiles(root, child));
    if (entry.isFile()) result.push(child.replaceAll(path.sep, "/"));
  }
  return result.sort((a, b) => a.localeCompare(b, "en"));
}

if (!fs.existsSync(pboPath)) fail(`file does not exist: ${pboPath}`);
if (!fs.existsSync(sourceRoot)) fail(`source does not exist: ${sourceRoot}`);

const bytes = fs.readFileSync(pboPath);
if (bytes.length < 64) fail("file is too small");

const bodyEnd = bytes.length - 21;
if (bytes[bodyEnd] !== 0) fail("checksum separator is missing");
const storedSha1 = bytes.subarray(bodyEnd + 1);
const actualSha1 = crypto.createHash("sha1").update(bytes.subarray(0, bodyEnd)).digest();
if (!storedSha1.equals(actualSha1)) fail("trailer SHA-1 does not match the PBO body");

const state = { offset: 0 };
const properties = new Map();
if (!missionPbo) {
if (readCString(bytes, state) !== "") fail("missing Vers header marker");
if (readUInt32(bytes, state) !== 0x56657273) fail("unexpected PBO header method");
for (let index = 0; index < 4; index += 1) readUInt32(bytes, state);

while (true) {
  const key = readCString(bytes, state);
  if (!key) break;
  properties.set(key.toLowerCase(), readCString(bytes, state));
}
if (!inspectOnly && properties.get("prefix") !== expectedPrefix) {
  fail(`prefix is '${properties.get("prefix") || "<missing>"}', expected '${expectedPrefix}'`);
}
} else if (bytes[0] === 0) {
  fail("mission PBO must begin with a file header, not addon properties");
}

const headers = [];
const seenNames = new Set();
while (true) {
  const name = readCString(bytes, state).replaceAll("\\", "/");
  if (!name) {
    if (state.offset + 20 > bodyEnd) fail("truncated end-of-header marker");
    for (const marker of bytes.subarray(state.offset, state.offset + 20)) {
      if (marker !== 0) fail("invalid end-of-header marker");
    }
    state.offset += 20;
    break;
  }
  if (seenNames.has(name)) fail(`duplicate file header: ${name}`);
  seenNames.add(name);
  const packingMethod = readUInt32(bytes, state);
  const originalSize = readUInt32(bytes, state);
  const reserved = readUInt32(bytes, state);
  const timestamp = readUInt32(bytes, state);
  const dataSize = readUInt32(bytes, state);
  if (packingMethod !== 0) fail(`compressed entry is not supported by this build: ${name}`);
  if (reserved !== 0) fail(`unexpected reserved value for ${name}`);
  if (originalSize !== dataSize) fail(`size mismatch in uncompressed header for ${name}`);
  headers.push({ name, originalSize, timestamp, dataSize });
}

const entries = new Map();
for (const header of headers) {
  const end = state.offset + header.dataSize;
  if (end > bodyEnd) fail(`entry exceeds PBO body: ${header.name}`);
  entries.set(header.name, bytes.subarray(state.offset, end));
  state.offset = end;
}
if (state.offset !== bodyEnd) fail(`${bodyEnd - state.offset} unreferenced byte(s) remain before checksum`);

const sourceFiles = listFiles(sourceRoot);
const pboFiles = [...entries.keys()].sort((a, b) => a.localeCompare(b, "en"));
const missing = sourceFiles.filter(name => !entries.has(name));
const unexpected = pboFiles.filter(name => !sourceFiles.includes(name));
if (!inspectOnly && JSON.stringify(sourceFiles) !== JSON.stringify(pboFiles)) {
  fail(`manifest differs; missing=[${missing.join(", ")}], unexpected=[${unexpected.join(", ")}]`);
}

const changed = [];
for (const name of sourceFiles) {
  if (!entries.has(name)) continue;
  const sourceBytes = fs.readFileSync(path.join(sourceRoot, ...name.split("/")));
  if (!sourceBytes.equals(entries.get(name))) changed.push(name);
}
if (!inspectOnly && changed.length > 0) fail(`content differs from source: ${changed.join(", ")}`);

const sha256 = crypto.createHash("sha256").update(bytes).digest("hex").toUpperCase();
const configText = entries.get("config.cpp")?.toString("utf8") || "";
const versionMatch = configText.match(/name\s*=\s*"([^"]+)"/);

console.log(JSON.stringify({
  verified: true,
  pbo: pboPath,
  source: sourceRoot,
  prefix: properties.get("prefix"),
  displayName: versionMatch?.[1] || null,
  fileCount: sourceFiles.length,
  pboFileCount: pboFiles.length,
  manifestMatchesSource: missing.length === 0 && unexpected.length === 0,
  contentsMatchSource: changed.length === 0,
  missingFromPbo: missing,
  unexpectedInPbo: unexpected,
  changedFromSource: changed,
  sizeBytes: bytes.length,
  sha1Body: actualSha1.toString("hex").toUpperCase(),
  sha256
}, null, 2));
