'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),crypto=require('node:crypto');
const storeModule=require('../control-center/side-setups'),editor=require('../control-center/warlords-editor');
test('large side setups round-trip infantry, vehicles and prices beyond old limits',()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'nero-unbounded-'));try{
  const store=storeModule.createStore(dir),ids=Array.from({length:1500},(_,i)=>'Class_'+i),setup={side:'west',faction:'SavedFaction',assets:ids,infantry:ids,infantryCosts:Object.fromEntries(ids.map(id=>[id,175]))};
  const record=store.save({name:'Large setup',setup});assert.deepEqual(store.get(record.id).setup,setup);
  const army=editor.defaults();Object.assign(army,{westFaction:setup.faction,westAssets:ids,westInfantry:ids,westInfantryCosts:setup.infantryCosts});assert.equal(editor.validate(army,{catalog:false}).westAssets.length,1500);
  assert.throws(()=>storeModule.validate({...setup,infantry:['Bad;Class']}),/классов/);
 }finally{fs.rmSync(dir,{recursive:true,force:true});}
});
test('libraries can add records beyond the former 200-record ceiling',()=>{
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'nero-libraries-'));try{
  const setups=path.join(root,'setups'),operations=path.join(root,'operations'),maps=path.join(root,'maps');for(const d of [setups,operations,maps])fs.mkdirSync(d);
  const setup={side:'west',faction:'SavedFaction',assets:[],infantry:[],infantryCosts:{}},design=require('../control-center/operations').defaults(),map=require('../control-center/scenario-design').blank('Australia');
  for(let i=0;i<200;i++){const id=crypto.randomUUID();fs.writeFileSync(path.join(setups,id+'.json'),JSON.stringify({id,name:'Setup '+i,setup,revision:1,updatedAt:'2026-01-01'}));fs.writeFileSync(path.join(operations,id+'.json'),JSON.stringify({id,design,revision:1,updatedAt:'2026-01-01'}));fs.writeFileSync(path.join(maps,id+'.json'),JSON.stringify({id,name:'Map '+i,design:map,revision:1,updatedAt:'2026-01-01'}));}
  assert(storeModule.createStore(setups).save({name:'New setup',setup}).verified);
  assert(require('../control-center/operations').createStore(operations).save({design}).verified);
  assert(require('../control-center/map-presets').createStore(maps).save('New map',map,[]).verified);
 }finally{fs.rmSync(root,{recursive:true,force:true});}
});
test('air catalogs and full faction presets retain every selected installed class',()=>{
 const ops=require('../control-center/operations'),d=ops.defaults(),rows=ops.catalog().filter(c=>c.side==='WEST');assert(rows.length>8);d.sides[0].classes=rows.map(c=>c.class);assert.equal(ops.validate(d).sides[0].classes.length,rows.length);
 const equipment=require('../control-center/campaign-equipment'),f=equipment.factions('WEST').find(f=>f.infantry.length>32);assert(f);assert.deepEqual(equipment.fullArmy('WEST',f.id).classes,f.infantry);
});
test('map drafts retain large point and garrison class collections',()=>{
 const schema=require('../control-center/scenario-design'),d=schema.blank('Australia');
 d.sectors=Array.from({length:80},(_,i)=>({id:'sector_'+i,name:'Sector '+i,side:'GUER',position:[10000+i*100,15000],radius:200,infantry:4,vehicles:0,vehicleClasses:Array.from({length:70},(_,j)=>'Vehicle_'+j)}));
 d.startAssets=Array.from({length:70},(_,i)=>({side:'WEST',class:'Start_'+i,count:1}));
 const result=schema.validate(d,[],{draft:true});assert.equal(result.sectors.length,80);assert.equal(result.sectors[0].vehicleClasses.length,70);assert.equal(result.startAssets.length,70);
});
test('campaign topology accepts more than 64 sectors and 192 valid links',()=>{
 const campaign=require('../control-center/campaign-operations'),d=campaign.defaults(),base=d.sectors.find(s=>s.id===d.sides[0].base),size=require('../control-center/scenario-design').world(d.world).size;
 for(let x=-8;x<=8&&d.sectors.length<70;x++)for(let y=-8;y<=8&&d.sectors.length<70;y++){
  const position=[base.position[0]+x*750,base.position[1]+y*750];
  if(position.some(n=>n<500||n>size-500)||d.sectors.some(s=>Math.hypot(...s.position.map((n,i)=>n-position[i]))<s.radius+200+100))continue;
  const id='Extra_'+d.sectors.length;d.sectors.push({id,name:id,kind:'town',owner:'NONE',position,radius:100,stock:0,income:0});d.links.push([base.id,id]);
 }
 assert.equal(d.sectors.length,70);
 for(const a of d.sectors)for(const b of d.sectors){if(d.links.length>=210)break;if(a.id===b.id||Math.hypot(...a.position.map((n,i)=>n-b.position[i]))>12000||d.links.some(p=>p.includes(a.id)&&p.includes(b.id)))continue;d.links.push([a.id,b.id]);}
 assert.equal(d.links.length,210);assert.equal(campaign.validate(d).sectors.length,70);
});
test('mission generation retains a large selected infantry roster without truncation',()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'nero-large-mission-'));try{
  const campaign=require('../control-center/campaign-operations'),d=campaign.defaults();d.sides[0].faction='';d.sides[0].classes=campaign.catalog().filter(c=>c.side==='WEST').slice(0,600).map(c=>c.class);
  require('../tools/build-campaign-operation').build(d,dir);require('../tools/validate-campaign-operation').validate(dir);
  const stored=JSON.parse(fs.readFileSync(path.join(dir,'operation.json'),'utf8')),config=require('../tools/validate-mission').parseConfig(fs.readFileSync(path.join(dir,'description.ext'),'utf8'));
  assert.deepEqual(stored.sides[0].classes,d.sides[0].classes);assert.deepEqual(config.classes.CfgNeroOperation.classes.WEST.values.classes,d.sides[0].classes);
 }finally{fs.rmSync(dir,{recursive:true,force:true});}
});
