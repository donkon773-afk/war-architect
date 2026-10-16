'use strict';
/* Read installed config metadata without starting Arma or changing its files. */
const fs=require('node:fs'),path=require('node:path');
const {readEntry}=require('./read-pbo-entry'),{decodeRap}=require('./read-world-config');
const root=path.resolve(__dirname,'..');
function collect(catalog){
  const launch=JSON.parse(fs.readFileSync(path.join(__dirname,'warlords-launch.json'),'utf8').replace(/^\uFEFF/,''));
  const registry=new Map(),errors=[],sources=[];
  const base=path.join(launch.armaRoot,'Addons');
  const baseNames=['characters_f','characters_f_beta','characters_f_gamma','air_f','air_f_beta','air_f_gamma','air_f_epb','air_f_epc','soft_f','soft_f_beta','soft_f_gamma','armor_f','armor_f_beta','armor_f_gamma','boat_f','boat_f_beta','boat_f_gamma','static_f','static_f_beta','static_f_gamma','weapons_f'];
  const files=baseNames.map(n=>path.join(base,n+'.pbo'));
  for(const mod of catalog.mods){const dir=path.join(mod.path,'addons');if(fs.existsSync(dir))files.push(...fs.readdirSync(dir).filter(n=>n.toLowerCase().endsWith('.pbo')).map(n=>path.join(dir,n)));}
  for(const file of files){
    try{
      const cfg=decodeRap(readEntry(file,'config.bin'));
      sources.push({file,mtime:fs.statSync(file).mtime.toISOString()});
      for(const [id,node] of Object.entries(cfg.classes.CfgVehicles?.classes||{})){
        const key=id.toLowerCase(),old=registry.get(key);
        registry.set(key,{id,parent:node.parent||old?.parent||'',values:{...old?.values,...node.values},source:file});
      }
    }catch(e){if(!/Entry missing/.test(e.message))errors.push({file,error:e.message});}
  }
  function chain(id){const rows=[],seen=new Set();let row=registry.get(id.toLowerCase());while(row&&!seen.has(row.id.toLowerCase())){rows.push(row);seen.add(row.id.toLowerCase());row=registry.get(row.parent.toLowerCase());}return rows;}
  const keys=['weapons','magazines','linkedItems','uniformClass','backpack','hiddenSelectionsTextures','simulation','maxSpeed','crew','faction','side','scope','transportSoldier'];
  const assets=catalog.assets.map(a=>{
    const rows=chain(a.class),resolved={};
    for(const key of keys){const r=rows.find(r=>Object.hasOwn(r.values,key));if(r)resolved[key]=r.values[key];}
    return {...a,configPresent:rows.length>0,config:resolved,ancestors:rows.map(r=>r.id),configSource:rows[0]?.source||null};
  });
  return {version:1,checkedAt:new Date().toISOString(),evidence:'installed_config_not_engine',catalogScannedAt:catalog.scannedAt,sources,errors,assets};
}
if(require.main===module){const catalog=JSON.parse(fs.readFileSync(path.join(root,'dist/mod-assets.json'),'utf8'));const result=collect(catalog),out=path.join(root,'dist/faction-preset-config.json');fs.writeFileSync(out,JSON.stringify(result,null,2));console.log(JSON.stringify({out,assets:result.assets.length,sources:result.sources.length,missing:result.assets.filter(a=>!a.configPresent).length,errors:result.errors.length}));}
module.exports={collect};
