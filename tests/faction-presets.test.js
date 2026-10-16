'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const builder=require('../tools/build-faction-presets'),editor=require('../control-center/warlords-editor'),storage=require('../control-center/side-setups'),contract=require('../control-center/side-setup-client');
const snapshot=JSON.parse(fs.readFileSync(path.join(__dirname,'../dist/faction-preset-config.json'),'utf8')),pack=builder.generate(snapshot),assets=new Map(snapshot.assets.map(a=>[a.class,a]));
test('every installed infantry faction is covered by valid faction-specific classes',()=>{
  assert.equal(pack.coverage.length,new Set(snapshot.assets.filter(a=>a.kind==='INFANTRY').map(a=>a.faction)).size);
  assert(pack.coverage.every(r=>r.presets.length));assert.equal(pack.issues.length,0);
  for(const p of pack.presets){storage.validate(p.setup);assert(p.setup.infantry.length);assert(p.setup.infantry.every(id=>assets.get(id).faction===p.setup.faction));assert(p.setup.infantry.every(id=>!/protagonist|_vr_|_vr$|juggernaut|unarmed|story_/i.test(id)));}
});
test('SOCOM mobile packages have MGS and ATGM, only American MARSOC infantry and no tracks',()=>{
  for(const camo of ['woodland','desert']){
    const p=pack.presets.find(p=>p.key==='us:socom-mobile:'+camo);
    assert(p.setup.assets.includes('CUP_B_M1128_MGS_'+(camo==='desert'?'Desert':'Woodland')));
    assert(p.setup.assets.includes('rhsusf_stryker_m1134_'+(camo==='desert'?'d':'wd')));
    assert(p.setup.infantry.every(id=>id.startsWith('rhsusf_socom_marsoc_')));
    assert(p.setup.assets.every(id=>!builder.isTracked(assets.get(id))));
    assert(!p.setup.assets.some(id=>/Warrior|Rooikat|Badger|m1a|m113_|bradley/i.test(id)));
    const army=contract.apply(editor.defaults(),p.setup),commander=editor.commander(army,'west');assert(p.setup.infantry.includes(commander));assert(commander.startsWith('rhsusf_socom_marsoc_'));
  }
});
test('British modern/Harrier packages separate eras and preserve their real camouflage and equipment',()=>{
  for(const camo of ['woodland','desert'])for(const era of ['modern','harrier']){
    const p=pack.presets.find(p=>p.key===`uk:${era}:${camo}`);
    assert(p.setup.assets.some(id=>id.includes('Challenger2')));assert(p.setup.assets.some(id=>id.includes('FV510')));assert(p.setup.assets.some(id=>id.includes('Bulldog')));
    assert.equal(p.setup.assets.some(id=>id.includes('F35B')),era==='modern');assert.equal(p.setup.assets.some(id=>id.includes('GR9')),era==='harrier');
    assert(!p.setup.assets.some(id=>builder.camouflage(assets.get(id))===(camo==='desert'?'woodland':'desert')));
    assert(p.setup.infantry.every(id=>id.endsWith(era==='modern'?'_MTP':camo==='desert'?'_DDPM':'_DPM')));
    assert(p.metadata.weapons.some(w=>w.includes('L85')));assert(p.metadata.weapons.some(w=>w.includes('Javelin')));
  }
});
test('native Arma infantry is available instead of being filtered out as modPath-empty',()=>{
  assert(editor.inventory().assets.some(a=>a.class==='B_Soldier_F'));
  const p=pack.presets.find(p=>p.key==='1:BLU_F:base');assert(p.setup.infantry.includes('B_Soldier_F'));assert(p.setup.assets.every(id=>/^B_/.test(id)));
});
test('installation is additive and repeatable; later edits are never overwritten',()=>{
  const parent=fs.realpathSync(os.tmpdir()),dir=fs.mkdtempSync(path.join(parent,'nero-faction-presets-'));
  try{
    const first=builder.install(pack,dir,storage.validate);assert.equal(first.created.length,pack.presets.length);
    const store=storage.createStore(dir),p=pack.presets.find(p=>p.key==='us:socom-mobile:woodland'),old=store.get(p.id);
    const changed=store.save({...old,name:'Мой мобильный пресет',setup:{...old.setup,assets:old.setup.assets.slice(1)}});
    const saved=fs.readFileSync(path.join(dir,p.id+'.json'),'utf8'),again=builder.install(pack,dir,storage.validate);
    assert.equal(again.created.length,0);assert.equal(again.preserved.length,pack.presets.length);assert.equal(fs.readFileSync(path.join(dir,p.id+'.json'),'utf8'),saved);assert.equal(store.get(p.id).revision,changed.revision);
  }finally{
    const resolved=fs.realpathSync(dir);assert.equal(path.dirname(resolved),parent);assert(path.basename(resolved).startsWith('nero-faction-presets-'));fs.rmSync(resolved,{recursive:true,force:true});
  }
});
test('whole pack generates native Warlords requisition config without losing selected infantry',()=>{
  for(const p of pack.presets){const army=contract.apply(editor.defaults(),p.setup),text=editor.preset(army,[p.setup.side]);for(const id of p.setup.infantry)assert(text.includes('class '+id+' '));assert(p.setup.infantry.includes(editor.commander(army,p.setup.side))||p.metadata.combatReady===false);}
});
