'use strict';
/* Crisp street-level map layer straight from the terrain file in the mod PBO:
 * road surfaces, building footprints, walls/fences, railways and power lines
 * exactly as the in-game map draws them (WRP MapInfo; every record is matched
 * to its placed object by ID). Output: data/map-tiles/<world>/vector.json —
 * integer decimetres, a few MB per map, drawn as vectors in the editor so
 * streets stay sharp at any zoom. No game process, no PBO is modified. */
const fs = require('node:fs'), path = require('node:path');
const { loadWrp, parse } = require('./read-wrp');
const { bundle } = require('../extract-map-background');
const { roadLines } = require('./read-roads');

const LAYERS = {
  main: [32], road: [24], track: [31],
  house: [4], building: [3, 8, 9, 18, 19, 28, 29, 36, 37, 38, 39],
  /* point landmarks: x, y, map type (bunker, fortress, fountain, tower, lighthouse, quay, transmitter, stack, water tower) */
  poi: [12, 13, 14, 15, 16, 17, 26, 27, 30],
  wall: [20, 21], rail: [35], power: [34]
};
const layerOf = new Map(Object.entries(LAYERS).flatMap(([name, types]) => types.map(t => [t, name])));

function build(world, log = () => {}) {
  const { wrp } = bundle(world);
  const t0 = Date.now();
  const w = parse(loadWrp(wrp.pbo, wrp.virtual), () => {}, { objects: false });
  const size = w.worldSize, out = Object.fromEntries(Object.keys(LAYERS).map(k => [k, []])), skipped = { outside: 0 };
  for (const e of w.mapInfo) {
    const layer = layerOf.get(e.type); if (!layer) continue;
    if (e.pts.some(([x, y]) => !(x >= -50 && y >= -50 && x <= size + 50 && y <= size + 50))) { skipped.outside++; continue; }
    for (const [x, y] of e.pts) out[layer].push(Math.round(x * 10), Math.round(y * 10));
    if (layer === 'poi') out.poi.push(e.type);
  }
  /* Terrain Builder roads (shapefile): flat [n, widthDm, kind(0 main,1 road,2 track), x1,y1, …] in dm */
  const shp = roadLines(wrp.pbo, wrp.virtual, size); out.roadline = []; let roadlines = 0;
  if (shp) for (const l of shp.lines) { out.roadline.push(l.pts.length, Math.round(l.width * 10), l.kind); for (const [x, y] of l.pts) out.roadline.push(Math.round(x * 10), Math.round(y * 10)); roadlines++; }
  const counts = Object.fromEntries(Object.entries(out).filter(([k]) => k !== 'roadline').map(([k, v]) => [k, v.length / ({ rail: 6, power: 4, poi: 3 }[k] || 8)])); counts.roadline = roadlines;
  log({ world: world.id, worldSize: size, counts, skipped, ms: Date.now() - t0 });
  return { version: 1, world: world.id, worldSize: size, units: 'dm', source: { pbo: path.basename(wrp.pbo), wrp: wrp.virtual, wrpVersion: w.version, roads: shp ? shp.source : null }, counts, layers: out };
}

function write(world, log) {
  const v = build(world, log), dir = path.join(__dirname, '../../control-center/data/map-tiles', world.id);
  fs.mkdirSync(dir, { recursive: true });
  const file = path.join(dir, 'vector.json'), tmp = file + '.tmp';
  fs.writeFileSync(tmp, JSON.stringify(v)); fs.renameSync(tmp, file);
  return { file, bytes: fs.statSync(file).size, counts: v.counts };
}

module.exports = { build, write, LAYERS };
if (require.main === module) {
  const world = require('../../control-center/scenario-design').world(process.argv[2] || 'Australia');
  console.log(JSON.stringify(write(world, x => console.log(JSON.stringify(x)))));
}
