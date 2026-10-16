'use strict';
const fs=require('node:fs'),path=require('node:path'),Module=require('node:module');
let s=fs.readFileSync(path.join(__dirname,'audit-air-defense.js'),'utf8').split("const catalog=require('../control-center/campaign-equipment').catalog();")[0];
s=s.replace("const mods=vanilla?[]:JSON.parse(fs.readFileSync(path.join(root,'dist/mod-assets.json'),'utf8')).mods;",`const mods=[];for(const dir of [path.join(arma,'!Workshop'),arma])for(const name of fs.readdirSync(dir).filter(n=>n.startsWith('@')))if(fs.statSync(path.join(dir,name)).isDirectory())mods.push({name,path:path.join(dir,name)});`);
s+=`
const pattern=/iskander|tochka|scud|atacms|prsm|kinzhal|kh47|fateh|9m723|9m79|9p129|mgm.?140|ofp_m57|maz.?543|ballistic/i;
const ammo=[],vehiclesFound=[];
for(const [id,n]of tables.CfgAmmo)if(pattern.test(id+' '+n.values.displayname)){const e=resolved('CfgAmmo',id);ammo.push({class:n.id,parent:n.parent,origin:n.origin,values:e.values,classes:e.classes});}
for(const [id,n]of tables.CfgVehicles)if(pattern.test(id+' '+n.values.displayname)){const e=resolved('CfgVehicles',id);const ts=turrets(e);const weapons=[...(e.values.weapons||[]),...ts.flatMap(t=>t.weapons)];vehiclesFound.push({class:n.id,origin:n.origin,values:e.values,turrets:ts,weapons:weapons.map(w=>({class:w,...resolved('CfgWeapons',w)}))});}
const mags=[];for(const [id,n]of tables.CfgMagazines)if(pattern.test(id+' '+n.values.displayname)||ammo.some(a=>a.class.toLowerCase()===String(n.values.ammo).toLowerCase()))mags.push({class:n.id,...resolved('CfgMagazines',id)});
const out=path.join(root,'docs/ballistic-audit-2026-10-14');fs.mkdirSync(out,{recursive:true});fs.writeFileSync(path.join(out,'inventory.json'),JSON.stringify({date:new Date().toISOString(),configs,mods:mods.length,errors,ammo,vehicles:vehiclesFound,magazines:mags},null,2));console.log(JSON.stringify({configs,ammo:ammo.map(a=>({class:a.class,simulation:a.values.simulation,maxSpeed:a.values.maxspeed,ttl:a.values.timetolive,thrustTime:a.values.thrusttime,artillery:a.values.artillerylock})),vehicles:vehiclesFound.map(v=>({class:v.class,label:v.values.displayname})),magazines:mags.map(m=>({class:m.class,ammo:m.values.ammo,count:m.values.count,initSpeed:m.values.initspeed}))}));
`;
const m=new Module(__filename,module);m.filename=__filename;m.paths=module.paths;m._compile(s,__filename);
