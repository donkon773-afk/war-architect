'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),cp=require('node:child_process');
const editor=require('../control-center/warlords-editor'),schema=require('../control-center/scenario-design'),packages=require('../control-center/addon-package'),parser=require('../tools/validate-mission');
const temp=()=>fs.mkdtempSync(path.join(os.tmpdir(),'nero-editor-'));
test('vanilla preset card identifies standard AI and does not advertise the unused model',()=>{
  const html=fs.readFileSync('control-center/index.html','utf8'),fn=html.slice(html.indexOf('function renderPresets()'),html.indexOf('function applyPreset('));
  const element=()=>({value:'',children:[],classList:{toggle(){}},append(...x){this.children.push(...x);},replaceChildren(...x){this.children=x;}}),elements=new Map(),by=id=>{if(!elements.has(id))elements.set(id,element());return elements.get(id);};
  const context={state:{presets:{Vanilla:{scenario:'warlords',map:'Australia',mode:'vanilla',vanillaLambs:true,primaryModel:'UNUSED_PRIVATE_MODEL',primaryNode:'test'}},nodes:[{id:'test',label:'UNUSED_NODE'}]},by,document:{createElement:element},viewedPreset:'',applyPreset(){},overwritePreset(){},removePreset(){},message(){}};
  require('node:vm').runInNewContext(fn+';renderPresets();',context);
  const card=by('presetList').children[0],text=card.children.map(e=>e.textContent||'').join(' ');assert(text.includes('Штатный ИИ Arma · LAMBS'));assert(!text.includes('UNUSED_PRIVATE_MODEL'));assert(!text.includes('Одна LLM'));assert(!text.includes('UNUSED_NODE'));
});
test('collapsed mod catalogs create rows on demand and retain green selections after filtering',()=>{
  const html=fs.readFileSync('control-center/index.html','utf8'),fn=html.slice(html.indexOf('function equipmentModOptions()'),html.indexOf('function filterAssets()'));
  const element=()=>({value:'',children:[],dataset:{},open:false,append(...x){this.children.push(...x);},replaceChildren(...x){this.children=x;},querySelectorAll(){return this.children;}}),elements=new Map(),by=id=>{if(!elements.has(id))elements.set(id,element());return elements.get(id);};by('assetShow').value='all';
  const context={by,document:{createElement:element},catalog:{mods:[{name:'@Green'}],assets:[{class:'GreenTank',label:'Green tank',mod:'@Green',kind:'TANK',side:2}]},armySelected:{west:new Set(),east:new Set(),green:new Set()},modOpen:new Map(),modPages:new Map(),dirty:false,options(select,entries){select.children=entries;}};
  require('node:vm').runInNewContext(fn+';renderAssets();',context);let group=by('greenAssets').children[0],rows=group.children[1];assert.equal(rows.children.length,0);
  group.open=true;group.ontoggle();assert.equal(rows.children.length,1);const checkbox=rows.children[0].children[0];checkbox.checked=true;checkbox.onchange();assert(context.armySelected.green.has('GreenTank'));
  by('assetShow').value='selected';context.renderAssets();group=by('greenAssets').children[0];rows=group.children[1];assert.equal(rows.children.length,1);assert(rows.children[0].children[0].checked);
});
test('green armies validate their faction and equipment, rejecting red equipment',()=>{
  const army=editor.defaults(),green=editor.inventory().assets.find(a=>a.side===2&&a.kind==='TANK');assert(green);army.greenAssets=[green.class];assert.equal(editor.validate(army).greenAssets[0],green.class);
  assert.throws(()=>editor.validate({...army,greenAssets:[army.eastAssets[0]]}),/неверную сторону/);
  assert.throws(()=>editor.validate({...army,greenFaction:army.eastFaction}),/фракцию/);
  assert(editor.mods(army).includes(green.modPath));
});
test('third side generated shop contains exactly the selected green equipment, including naval',()=>{
  const dir=temp();try{
    const inv=editor.inventory().assets,army=editor.defaults(),tank=inv.find(a=>a.side===2&&a.kind==='TANK'),ship=inv.find(a=>a.side===2&&a.kind==='SHIP');assert(tank&&ship);army.greenAssets=[tank.class,ship.class];
    const d=schema.blank('Australia');d.mode='three';d.playerSide='GUER';d.greenFaction=army.greenFaction;d.bases.push({id:'green',name:'Green',side:'GUER',position:[20000,20000],radius:200});d.sectors.push({id:'town',name:'Town',side:'GUER',position:[12000,16000],radius:250,infantry:12,vehicles:0,vehicleClasses:[]});d.army=army;
    const validated=schema.validate(d);assert.equal(validated.army.greenFaction,validated.greenFaction);
    require('../tools/build-three-mission').build(validated,{army,commanders:10,parameters:{}},dir,require('../tools/build-designed-mission').designConfig(validated),editor.mods(army));
    const p=parser.parseConfig(fs.readFileSync(path.join(dir,'neroDesign/preset.hpp'),'utf8')).classes.CfgWLRequisitionPresets.classes.NeroWL_RHSStart.classes.GUER.classes;
    assert.deepEqual(Object.keys(p.Vehicles.classes),[tank.class]);assert.deepEqual(Object.keys(p.Naval.classes),[ship.class]);assert.equal(Object.keys(p.Aircraft.classes).length,0);assert(Object.keys(p.Infantry.classes).length>0);
    assert.equal(parser.validateDirectory(dir).slots,30);
  }finally{fs.rmSync(dir,{recursive:true,force:true});}
});
test('map presets round-trip three armies and reject a stale editor revision',()=>{
  const dir=temp();try{const d=schema.blank('Australia');d.sectors=[{id:'town',name:'Town',side:'GUER',position:[10000,10000],radius:250,infantry:12,vehicles:0,vehicleClasses:[]}];d.army=editor.validate(editor.defaults());d.army.greenAssets=[editor.inventory().assets.find(a=>a.side===2&&a.kind==='TANK').class];
    const store=require('../control-center/map-presets').createStore(dir,{...schema,load:()=>schema.blank('Australia')});const r=store.save('Three armies',d,[]),saved=store.get(r.id);assert.deepEqual(saved.design.army,d.army);store.update(r.id,{revision:r.revision,name:'Renamed'},[]);assert.throws(()=>store.update(r.id,{revision:r.revision,design:d},[]),/другом окне/);
  }finally{fs.rmSync(dir,{recursive:true,force:true});}
});
test('installed status checks the selected scenario, with different addon names and paths',()=>{
  const dir=temp();try{const core={projects:{warlords:path.join(dir,'W'),antistasi:path.join(dir,'A')},read:()=>({armaRoot:path.join(dir,'game')})};
    for(const s of ['warlords','antistasi']){const a=packages.descriptor(s,core);for(const f of [a.candidate,a.installed]){fs.mkdirSync(path.dirname(f),{recursive:true});fs.writeFileSync(f,s);}}
    assert(packages.installed('antistasi',core));fs.writeFileSync(packages.descriptor('warlords',core).installed,'old W');assert(!packages.installed('warlords',core));assert(packages.installed('antistasi',core));assert.throws(()=>packages.descriptor('../bad',core));
  }finally{fs.rmSync(dir,{recursive:true,force:true});}
});
test('real PowerShell installer backs up and installs either scenario; failed verification keeps old addon',()=>{
  const source=fs.readFileSync('control-center/launch.ps1','utf8'),block=source.slice(source.indexOf('$addonSourceName=if'),source.indexOf('# Stop only known bridge'));
  const shell=[process.env.NEROAI_PWSH,'C:/Program Files/PowerShell/7/pwsh.exe',path.join(process.env.USERPROFILE,'.cache/codex-runtimes/codex-primary-runtime/dependencies/native/powershell/pwsh.exe')].find(p=>p&&fs.existsSync(p));assert(shell);
  const quote=v=>"'"+v.replaceAll("'","''")+"'";
  for(const [scenario,name,prefix] of [['warlords','NeroWL.pbo','NeroWL'],['antistasi','NeroAI5.pbo','NeroAI5']])for(const fail of [false,true]){
    const dir=temp();try{const project=path.join(dir,'project'),game=path.join(dir,'game'),mod=path.join(game,scenario),installed=path.join(mod,'addons',name);for(const d of ['tools','dist/candidate',scenario==='antistasi'?'addons/NeroAI5':'addons/NeroAI3'])fs.mkdirSync(path.join(project,d),{recursive:true});fs.mkdirSync(path.dirname(installed),{recursive:true});fs.writeFileSync(installed,'old');fs.writeFileSync(path.join(project,'dist/candidate',name),'new');fs.writeFileSync(path.join(project,'tools/verify-pbo.js'),"if(!require('fs').existsSync(process.argv[3]))process.exit(2);process.exit("+Number(fail)+')');
      const script=path.join(dir,'install.ps1');fs.writeFileSync(script,"$ErrorActionPreference='Stop'\n"+`$projectPath=${quote(project)}\n$armaRoot=${quote(game)}\n$addonMod=${quote(mod)}\n$addonName=${quote(name)}\n$addonPrefix=${quote(prefix)}\n$node=${quote(process.execPath)}\n$request=@{scenario=${quote(scenario)};missionFiles=@()}\n`+block);
      if(fail){assert.throws(()=>cp.execFileSync(shell,['-NoProfile','-File',script],{windowsHide:true,stdio:'pipe'}));assert.equal(fs.readFileSync(installed,'utf8'),'old');}
      else{cp.execFileSync(shell,['-NoProfile','-File',script],{windowsHide:true,stdio:'pipe'});assert.equal(fs.readFileSync(installed,'utf8'),'new');const backups=fs.readdirSync(path.join(project,'backups'));assert.equal(backups.length,1);assert.equal(fs.readFileSync(path.join(project,'backups',backups[0],name),'utf8'),'old');}
    }finally{fs.rmSync(dir,{recursive:true,force:true});}
  }
});
