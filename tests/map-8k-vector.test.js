'use strict';
// 8.10: street-level maps from the mod files — WRP map info + Terrain Builder
// road shapefiles -> vector layer; 8K overview; crisp vectors in the editor.
const test = require('node:test'), assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path');
const { parseMapInfo } = require('../tools/map-assets/read-wrp');
const { parseShp, parseDbfIds, parseLib } = require('../tools/map-assets/read-roads');

test('map info: houses, road quads, lines and points are read; unknown types stop instead of guessing', () => {
  const recs = [];
  const point = (type, id, x, y) => { const b = Buffer.alloc(16); b.writeUInt32LE(type, 0); b.writeUInt32LE(id, 4); b.writeFloatLE(x, 8); b.writeFloatLE(y, 12); return b; };
  const quad = (type, id, color, pts) => { const b = Buffer.alloc(color === undefined ? 40 : 44); b.writeUInt32LE(type, 0); b.writeUInt32LE(id, 4); pts.flat().forEach((v, i) => b.writeFloatLE(v, 8 + i * 4)); if (color !== undefined) b.writeUInt32LE(color, 40); return b; };
  recs.push(point(22, 1, 10, 20));
  recs.push(quad(4, 2, 0xff666666, [[0, 0], [10, 0], [0, 8], [10, 8]]));   // house
  recs.push(quad(32, 3, undefined, [[0, 0], [25, 0], [0, 7], [25, 7]]));   // main road quad
  const rail = Buffer.alloc(33); rail.writeUInt32LE(35, 0); rail.writeUInt32LE(4, 4); [1, 2, 3, 4, 5, 6].forEach((v, i) => rail.writeFloatLE(v, 8 + i * 4)); recs.push(rail);
  const buf = Buffer.concat(recs);
  const out = parseMapInfo(buf, 0);
  assert.deepEqual(out.map(e => e.type), [22, 4, 32, 35]);
  assert.deepEqual(out[1].pts[3], [10, 8]); assert.equal(out[1].color, 0xff666666);
  assert.equal(out[3].pts.length, 3);
  assert.throws(() => parseMapInfo(Buffer.concat([buf, point(77, 9, 0, 0)]), 0), /unknown map-info type 77/);
});

test('road shapefile, DBF ids and roadslib widths are read', () => {
  // one polyline record with 1 part, 2 points
  const rec = Buffer.alloc(44 + 4 + 32); rec.writeInt32LE(3, 0); rec.writeInt32LE(1, 36); rec.writeInt32LE(2, 40); rec.writeInt32LE(0, 44);
  [[200100, 500], [200150, 540]].forEach(([x, y], i) => { rec.writeDoubleLE(x, 48 + i * 16); rec.writeDoubleLE(y, 56 + i * 16); });
  const head = Buffer.alloc(100); head.writeInt32BE(9994, 0); head.writeInt32LE(3, 32);
  const rh = Buffer.alloc(8); rh.writeInt32BE(1, 0); rh.writeInt32BE(rec.length / 2, 4);
  const shapes = parseShp(Buffer.concat([head, rh, rec]));
  assert.deepEqual(shapes, [[[[200100, 500], [200150, 540]]]]);
  const dbf = Buffer.alloc(32 + 32 + 1 + 1 + 4); dbf.writeUInt32LE(1, 4); dbf.writeUInt16LE(65, 8); dbf.writeUInt16LE(5, 10);
  dbf.write('ID', 32, 'latin1'); dbf[32 + 11] = 0x4e; dbf[32 + 16] = 4; dbf[64] = 0x0d; dbf.write(' ', 65, 'latin1'); dbf.write('   7', 66, 'latin1');
  assert.deepEqual(parseDbfIds(dbf), [7]);
  const lib = parseLib('class RoadTypesLibrary { class Road0007 { width = 10; map = "main road"; }; class Road0008 { width = 4; map = "track"; }; };');
  assert.deepEqual(lib.get(7), { width: 10, kind: 0 }); assert.deepEqual(lib.get(8), { width: 4, kind: 2 });
});

test('built layers exist for the installed maps; Australia matches the measured counts', () => {
  const file = path.join(__dirname, '../control-center/data/map-tiles/Australia/vector.json');
  if (!fs.existsSync(file)) return; // map data is a local build artefact
  const v = JSON.parse(fs.readFileSync(file, 'utf8'));
  assert.equal(v.worldSize, 40960); assert.equal(v.units, 'dm');
  assert.equal(v.counts.house, 26896); assert.equal(v.counts.main, 27055); assert(v.counts.roadline >= 100);
  assert(fs.existsSync(path.join(path.dirname(file), 'overview8k.jpg')));
});

test('editor draws real-width vectors when zoomed in; server serves the 8K overview and the gzip layer', () => {
  const mb = fs.readFileSync('control-center/map-background.js', 'utf8');
  assert.match(mb, /overview8k\.jpg/); assert.match(mb, /function vectorFile\(world\)/);
  const server = fs.readFileSync('control-center/server.js', 'utf8');
  assert(server.includes("url.pathname.startsWith('/map-vector/')")); assert(server.includes('gzipSync'));
  assert(server.includes('build-vector-map.js') && server.includes("render-vector.py'),'overview'"), 'background build also makes the vector layer and the 8K overview');
  const d = fs.readFileSync('control-center/designer.html', 'utf8');
  assert(d.includes('const VECTOR_SPAN=8000')); assert(d.includes("'stroke-width':Math.max(Number(key.split('_')[1])/10"), 'road width in metres');
  assert(d.includes('id="vectorLayer"') && d.includes('id="vectorToggle"'));
});
