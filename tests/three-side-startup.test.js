'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const schema=require('../control-center/scenario-design'),editor=require('../control-center/warlords-editor'),parser=require('../tools/validate-mission'),generator=require('../tools/build-three-mission'),design=require('../tools/build-designed-mission');
function build(role='commander',side='WEST'){
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'nero-three-start-'));
 const d=schema.blank('btrx_sngt');d.mode='three';d.playerRole=role;d.playerSide=side;d.army=editor.defaults();d.greenFaction=d.army.greenFaction;
 d.bases.push({id:'green',name:'Green',side:'GUER',position:[3000,4000],radius:200});
 d.sectors=[{id:'capture',name:'Capture',side:'GUER',position:[9000,9000],radius:250,infantry:12,vehicles:0,vehicleClasses:[]}];
 generator.build(d,{army:d.army,commanders:10,parameters:{}},dir,design.designConfig(d));
 return {dir,sqm:fs.readFileSync(path.join(dir,'mission.sqm'),'utf8'),desc:fs.readFileSync(path.join(dir,'description.ext'),'utf8')};
}
test('Sanagasta three-side mission declares its terrain and multiplayer metadata before entering the lobby',()=>{
 const r=build();try{
  const root=parser.parseConfig(r.sqm);assert.equal(root.classes.ScenarioData.classes.Header.values.maxPlayers,30);assert.equal(root.classes.ScenarioData.values.gameType,'CTI');assert(root.values.addons.includes('btrx_sngt'));assert.equal(root.values.sourceName,'NeroAI_Designed_btrx_sngt_Three');assert.equal(parser.validateDirectory(r.dir).slots,30);
  const old=r.sqm.replace(/class ScenarioData[^\n]+\n/,'');assert.notEqual(old,r.sqm);assert.throws(()=>parser.validateMission(old,r.desc),/multiplayer metadata/);
  assert.throws(()=>parser.validateMission(r.sqm.replace('maxPlayers=30','maxPlayers=29'),r.desc),/multiplayer metadata/);
 }finally{fs.rmSync(r.dir,{recursive:true,force:true});}
});
test('each combat side has one playable default player and the observer has a separate civilian slot',()=>{
 for(const [role,side,count] of [['commander','WEST',30],['commander','EAST',30],['commander','GUER',30],['observer','WEST',31]]){
  const r=build(role,side);try{
   const result=parser.validateDirectory(r.dir);assert.equal(result.slots,count);
   const groups=Object.values(parser.parseConfig(r.sqm).classes.Mission.classes.Entities.classes),players=groups.flatMap(g=>Object.values(g.classes.Entities.classes)).filter(u=>u.classes.Attributes.values.isPlayer===1);
   assert.equal(players.length,1);assert.equal(players[0].values.side,role==='observer'?'Civilian':{WEST:'West',EAST:'East',GUER:'Independent'}[side]);
   assert.throws(()=>parser.validateMission(r.sqm.replace('isPlayer=1;',''),r.desc),/default player/);
  }finally{fs.rmSync(r.dir,{recursive:true,force:true});}
 }
});
