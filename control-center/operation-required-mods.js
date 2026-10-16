'use strict';
const fs=require('node:fs'),path=require('node:path'),policy=require('./operation-mod-policy');
function resolve(design,inventory=require('./warlords-editor').inventory()){
 const rows=policy.requirements(design,inventory.mods);
 for(const r of rows.filter(r=>!r.generated)){
  if(!r.id)throw Error('Не установлен обязательный мод: '+r.label+'. Нужен для: '+r.reason+'.');
  let files;try{if(!fs.statSync(r.id).isDirectory())throw Error();files=fs.readdirSync(path.join(r.id,'addons'));}catch{throw Error('Недоступен обязательный мод: '+r.label+' ('+r.id+').');}
  for(const file of r.files){const actual=files.find(f=>f.toLowerCase()===file.toLowerCase());if(!actual||!fs.statSync(path.join(r.id,'addons',actual)).isFile())throw Error('Обязательный мод '+r.label+' неполный: отсутствует addons/'+file+'. Проверьте файлы мода в Steam.');}
 }
 return rows;
}
function verifyArtifact(artifact){
 const designFile=path.join(artifact.output,'operation.json');if(!fs.existsSync(designFile))throw Error('Не найдены настройки сборки. Пересоберите миссию перед запуском.');
 const design=JSON.parse(fs.readFileSync(designFile,'utf8')),required=resolve(design),mods=new Set(artifact.extraMods.map(p=>path.resolve(p).toLowerCase()));
 for(const r of required.filter(r=>!r.generated))if(!mods.has(path.resolve(r.id).toLowerCase()))throw Error('В сборке отсутствует обязательный мод '+r.label+'. Пересоберите миссию.');
 const prefixes={strategic:'NeroStrategic',ad:'NeroAirDefense',missiles:'NeroMissileProfiles'};
 for(const r of required.filter(r=>r.generated))if(!(artifact.addonArtifacts||[]).some(a=>a.prefix===prefixes[r.key]))throw Error('В сборке отсутствует обязательный аддон '+r.label+'. Пересоберите миссию.');
 for(const a of artifact.addonArtifacts||[])if(!mods.has(path.resolve(a.mod).toLowerCase())||!fs.existsSync(a.pbo))throw Error('Отсутствует обязательный аддон механик '+a.prefix+'. Пересоберите миссию.');
 return required;
}
module.exports={resolve,verifyArtifact};
