'use strict';
/* Read an Arma 3 terrain (OPRW v20–25) straight from the mod PBO — no game:
 * model list, every placed object (position, rotation, model) and the road
 * network. Used to draw crisp roads and building footprints in the editor.
 * Every section is bounds-checked; a layout this reader does not understand
 * throws instead of producing a guessed map. */
const fs = require('node:fs');
const { indexEntries } = require('../read-pbo-entry');

function lzss(input, expected) {
  const out = Buffer.alloc(expected); let pos = 0, read = 0; const limit = input.length - 4;
  while (pos < expected) {
    if (read >= limit) throw Error('LZSS truncated');
    const flags = input[read++];
    for (let bit = 0; bit < 8 && pos < expected; bit++) {
      if (flags & (1 << bit)) out[pos++] = input[read++];
      else { const a = input[read++], b = input[read++]; let from = pos - (a + ((b & 240) << 4)); const n = (b & 15) + 3; for (let i = 0; i < n && pos < expected; i++, from++) out[pos++] = from < 0 ? 32 : out[from]; }
    }
  }
  return out;
}

/* LZO1X decompression that reports how many input bytes it consumed. */
function lzo1x(src, start, outLen) {
  const out = Buffer.alloc(outLen); let ip = start, op = 0, state = 0;
  const lit = n => { if (ip + n > src.length || op + n > outLen) throw Error('LZO literal overrun'); src.copy(out, op, ip, ip + n); ip += n; op += n; };
  const zeros = () => { let c = 0; while (src[ip] === 0) { ip++; c++; } return c; };
  if (src[ip] >= 22) { const n = src[ip++] - 17; lit(n); state = 4; }
  else if (src[ip] >= 18) { const n = src[ip++] - 17; lit(n); state = n; }
  for (;;) {
    const inst = src[ip++]; let from, len, ns;
    if (inst & 0xC0) { from = op - ((src[ip++] << 3) + ((inst >> 2) & 7) + 1); len = (inst >> 5) + 1; ns = inst & 3; }
    else if (inst & 0x20) { len = (inst & 0x1f) + 2; if (len === 2) { const z = zeros(); len += z * 255 + 31 + src[ip++]; } ns = src.readUInt16LE(ip); ip += 2; from = op - ((ns >> 2) + 1); ns &= 3; }
    else if (inst & 0x10) { len = (inst & 7) + 2; if (len === 2) { const z = zeros(); len += z * 255 + 7 + src[ip++]; } ns = src.readUInt16LE(ip); ip += 2; from = op - (((inst & 8) << 11) + (ns >> 2)); ns &= 3; if (from === op) break; from -= 16384; }
    else if (state === 0) { let n = inst + 3; if (n === 3) { const z = zeros(); n += z * 255 + 15 + src[ip++]; } lit(n); state = 4; continue; }
    else if (state !== 4) { ns = inst & 3; from = op - ((inst >> 2) + (src[ip++] << 2) + 1); len = 2; }
    else { ns = inst & 3; from = op - ((inst >> 2) + (src[ip++] << 2) + 2049); len = 3; }
    if (from < 0 || op + len > outLen) throw Error('LZO back-reference out of range');
    for (let i = 0; i < len; i++) out[op++] = out[from++];
    state = ns; if (ns) lit(ns);
  }
  if (op !== outLen) throw Error(`LZO length ${op} != ${outLen}`);
  return { data: out, end: ip };
}

class Reader {
  constructor(b) { this.b = b; this.p = 0; }
  u8() { return this.b[this.p++]; } u16() { const v = this.b.readUInt16LE(this.p); this.p += 2; return v; }
  u32() { const v = this.b.readUInt32LE(this.p); this.p += 4; return v; } f32() { const v = this.b.readFloatLE(this.p); this.p += 4; return v; }
  str() { const e = this.b.indexOf(0, this.p); if (e < 0 || e - this.p > 1024) throw Error('bad string at ' + this.p); const s = this.b.toString('latin1', this.p, e); this.p = e + 1; return s; }
  skip(n) { this.p += n; if (this.p > this.b.length) throw Error('read past end'); }
  /* BI compressed array: raw when smaller than 1024 bytes, else LZO1X. */
  lzo(bytes) { if (bytes < 1024) { const d = this.b.subarray(this.p, this.p + bytes); this.p += bytes; return d; } const r = lzo1x(this.b, this.p, bytes); this.p = r.end; return r.data; }
  quadTree() { if (this.u8()) this.node(0); else this.skip(4); }
  node(depth) { if (depth > 32) throw Error('quadtree too deep'); const mask = this.u16(); for (let i = 0; i < 16; i++) if (mask & (1 << i)) this.node(depth + 1); else this.skip(4); }
}

function loadWrp(pbo, virtual) {
  const e = indexEntries(pbo).find(x => x.virtual.toLowerCase() === virtual.toLowerCase());
  if (!e) throw Error('WRP not found: ' + virtual);
  const fd = fs.openSync(pbo, 'r'); const raw = Buffer.alloc(e.size);
  try { fs.readSync(fd, raw, 0, e.size, e.offset); } finally { fs.closeSync(fd); }
  return e.packing === 0x43707273 ? lzss(raw, e.original) : raw;
}

function parse(buf, log = () => {}, opts = {}) {
  const r = new Reader(buf);
  if (buf.toString('ascii', 0, 4) !== 'OPRW') throw Error('not OPRW'); r.p = 4;
  const version = r.u32(); if (version < 20 || version > 25) throw Error('unsupported OPRW ' + version);
  const appId = version >= 25 ? r.u32() : 0;
  const layerX = r.u32(), layerY = r.u32(), mapX = r.u32(), mapY = r.u32(), cell = r.f32();
  log({ version, appId, layerX, layerY, mapX, mapY, cell, worldSize: layerX * cell });
  r.quadTree(); log({ at: r.p, after: 'geography' });
  r.quadTree(); log({ at: r.p, after: 'soundmap' });
  const peaks = r.u32(); if (peaks > 1e6) throw Error('peaks ' + peaks); r.skip(peaks * 12); log({ peaks, at: r.p });
  r.quadTree(); log({ at: r.p, after: 'rvmat layer index' });
  r.lzo(mapX * mapY); log({ at: r.p, after: 'random clutter' });
  r.lzo(mapX * mapY); log({ at: r.p, after: 'compressed bytes 1' });
  const elevation = r.lzo(mapX * mapY * 4); log({ at: r.p, after: 'elevation' });
  if (opts.elevationOnly) return {version,layerX,layerY,mapX,mapY,cell,worldSize:layerX*cell,elevation};
  const nRvmats = r.u32(); if (nRvmats > 1e6) throw Error('rvmats ' + nRvmats);
  for (let i = 0; i < nRvmats; i++) { r.str(); r.str(); }
  log({ nRvmats, at: r.p });
  const nModels = r.u32(); if (nModels > 1e6) throw Error('models ' + nModels);
  const models = []; for (let i = 0; i < nModels; i++) models.push(r.str());
  log({ nModels, first: models.slice(0, 3), at: r.p });
  const nEnt = r.u32(); if (nEnt > 1e7) throw Error('entities ' + nEnt);
  for (let i = 0; i < nEnt; i++) { r.str(); r.str(); r.skip(16); }
  log({ nEnt, at: r.p });
  r.quadTree(); const sizeObjects = r.u32(); r.quadTree(); const sizeMapInfo = r.u32();
  log({ sizeObjects, sizeMapInfo, at: r.p });
  r.lzo(layerX * layerY); r.lzo(mapX * mapY);
  const maxObjectId = r.u32(), roadnetSize = r.u32(); log({ maxObjectId, roadnetSize, at: r.p });
  const roads = [], roadStart = r.p;
  /* per layer cell: u32 parts; part = u16 n, n×XYZ, n×u8 type, u32 id, asciiz model, 4x3 transform */
  for (let i = 0; i < layerX * layerY; i++) {
    const parts = r.u32(); if (parts > 100000) throw Error('roadnet parts ' + parts + ' at cell ' + i);
    for (let j = 0; j < parts; j++) {
      const n = r.u16(); if (n > 64) throw Error('road positions ' + n + ' at ' + r.p);
      const pts = []; for (let k = 0; k < n; k++) pts.push([r.f32(), r.f32(), r.f32()]);
      const types = []; for (let k = 0; k < n; k++) types.push(r.u8());
      const id = r.u32(), model = r.str(); const m = []; for (let k = 0; k < 12; k++) m.push(r.f32());
      roads.push({ pts, types, id, model, m });
    }
  }
  if (r.p - roadStart !== roadnetSize) throw Error('roadnet size mismatch: read ' + (r.p - roadStart) + ' of ' + roadnetSize);
  log({ roads: roads.length, at: r.p });
  const count = sizeObjects / 60; if (!Number.isInteger(count)) throw Error('object block size ' + sizeObjects);
  /* opts.objects === false: skip the per-object array (2.3 M objects on Australia) when only map info is needed */
  if (opts.objects === false) { r.skip(sizeObjects); const mapInfo = parseMapInfo(buf, r.p); log({ mapInfo: mapInfo.length }); return { version, layerX, layerY, mapX, mapY, cell, worldSize: layerX * cell, models, objects: [], roads, mapInfo }; }
  const objects = new Array(count);
  for (let i = 0; i < count; i++) { const id = r.u32(), model = r.u32(); const m = []; for (let k = 0; k < 12; k++) m.push(r.f32()); r.skip(4); if (model >= models.length) throw Error('object model index ' + model); objects[i] = { id, model, m }; }
  log({ objects: count, at: r.p, left: buf.length - r.p });
  const mapInfo = parseMapInfo(buf, r.p);
  log({ mapInfo: mapInfo.length });
  return { version, layerX, layerY, mapX, mapY, cell, worldSize: layerX * cell, models, objects, roads, elevation, mapInfo };
}

/* MapInfo = what the in-game map draws. Record sizes after the u32 type were
 * established on Australia (31 312 465 bytes parsed to the exact end); an
 * unknown type stops with an error instead of misreading the rest. Types follow
 * the engine map classes (0 tree, 1 small tree, 2 bush, 3 building, 4 house,
 * 8 church, 9 chapel, 11 rock, 12 bunker, 18 fuel station, 19 hospital,
 * 20 fence, 21 wall, 24 road, 25 forest, 28 ruin, 31 track, 32 main road,
 * 34 power line, 35 railway …). */
const MAPINFO_SIZE = { 41: 24, 42: 24, 43: 24, 0: 12, 1: 12, 2: 12, 10: 12, 11: 12, 12: 12, 13: 12, 14: 12, 15: 12, 16: 12, 17: 12, 22: 12, 23: 12, 26: 12, 27: 12, 30: 12, 25: 24, 33: 24, 34: 20, 35: 29, 24: 36, 31: 36, 32: 36, 3: 40, 4: 40, 5: 40, 6: 40, 7: 40, 8: 40, 9: 40, 18: 40, 19: 40, 20: 40, 21: 40, 28: 40, 29: 40, 36: 40, 37: 40, 38: 40, 39: 40 };
function parseMapInfo(buf, start) {
  const out = []; let p = start;
  while (p < buf.length) {
    const type = buf.readUInt32LE(p), size = MAPINFO_SIZE[type];
    if (size === undefined) throw Error('unknown map-info type ' + type + ' at +' + (p - start));
    const id = buf.readUInt32LE(p + 4), f = i => buf.readFloatLE(p + 8 + i * 4);
    if (size === 12) out.push({ type, id, pts: [[f(0), f(1)]] });
    else if (size === 20) out.push({ type, id, pts: [[f(0), f(1)], [f(2), f(3)]] });
    else if (size === 29) out.push({ type, id, pts: [[f(0), f(1)], [f(2), f(3)], [f(4), f(5)]] });
    else if (size === 36 || size === 40) out.push({ type, id, pts: [[f(0), f(1)], [f(2), f(3)], [f(4), f(5)], [f(6), f(7)]], color: size === 40 ? buf.readUInt32LE(p + 40) : 0 });
    p += 4 + size;
  }
  if (p !== buf.length) throw Error('map-info overrun');
  return out;
}

module.exports = { loadWrp, parse, parseMapInfo, lzo1x, lzss };
if (require.main === module) {
  const [pbo, virtual] = process.argv.slice(2);
  const t = Date.now(); const buf = loadWrp(pbo, virtual); console.log('loaded', buf.length, Date.now() - t, 'ms');
  const w = parse(buf, x => console.log(JSON.stringify(x)));
  console.log('done', Date.now() - t, 'ms');
}
