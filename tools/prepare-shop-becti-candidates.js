'use strict';
// Build reviewable artifacts and new scenario copies. Never installs or launches the game.
const fs=require('fs'),path=require('path'),crypto=require('crypto');
async function main(){
 const root=path.resolve(__dirname,'..'),dir=path.join(root,'dist/candidate/shop-becti-20261017');fs.mkdirSync(dir,{recursive:true});
 const inventory=require('../control-center/campaign-equipment'),old=JSON.parse(fs.readFileSync(path.join(root,'docs/behavior-incident-20261017/mission-design.json'),'utf8'));
 const campaign={...old,campaignKey:crypto.randomUUID(),title:'War Architect — Australia: магазин и AI 17.10',sides:old.sides.map(a=>({...a,...inventory.completeLoadout(a)}))};
 const becti=require('../control-center/becti').defaults('Australia');becti.title='War Architect — BECTI Australia · испытания';becti.sides=becti.sides.map(a=>({...a,...inventory.completeLoadout(a)}));
 const result={date:new Date().toISOString(),installed:false,gameTested:false,artifacts:[],scenarios:[]};
 for(const d of [campaign,becti]){
  console.log('Building '+d.type);const artifact=await require('../control-center/operation-build').build(d);
  const record=require('../control-center/operations').save({design:d});result.scenarios.push({id:record.id,type:d.type,title:d.title});result.artifacts.push(artifact);
  console.log(JSON.stringify({type:d.type,pbo:artifact.pbo,hash:artifact.sha256,bytes:artifact.bytes,record:record.id,armies:d.sides.map(a=>({side:a.side,gear:a.gear.length,shop:a.shop.length}))}));
 }
 fs.writeFileSync(path.join(dir,'manifest.json'),JSON.stringify(result,null,2));console.log('Candidate manifest: '+path.join(dir,'manifest.json'));
}
main().catch(e=>{console.error(e);process.exitCode=1;});
