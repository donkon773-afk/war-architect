'use strict';
/* Build the street-level vector layer and the 8K overview for every map that
 * already has a satellite background (control-center/data/map-tiles/<id>).
 * One map failing (an older terrain format) never stops the others. */
const fs = require('node:fs'), path = require('node:path'), { execFileSync } = require('node:child_process');
const tilesRoot = path.join(__dirname, '../../control-center/data/map-tiles');
const only = process.argv.slice(2);
const report = [];
for (const id of fs.readdirSync(tilesRoot).filter(d => fs.existsSync(path.join(tilesRoot, d, 'background.json')) && (!only.length || only.includes(d)))) {
  const t = Date.now();
  try {
    const v = JSON.parse(execFileSync(process.execPath, ['--max-old-space-size=6144', path.join(__dirname, 'build-vector-map.js'), id], { encoding: 'utf8', maxBuffer: 1 << 24 }).trim().split('\n').pop());
    execFileSync('python', [path.join(__dirname, 'render-vector.py'), 'overview', path.join(tilesRoot, id), '8192'], { encoding: 'utf8' });
    report.push({ id, ok: true, mb: +(v.bytes / 1048576).toFixed(1), counts: v.counts, s: Math.round((Date.now() - t) / 1000) });
  } catch (e) {
    report.push({ id, ok: false, error: String(e.stderr || e.message).split('\n').find(l => /Error/.test(l)) || String(e.message).slice(0, 200), s: Math.round((Date.now() - t) / 1000) });
  }
  console.log(JSON.stringify(report.at(-1)));
}
fs.writeFileSync(path.join(tilesRoot, 'vector-build-report.json'), JSON.stringify(report, null, 2));
