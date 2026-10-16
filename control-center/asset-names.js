"use strict";
const fs=require('node:fs'),path=require('node:path');
let cache,stamp;
function names(){const file=path.join(__dirname,'../dist/asset-names.json');if(!fs.existsSync(file))return {};const now=fs.statSync(file).mtimeMs;if(now!==stamp){stamp=now;cache=JSON.parse(fs.readFileSync(file,'utf8')).strings;}return cache;}
function humanize(id){
 return String(id).replace(/^(?:UK3CB|CUP|RHSUSF|RHS|OFP|TT|JS_JC|HAFM|JCA|TBD|ACE)_/i,'').replace(/^(?:BAF|B|O|I)_/i,'').replace(/^(?:B|O|I|G)_/i,'').replace(/_/g,' ').replace(/\bLogistics\b/gi,'грузовой').replace(/\bPassenger\b/gi,'пассажирский').replace(/\s+/g,' ').trim();
}
function label(asset,override){
 if(override)return override.replace(/\s*\((?:HAFM|TT)\)/g,'').trim();
 let value=asset.label||'';
 if(value.startsWith('$'))value=names()[value.slice(1).toLowerCase()]||'';
 if(!value||value===asset.class||value.startsWith('$'))value=humanize(asset.class);
 return value.replace(/<[^>]*>/g,'').replace(/\s+/g,' ').trim();
}
module.exports={label,humanize};
