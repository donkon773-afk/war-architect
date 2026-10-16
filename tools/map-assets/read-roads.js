'use strict';
/* Roads of Terrain Builder maps (Arma 3, CUP 2.x): the engine builds the road
 * network at load time from <terrain>/data/roads/roads.shp + roads.dbf (road ID)
 * + roadslib.cfg (width in metres, map class). Read them read-only from the map
 * PBO or the game's map_*_data.pbo. Output: polylines with real road width. */
const fs = require('node:fs'), path = require('node:path');
const { indexEntries, expandLzss } = require('../read-pbo-entry');

const GAME = 'H:/SteamLibrary/steamapps/common/Arma 3';
function candidatePbos(wrpPbo) {
  const dirs = [path.dirname(wrpPbo), ...['Addons', 'Enoch/Addons', 'Expansion/Addons', 'Heli/Addons', 'Jets/Addons', 'Tank/Addons'].map(d => path.join(GAME, d))];
  return [...new Set(dirs)].filter(d => fs.existsSync(d)).flatMap(d => fs.readdirSync(d).filter(f => f.toLowerCase().endsWith('.pbo')).map(f => path.join(d, f)));
}
function read(e) { const b = Buffer.alloc(e.size); const fd = fs.openSync(e.pbo, 'r'); try { fs.readSync(fd, b, 0, e.size, e.offset); } finally { fs.closeSync(fd); } return e.packing === 0x43707273 ? expandLzss(b, e.original) : b; }

function findRoadFiles(wrpPbo, wrpVirtual) {
  const dir = wrpVirtual.slice(0, wrpVirtual.lastIndexOf('/')).toLowerCase() + '/data/roads/';
  const want = { shp: dir + 'roads.shp', dbf: dir + 'roads.dbf', lib: dir + 'roadslib.cfg' }, found = {};
  for (const pbo of [wrpPbo, ...candidatePbos(wrpPbo).filter(p => p !== wrpPbo)]) {
    let entries; try { entries = indexEntries(pbo); } catch { continue; }
    for (const e of entries) for (const [k, v] of Object.entries(want)) if (!found[k] && e.virtual.toLowerCase() === v) found[k] = { ...e, pbo };
    if (found.shp && found.dbf && found.lib) break;
  }
  return found.shp && found.dbf ? found : null;
}

function parseShp(b) {
  if (b.readInt32BE(0) !== 9994) throw Error('not a shapefile');
  const type = b.readInt32LE(32); if (type !== 3 && type !== 13 && type !== 23) throw Error('roads.shp is not polylines (type ' + type + ')');
  const out = []; let p = 100;
  while (p + 8 <= b.length) {
    const len = b.readInt32BE(p + 4) * 2, rec = p + 8; p = rec + len;
    if (b.readInt32LE(rec) === 0) { out.push(null); continue; }
    const nParts = b.readInt32LE(rec + 36), nPts = b.readInt32LE(rec + 40), parts = [];
    for (let i = 0; i < nParts; i++) parts.push(b.readInt32LE(rec + 44 + i * 4));
    const pts = rec + 44 + nParts * 4, lines = [];
    for (let i = 0; i < nParts; i++) { const a = parts[i], z = i + 1 < nParts ? parts[i + 1] : nPts, line = []; for (let k = a; k < z; k++) line.push([b.readDoubleLE(pts + k * 16), b.readDoubleLE(pts + k * 16 + 8)]); lines.push(line); }
    out.push(lines);
  }
  return out;
}

function parseDbfIds(b) {
  const n = b.readUInt32LE(4), headerLen = b.readUInt16LE(8), recLen = b.readUInt16LE(10), fields = []; let off = 1;
  for (let p = 32; p < headerLen - 1 && b[p] !== 0x0d; p += 32) { const name = b.toString('latin1', p, p + 11).replace(/\0.*$/, '').trim(); const len = b[p + 16]; fields.push({ name, off, len }); off += len; }
  const f = fields.find(x => x.name.toUpperCase() === 'ID'); if (!f) throw Error('roads.dbf has no ID field');
  const ids = []; for (let i = 0; i < n; i++) { const r = headerLen + i * recLen; ids.push(parseInt(b.toString('latin1', r + f.off, r + f.off + f.len).trim(), 10)); }
  return ids;
}

function parseLib(text) {
  const lib = new Map();
  for (const m of text.matchAll(/class\s+Road0*(\d+)\s*\{([\s\S]*?)\};/gi)) {
    const width = parseFloat((m[2].match(/\bwidth\s*=\s*([\d.]+)/i) || [])[1]); const map = ((m[2].match(/\bmap\s*=\s*"([^"]*)"/i) || [])[1] || '').toLowerCase();
    lib.set(Number(m[1]), { width: Number.isFinite(width) ? width : 6, kind: /main|highway/.test(map) ? 0 : /track|trail|path/.test(map) ? 2 : 1 });
  }
  return lib;
}

/* -> { lines: [{kind, width, pts:[[x,y]...]}], source } or null when the map has no shapefile roads */
function roadLines(wrpPbo, wrpVirtual, worldSize) {
  const f = findRoadFiles(wrpPbo, wrpVirtual); if (!f) return null;
  const shapes = parseShp(read(f.shp)), ids = parseDbfIds(read(f.dbf)), lib = f.lib ? parseLib(read(f.lib).toString('latin1')) : new Map();
  if (shapes.length !== ids.length) throw Error(`roads.shp/.dbf record count differs (${shapes.length}/${ids.length})`);
  let minX = Infinity; for (const s of shapes) if (s) for (const l of s) for (const [x] of l) minX = Math.min(minX, x);
  const dx = minX > worldSize ? 200000 : 0; /* Terrain Builder easting offset */
  const lines = [];
  shapes.forEach((s, i) => { if (!s) return; const t = lib.get(ids[i]) || { width: 6, kind: 1 }; for (const l of s) if (l.length > 1) lines.push({ kind: t.kind, width: t.width, pts: l.map(([x, y]) => [x - dx, y]) }); });
  return { lines, source: { shp: path.basename(f.shp.pbo) + ':' + f.shp.virtual, offsetX: dx, types: lib.size } };
}

module.exports = { roadLines, parseShp, parseDbfIds, parseLib, findRoadFiles };
