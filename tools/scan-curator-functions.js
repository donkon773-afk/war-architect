'use strict';
const fs=require('node:fs'),path=require('node:path'),{readEntry,indexEntries}=require('./read-pbo-entry'),{decodeRap}=require('./read-world-config');
const launch=JSON.parse(fs.readFileSync(path.join(__dirname,'warlords-launch.json'),'utf8').replace(/^\uFEFF/,'')),dir=path.join(launch.armaRoot,'Curator','Addons'),functions=new Set();
for(const name of fs.readdirSync(dir).filter(n=>/\.pbo$/i.test(n))){const file=path.join(dir,name);for(const e of indexEntries(file).filter(e=>/(^|[\\/])config\.bin$/i.test(e.name))){const cfg=decodeRap(readEntry(file,e.name));for(const [id,tag]of Object.entries(cfg.classes.CfgFunctions?.classes||{})){if(tag.values.tag&&tag.values.tag!=='BIS')continue;for(const category of Object.values(tag.classes))for(const fn of Object.keys(category.classes))functions.add('BIS_fnc_'+fn);}}}
// Particle modules are published by the base game's Modules_F addon. The
// emitter delegates to these functions through persistent BIS_fnc_MP calls.
const effects=path.join(launch.armaRoot,'Addons/modules_f.pbo');
for(const entry of indexEntries(effects).filter(e=>/(^|[\\/])config\.bin$/i.test(e.name))){const cfg=decodeRap(readEntry(effects,entry.name));for(const tag of Object.values(cfg.classes.CfgFunctions?.classes||{}))for(const [category,group]of Object.entries(tag.classes))if(category==='Effects')for(const name of Object.keys(group.classes))functions.add('BIS_fnc_'+name);}
const result={evidence:'installed_BI_Curator_and_base_particle_CfgFunctions',functions:[...functions].sort()};fs.writeFileSync(path.join(__dirname,'../dist/curator-functions.json'),JSON.stringify(result,null,2));console.log(JSON.stringify({nativeCuratorFunctions:result.functions.length}));
