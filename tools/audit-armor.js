'use strict';
const fs=require('node:fs'),path=require('node:path'),Module=require('node:module');
let s=fs.readFileSync(path.join(__dirname,'audit-air-defense.js'),'utf8').split("const catalog=require('../control-center/campaign-equipment').catalog();")[0];
s=s.replace("const mods=vanilla?[]:JSON.parse(fs.readFileSync(path.join(root,'dist/mod-assets.json'),'utf8')).mods;",`const mods=[];for(const dir of [path.join(arma,'!Workshop'),arma])for(const name of fs.readdirSync(dir).filter(n=>n.startsWith('@')))if(fs.statSync(path.join(dir,name)).isDirectory())mods.push({name,path:path.join(dir,name)});`);
s+=`
const rows=[];
for(const [id,n] of tables.CfgVehicles){const e=resolved('CfgVehicles',id),v=e.values;if(v.scope!==2||!/tank|apc|ifv|mbt|bmp|bradley|warrior|puma|stryker|cv90|namer|bmd|lav25|aav|m113/i.test(id+' '+v.displayname)||/btr[_ -]?(40|60|70|80|90)|soldier|crew|pilot|wreck/i.test(id+' '+v.displayname))continue;
if(!nested(e,'HitPoints'))continue;
rows.push({class:n.id,origin:n.origin,patches:n.patches,values:pick(v,['displayname','simulation','armor','armorstructural','damageresistance','crewexplosionprotection','explosionshielding','ace_vehicle_damage_enabled','ace_vehicle_damage_hullhitpoint','ace_vehicle_damage_enginehitpoint','ace_vehicle_damage_turrethitpoint']),hitpoints:expand(nested(e,'HitPoints')),eventhandlers:nested(e,'EventHandlers'),ace:Object.fromEntries(Object.entries(v).filter(([k])=>k.startsWith('ace_')||k.startsWith('rhs_')))});}
const out='docs/armor-audit-2026-10-14';fs.mkdirSync(out,{recursive:true});fs.writeFileSync(out+'/inventory.json',JSON.stringify({configs,errors,rows},null,2));console.log(JSON.stringify({configs,errors:errors.length,count:rows.length,samples:rows.filter(r=>/^(B_MBT_01_cannon_F|O_MBT_02_cannon_F|B_APC_Tracked_01_rcws_F|B_APC_Wheeled_01_cannon_F|rhs_t90a_tv|rhsusf_m1a2sep1wd_usarmy|rhs_bmp2_msv|rhsusf_m2a3|CUP_B_MCV80)/i.test(r.class)).map(r=>({class:r.class,values:r.values,ace:r.ace,hitpoints:r.hitpoints}))}));
`;
const m=new Module(__filename,module);m.filename=__filename;m.paths=module.paths;m._compile(s,__filename);