'use strict';
// Read-only installed PBO evidence. A config or function is not proof of activation in a running mission.
const fs=require('node:fs'),path=require('node:path'),{indexEntries,readEntry}=require('./read-pbo-entry'),{decodeRap}=require('./read-world-config');
function audit(){const inventory=require('../control-center/warlords-editor').inventory(),publicClasses=new Set(inventory.assets.map(a=>a.class.toLowerCase())),rows=[],scripts=[],errors=[];let pbos=0,configs=0;
 for(const m of inventory.mods){const dir=path.join(m.path,'addons');if(!fs.existsSync(dir))continue;for(const file of fs.readdirSync(dir).filter(f=>/\.pbo$/i.test(f))){const pbo=path.join(dir,file);let entries;try{entries=indexEntries(pbo);pbos++;}catch(e){errors.push({pbo,error:e.message});continue;}
  for(const e of entries){if(/\.sqf$/i.test(e.name)&&(/(aps|shtora|trophy|afganit|drozd|reactive.?armor|reactive.?armour)/i.test(e.name)||/Active Protection|TT Armor/i.test(m.name)))scripts.push({mod:m.name,pbo,entry:e.name});
   if(!/(^|[\\/])config\.(bin|cpp)$/i.test(e.name))continue;configs++;
   try{const bytes=readEntry(pbo,e.name);if(!/HitERA|Explosive_Reactive_Armor|rhs_era|era_hitpoint/i.test(bytes.toString('latin1')))continue;
    if(!/\.bin$/i.test(e.name)){rows.push({mod:m.name,pbo,entry:e.name,textConfig:true,terms:[...new Set(bytes.toString('utf8').match(/HitERA\w*|Explosive_Reactive_Armor|rhs_era\w*/gi)||[])]});continue;}
    const tree=decodeRap(bytes),vehicles=Object.entries(tree.classes).find(([k])=>k.toLowerCase()==='cfgvehicles')?.[1].classes||{};
    for(const [vehicle,node]of Object.entries(vehicles)){const hits=[];function walk(n,parts=[]){for(const [name,c]of Object.entries(n.classes)){if(/^(hit_?era|era_?)/i.test(name)&&parts.at(-1)?.toLowerCase()==='hitpoints')hits.push({path:[...parts,name].join('/'),parent:c.parent,values:c.values});walk(c,[...parts,name]);}}walk(node);if(hits.length)rows.push({mod:m.name,pbo,entry:e.name,vehicle,parent:node.parent,publicClass:publicClasses.has(vehicle.toLowerCase()),hits});}
   }catch(err){errors.push({pbo,entry:e.name,error:err.message});}
  }
 }}return {pbos,configs,errors,eraDefinitions:rows,protectionScripts:scripts};}
if(require.main===module){const d=audit(),out=path.resolve(__dirname,'../docs/ace-protection-audit-2026-10-16/protection-inventory.json');fs.mkdirSync(path.dirname(out),{recursive:true});fs.writeFileSync(out,JSON.stringify(d,null,2));console.log(JSON.stringify({pbos:d.pbos,configs:d.configs,errors:d.errors.length,eraDefinitions:d.eraDefinitions.length,publicERAExamples:d.eraDefinitions.filter(r=>r.publicClass).slice(0,14).map(r=>({mod:r.mod,class:r.vehicle,hits:r.hits.length})),scriptMods:[...new Set(d.protectionScripts.map(r=>r.mod))],out},null,2));}
module.exports={audit};
