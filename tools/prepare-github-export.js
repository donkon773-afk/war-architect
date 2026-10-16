'use strict';
// Create a separate publication tree. Never edits local credentials or live data.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..');
const indexes=new Set(['mod-assets.json','worlds.json','campaign-inventory.json','asset-names.json','faction-preset-config.json']);
function allowed(rel){
 const parts=rel.split('/');
 if(parts.some(p=>['.git','node_modules','__pycache__'].includes(p)))return false;
 if(/^(backups|logs)\//.test(rel)||/^tools\/vendor\//.test(rel)||/^research\/native\//.test(rel))return false;
 if(/^docs\/control-editor-20261011\//.test(rel))return false;
 if(/^dist\//.test(rel))return parts.length===2&&indexes.has(parts[1]);
 if(/^control-center\/logs\//.test(rel)||/^control-center\/data\/runtime\//.test(rel))return false;
 if(/^control-center\/data\/map-tiles\//.test(rel)&&(!/\.json$/i.test(rel)||parts.includes('tiles')))return false;
 if(/^control-center\/data\//.test(rel)&&/(?:profiles\.json$|(?:^|\/)(?:session|operations-session|last-launch|operations-launch|launch-request)|operations-parameters-)/.test(rel))return false;
 if(rel==='bridge/neroai3.config.json')return false;
 if(/(?:^|\/)(?:\.env(?:\..*)?|[^/]*\.(?:pem|key|biprivatekey|pbo|mdmp|bidmp|rpt|log|tap|zip|7z|exe|dll|pyd|pyc))$/i.test(rel))return false;
 // Extracted third-party diagnostic sources are local evidence, not project code.
 if(/^docs\//.test(rel)&&/\.(?:sqf|fsm|cpp|hpp|bin|paa|p3d)$/i.test(rel))return false;
 return true;
}
function prepare(destination){
 const out=path.resolve(destination);if(out===root||out.startsWith(root+path.sep)||fs.existsSync(out))throw Error('Export requires a new directory outside the working project');
 fs.mkdirSync(out,{recursive:true});const copied=[],excluded=[];
 function walk(dir){for(const e of fs.readdirSync(dir,{withFileTypes:true})){const file=path.join(dir,e.name),rel=path.relative(root,file).split(path.sep).join('/');if(e.isSymbolicLink()){excluded.push(rel);continue;}if(e.isDirectory()){if(['backups','logs','.git','node_modules','tools/vendor','research/native','docs/control-editor-20261011','control-center/logs','control-center/data/runtime'].includes(rel)){excluded.push(rel+'/');continue;}walk(file);continue;}if(!allowed(rel)){excluded.push(rel);continue;}const target=path.join(out,rel);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(file,target);copied.push({path:rel,bytes:fs.statSync(file).size});}}
 walk(root);
 fs.writeFileSync(path.join(out,'.gitignore'),`node_modules/\nbackups/\nlogs/\nbridge/neroai3.config.json\ncontrol-center/data/profiles.json\ncontrol-center/data/runtime/\ncontrol-center/data/*session*.json\ncontrol-center/data/*launch*.json\ncontrol-center/data/operations-parameters-*.txt\ncontrol-center/logs/\nresearch/native/\ntools/vendor/\n*.pbo\n*.biprivatekey\n*.mdmp\n*.bidmp\n__pycache__/\n.env\n.env.*\n`);
 const suspicious=[];for(const row of copied){if(!/\.(json|js|md|txt|ps1|ini|html|xml|csv)$/i.test(row.path))continue;const text=fs.readFileSync(path.join(out,row.path),'utf8');for(const match of text.matchAll(/\b(?:gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{30,}|sk-(?:proj-|ant-)?[A-Za-z0-9_-]{20,})|"(?:apiKey|api_key|access_token|password)"\s*:\s*"([^"\r\n]{6,})"/g)){const value=match[1]||match[0];if(!/YOUR_|REPLACE|example|lm-studio|test-|fake|dummy|localhost/i.test(value))suspicious.push(row.path);}}
 if(suspicious.length)throw Error('Publication blocked; inspect possible secrets in: '+[...new Set(suspicious)].join(', '));
 const result={destination:out,files:copied.length,bytes:copied.reduce((n,r)=>n+r.bytes,0),secretsDetected:0,excludedFiles:excluded.length,manifestHash:crypto.createHash('sha256').update(JSON.stringify(copied)).digest('hex')};
 fs.writeFileSync(path.join(out,'PUBLICATION.json'),JSON.stringify({...result,destination:undefined},null,2));return result;
}
if(require.main===module){try{console.log(JSON.stringify(prepare(process.argv[2]),null,2));}catch(e){console.error(e.message);process.exitCode=1;}}
module.exports={prepare,allowed};
