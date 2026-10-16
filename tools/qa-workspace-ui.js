'use strict';
// Browser acceptance against in-memory API fixtures. No game launch, installed
// PBO writes, profile writes, or modifications of the running panel.
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..'),ui=path.join(root,'control-center');
const {chromium}=require(process.env.NEROAI_PLAYWRIGHT||'playwright');
const core=require('../control-center/core'),schema=require('../control-center/scenario-design'),editor=require('../control-center/warlords-editor'),presets=require('../control-center/map-presets');
const out=path.join(root,'dist/ui-review');fs.mkdirSync(out,{recursive:true});
const session='f'.repeat(48),state=structuredClone(core.publicState());
state.selected.map='WINTERURBAN';state.selected.useDesign=true;state.selected.scenario='warlords';state.selected.mode='tactical';
state.job={status:'idle',message:'Готов к настройке.'};state.running=false;
const inventory=editor.inventory(),catalog={...inventory,factionLabels:require('../control-center/faction-names').labels(inventory.factions)};
const worlds=schema.worlds().map(w=>({...w,background:require('../control-center/map-background').metadata(w)}));
const designs=new Map(worlds.map(w=>[w.id,structuredClone(schema.load(w.id))]));
const maps=new Map(presets.list().map(p=>{const full=presets.get(p.id);return [p.id,{...full,inGame:p.inGame}];}));
maps.set('qa-other-map',{id:'qa-other-map',name:'Наступление QA',revision:1,design:{...structuredClone(designs.get('WINTERURBAN')),title:'Наступление QA'}});
state.presets['Запуск QA']={...structuredClone(state.selected),army:{...structuredClone(designs.get('WINTERURBAN').army),westAssets:designs.get('WINTERURBAN').army.westAssets.slice(0,1)}};
const sideStore=require('../control-center/side-setups');
const sides=new Map(sideStore.list().map(s=>[s.id,sideStore.get(s.id)]));
const posts=[],failures={design:false,profile:false};
const operationStore=require('../control-center/operations');
const operationRows=operationStore.list();
const operationsServer=require('../control-center/operations-server').createServer({store:{list:()=>operationRows,get:id=>operationStore.get(id)},builder:{build:()=>{throw Error('Game builds disabled in UI review');}}});
function publicState(){return {...state,updateScenario:state.selected.scenario,updateInstalled:false};}
function canon(value){const d=structuredClone(value);delete d.savedAt;for(const key of ['bases','sectors','spawns'])for(const p of d[key]||[])delete p.type;const sort=v=>Array.isArray(v)?v.map(sort):v&&typeof v==='object'?Object.fromEntries(Object.keys(v).sort().map(k=>[k,sort(v[k])])):v;return JSON.stringify(sort(d));}
function summary(p){return {id:p.id,name:p.name,revision:p.revision,world:p.design.world,title:p.design.title,mode:p.design.mode,bases:p.design.bases.length,sectors:p.design.sectors.length,spawns:p.design.spawns.length,updatedAt:p.updatedAt||new Date().toISOString(),inGame:canon(p.design)===canon(designs.get(p.design.world))};}
const server=http.createServer(async(req,res)=>{try{
 const u=new URL(req.url,'http://localhost');let data;
 if(req.method==='POST'){let raw='';for await(const part of req)raw+=part;data=JSON.parse(raw);posts.push({url:u.pathname,data:structuredClone(data)});}
 const json=(value,code=200)=>{res.writeHead(code,{'Content-Type':'application/json'});res.end(JSON.stringify(value));};
 const sendFile=(file,type)=>{res.writeHead(200,{'Content-Type':type});res.end(fs.readFileSync(file));};
 const docs={'/':'index.html','/designer':'designer.html','/setups':'setups.html'};
 if(docs[u.pathname]){res.writeHead(200,{'Content-Type':'text/html; charset=utf-8'});return res.end(fs.readFileSync(path.join(ui,docs[u.pathname]),'utf8').replace('__SESSION_TOKEN__',session));}
 if(['/side-setup-client.js','/setups.js'].includes(u.pathname))return sendFile(path.join(ui,u.pathname.slice(1)),'text/javascript');
 if(u.pathname==='/api/catalog')return json(catalog);
 if(u.pathname==='/api/worlds')return json(worlds);
 if(u.pathname==='/api/state')return json(publicState());
 if(u.pathname==='/api/scenario-library')return json(require('../control-center/scenario-library').list({maps:[...maps.values()].map(summary),operations:operationRows,state,worlds}));
 if(u.pathname==='/api/operations-panel')return json({origin:'http://127.0.0.1:'+operationsServer.address().port});
 if(u.pathname==='/api/design'){
  if(data){if(failures.design)return json({error:'Тест: сохранение карты недоступно.'},400);const d=schema.validate(data.design,state.nodes,{draft:true});d.savedAt=new Date().toISOString();designs.set(d.world,structuredClone(d));return json(d);}
  return json(designs.get(u.searchParams.get('world')));
 }
 if(u.pathname==='/api/map-presets'){
  if(data){const p={id:'qa-'+Date.now(),name:data.name,design:structuredClone(data.design),revision:1,inGame:false};maps.set(p.id,p);return json({...summary(p),verified:true});}
  return json({presets:[...maps.values()].map(summary),current:[]});
 }
 if(u.pathname==='/api/map-preset')return json(maps.get(u.searchParams.get('id')));
 if(u.pathname==='/api/map-preset-update'){const p=maps.get(data.id);assert.equal(data.revision,p.revision);p.design=structuredClone(data.design);p.revision++;return json({...summary(p),verified:true});}
 if(u.pathname==='/api/map-preset-apply'){const p=maps.get(data.id);designs.set(p.design.world,{...structuredClone(p.design),savedAt:new Date().toISOString()});p.inGame=true;return json(designs.get(p.design.world));}
 if(u.pathname==='/api/save'){if(failures.profile)return json({error:'Тест: запись профиля недоступна.'},400);assert.equal(data.revision,state.revision);state.selected=core.validate(data.selected,state,{draft:true});state.revision++;if(data.name){state.presets[data.name]=state.selected;state.activePreset=data.name;}return json(publicState());}
 if(u.pathname==='/api/launch')return json({job:{status:'done',message:'Тест: сохранено; запуск игры перехвачен.'},revision:state.revision});
 if(u.pathname==='/api/side-setups')return json({setups:[...sides.values()].map(s=>({id:s.id,name:s.name,side:s.setup.side,faction:s.setup.faction,assets:s.setup.assets.length,infantry:s.setup.infantry?.length??'auto'}))});
 if(u.pathname==='/api/side-setup')return json(sides.get(u.searchParams.get('id')));
 if(u.pathname==='/api/journal')return json({bridge:[],engine:[]});
 if(u.pathname.startsWith('/map-vector/')){const id=decodeURIComponent(u.pathname.split('/')[2].replace('.json',''));return sendFile(require('../control-center/map-background').vectorFile(schema.world(id)),'application/json');}
 if(u.pathname.startsWith('/map-background/')){const id=decodeURIComponent(u.pathname.split('/')[2].replace('.jpg',''));return sendFile(require('../control-center/map-background').file(schema.world(id)),'image/jpeg');}
 if(u.pathname.startsWith('/map-tile/')){const [, , id,x,y]=u.pathname.split('/');const f=require('../control-center/map-background').file(schema.world(decodeURIComponent(id)),+x,+y.replace('.jpg',''));if(f&&fs.existsSync(f))return sendFile(f,'image/jpeg');}
 json({error:'Fixture route unavailable: '+u.pathname},404);
 }catch(error){res.writeHead(400,{'Content-Type':'application/json'});res.end(JSON.stringify({error:error.message}));}});
(async()=>{
 await new Promise(r=>server.listen(0,'127.0.0.1',r));
 await new Promise(r=>operationsServer.listen(0,'127.0.0.1',r));
 const browser=await chromium.launch({headless:true,executablePath:process.env.NEROAI_CHROME||'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 const errors=[];const context=await browser.newContext({viewport:{width:1440,height:1050}}),page=await context.newPage();page.on('pageerror',e=>errors.push(e.message));
 let acceptDialogs=true;page.on('dialog',d=>acceptDialogs?d.accept():d.dismiss());
 try{
  await page.goto('http://127.0.0.1:'+server.address().port+'/?tab=launch',{waitUntil:'domcontentloaded'});
  await page.waitForSelector('#editor-title',{timeout:30000});
  assert.equal(await page.evaluate(()=>{const ids=[...document.querySelectorAll('[id]')].map(el=>el.id);return new Set(ids).size===ids.length;}),true);
  await page.locator('#devmodeTab').click();
  assert.equal(await page.locator('#devmodePanel').isVisible(),true);
  await page.locator('#experiment-transportDrop').uncheck();
  await page.locator('#devModeEnabled').uncheck();
  assert.equal(await page.locator('#experiment-fieldRepair').isDisabled(),true);
  assert.equal(await page.locator('#experiment-fieldRepair').isChecked(),true);
  await page.locator('#save').click();await page.waitForFunction(()=>document.getElementById('message').textContent.includes('Сценарий сохранён'));
  assert.equal(state.selected.devMode.enabled,false);assert.equal(state.selected.devMode.features.transportDrop,false);
  await page.reload();await page.waitForSelector('#editor-title',{timeout:30000});
  await page.locator('#devmodeTab').click();assert.equal(await page.locator('#devModeEnabled').isChecked(),false);
  await page.locator('#devModeEnabled').check();assert.equal(await page.locator('#experiment-transportDrop').isChecked(),false);
  assert.equal(await page.locator('#experiment-fieldRepair').isChecked(),true);
  await page.screenshot({path:path.join(out,'devmode-desktop.png'),fullPage:true});
  await page.setViewportSize({width:1280,height:900});assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
  await page.screenshot({path:path.join(out,'devmode-1280.png'),fullPage:true});await page.setViewportSize({width:1440,height:1000});
  await page.locator('#launchTab').click();
  const saveOrderStart=posts.length;
  await page.locator('#editor-title').fill('Городской фронт · QA');await page.locator('#editor-title').dispatchEvent('change');
  await page.locator('[data-setup="rules"]').click();
  await page.locator('#editor-startCP').fill('7500');await page.locator('#editor-startCP').dispatchEvent('change');
  assert.equal(await page.locator('#BIS_WLStartCP').isVisible(),false);
  await page.locator('#editor-startCP').focus();await page.waitForFunction(()=>document.getElementById('settingHelp').textContent.includes('Стартовые очки'));
  await page.locator('#editor-startCP').locator('..').locator('.help-trigger').click();assert((await page.locator('#settingHelp').textContent()).includes('Стартовые очки'));
  const helpLabel=page.locator('#editor-startCP').locator('..');await helpLabel.locator('.context-help-inline').waitFor({state:'visible'});
  assert.equal(await helpLabel.locator('.help-trigger').getAttribute('aria-expanded'),'true');assert((await helpLabel.locator('.context-help-inline').textContent()).includes('Стартовые очки'));
  await page.screenshot({path:path.join(out,'inline-context-help.png'),fullPage:true});
  await helpLabel.locator('.help-trigger').click();assert.equal(await helpLabel.locator('.context-help-inline').isVisible(),false);
  await helpLabel.locator('.help-trigger').click();await page.keyboard.press('Escape');assert.equal(await helpLabel.locator('.context-help-inline').isVisible(),false);
  await page.locator('#save').click();await page.waitForFunction(()=>document.getElementById('message').textContent.includes('Сценарий сохранён'));
  assert.equal(designs.get('WINTERURBAN').startCP,7500);assert.equal(designs.get('WINTERURBAN').title,'Городской фронт · QA');
  assert(posts.slice(saveOrderStart).findIndex(p=>p.url==='/api/design')<posts.slice(saveOrderStart).findIndex(p=>p.url==='/api/save')); 
  await page.locator('[data-setup="vehicles"]').click();await page.locator('#armySetupSide').selectOption('west');await page.locator('#armyClearAll').click();
  const sourceFrame=page.frames().find(f=>f.url().includes('/designer'));await page.waitForFunction(()=>document.getElementById('designerFrame').contentWindow.NeroEditor.snapshot().army.westAssets.length===0);
  await page.locator('#armyUndoClear').click();assert((await sourceFrame.evaluate(()=>NeroEditor.snapshot().army.westAssets.length))>0);
  failures.profile=true;await page.locator('#save').click();await page.waitForFunction(()=>document.getElementById('message').textContent.includes('запись профиля недоступна'));
  assert.equal(await page.locator('#dirtyStatus').textContent(),'Есть изменения');failures.profile=false;
  await page.locator('#save').click();await page.waitForFunction(()=>document.getElementById('message').textContent.includes('Сценарий сохранён'));
  await page.locator('#mapPresetsTab').click();
  const frame=page.frames().find(f=>f.url().includes('/designer'));
  await frame.waitForSelector('#map');await page.screenshot({path:path.join(out,'map-desktop.png'),fullPage:true});
  const before=await frame.evaluate(()=>NeroEditor.snapshot().sectors.length);
  await frame.locator('#sectorTool').click();const rect=await frame.locator('#map').boundingBox();
  await page.mouse.click(rect.x+rect.width*.45,rect.y+rect.height*.53);
  assert.equal(await frame.evaluate(()=>NeroEditor.snapshot().sectors.length),before+1);
  assert.equal(await frame.locator('#tool').inputValue(),'select');
  const original=await frame.evaluate(()=>NeroEditor.snapshot().sectors.at(-1).position);
  await page.mouse.move(rect.x+rect.width*.45,rect.y+rect.height*.53);await page.mouse.down();await page.mouse.move(rect.x+rect.width*.45+35,rect.y+rect.height*.53+25,{steps:5});await page.mouse.up();
  const moved=await frame.evaluate(()=>NeroEditor.snapshot().sectors.at(-1).position);assert.notDeepEqual(moved,original);
  await frame.locator('#undoEdit').click();assert.deepEqual(await frame.evaluate(()=>NeroEditor.snapshot().sectors.at(-1).position),original);
  await page.locator('#launchTab').click();await page.locator('[data-setup="overview"]').click();acceptDialogs=false;
  await page.locator('#map').selectOption('Altis');await page.waitForFunction(()=>document.getElementById('map').value==='WINTERURBAN');acceptDialogs=true;
  assert.equal(await frame.evaluate(()=>NeroEditor.snapshot().sectors.length),before+1);await page.locator('#mapPresetsTab').click();
  // A refused map save must stop both profile saving and launching.
  failures.design=true;const checkpoint=posts.length;
  await page.locator('#launch').click();await page.waitForFunction(()=>document.getElementById('message').textContent.includes('Запуск отменён'));
  assert(!posts.slice(checkpoint).some(p=>['/api/save','/api/launch'].includes(p.url)));
  assert.equal(await page.locator('#dirtyStatus').textContent(),'Есть изменения');failures.design=false;
  await page.locator('#launch').click();await page.waitForFunction(()=>document.getElementById('message').textContent.includes('запуск игры перехвачен'));
  assert.equal(posts.filter(p=>p.url==='/api/launch').length,1);
  // Saving a new named map also selects it for the next game in one command.
  await frame.locator('[data-tab="presets"]').click();await frame.locator('#mapPresetName').fill('Единый сценарий QA');
  await page.locator('#save').click();await page.waitForFunction(()=>document.getElementById('message').textContent.includes('Сценарий сохранён'));
  const created=[...maps.values()].find(p=>p.name==='Единый сценарий QA');assert(summary(created).inGame);assert.equal(state.selected.map,'WINTERURBAN');assert.equal(state.selected.useDesign,true);
  const beforeUseRevision=state.revision;
  await frame.locator('.preset-row').filter({has:frame.locator('strong',{hasText:'Наступление QA'})}).getByRole('button',{name:'Использовать в игре',exact:true}).click();
  await page.waitForFunction(revision=>state.revision>revision&&document.getElementById('editor-title').value==='Наступление QA'&&!document.querySelector('main').inert,beforeUseRevision);
  assert.equal(designs.get('WINTERURBAN').title,'Наступление QA');
  await page.locator('#launchTab').click();await page.locator('[data-setup="overview"]').click();await page.screenshot({path:path.join(out,'scenario-desktop.png'),fullPage:true});
  await page.locator('#preset').selectOption('Запуск QA');await page.locator('#loadPreset').click();
  await page.waitForFunction(()=>document.getElementById('message').textContent.includes('Запуск QA» открыт'));
  assert.equal(await frame.evaluate(()=>NeroEditor.snapshot().army.westAssets.length),1);
  assert.equal(await page.locator('#experiment-transportDrop').isChecked(),true);assert.equal(await page.locator('#devModeEnabled').isChecked(),true);
  await page.locator('#setupsTab').click();await page.waitForFunction(()=>document.getElementById('setupsFrame').contentWindow.location.pathname==='/setups');const setupFrame=page.frames().find(f=>f.url().includes('/setups'));
  await setupFrame.waitForSelector('#setupName');await page.screenshot({path:path.join(out,'setups-desktop.png'),fullPage:true});assert.equal(context.pages().length,1);
  await page.locator('#operationsTab').click();await page.waitForFunction(()=>document.getElementById('operationsFrame').getAttribute('src').includes('/operations?'));
  await page.frameLocator('#operationsFrame').locator('#world option').first().waitFor({state:'attached',timeout:20000});const opsFrame=page.frames().find(f=>f.url().includes('/operations?'));
  await page.screenshot({path:path.join(out,'operations-desktop.png'),fullPage:true});
  assert.equal(await opsFrame.locator('#build').isVisible(),false);
  await opsFrame.locator('a[href="/ground"]').click();await opsFrame.waitForSelector('#world option',{state:'attached',timeout:20000});
  assert(opsFrame.url().includes('/ground'));await opsFrame.locator('a[href="/campaign"]').click();await opsFrame.waitForSelector('#world option',{state:'attached',timeout:20000});assert(opsFrame.url().includes('/campaign'));
  await page.setViewportSize({width:1280,height:800});await page.locator('#mapPresetsTab').click();await page.screenshot({path:path.join(out,'map-1280.png'),fullPage:true});
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
  assert.equal(await frame.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
  assert.equal(errors.length,0,errors.join('\n'));
  await page.locator('#missionsTab').click();await page.waitForFunction(()=>document.querySelectorAll('.mission-card').length>0);
  await page.screenshot({path:path.join(out,'missions-desktop.png'),fullPage:true});
  for(const mode of ['airBattle','assaultDefense','frontlineCampaign']){
    await page.locator('#missionFilter').selectOption(mode);
    const row=operationRows.find(r=>r.type===mode);assert(row,'saved operation fixture exists: '+mode);
    await page.locator('.mission-card').filter({has:page.locator('h3',{hasText:row.title})}).first().getByRole('button',{name:'Открыть сценарий'}).click();
    await page.waitForFunction(id=>document.getElementById('operationsFrame').getAttribute('src').includes('id='+id),row.id);
    const op=page.frameLocator('#operationsFrame');await op.locator('#title').waitFor();await page.waitForFunction(()=>document.getElementById('operationsFrame').getAttribute('src').includes('id='));
    await op.locator('#world option').first().waitFor({state:'attached',timeout:30000});assert.equal(await op.locator('#title').inputValue(),row.title);
    if(mode==='frontlineCampaign'){
      await op.locator('[data-tab="devmode"]').click();assert.equal(await op.locator('#campaignExperiments input').count(),require('../control-center/campaign-experiments').entries.length);
      await op.locator('input[data-experiment="physicalDrop"]').check();await op.locator('input[data-experiment="radarNetwork"]').check();
      assert.equal(await page.frames().find(f=>f.url().includes('/campaign?')).evaluate(()=>draft.devMode.physicalDrop&&draft.devMode.radarNetwork),true);
      await op.locator('input[data-experiment="realisticMissiles"]').check();
      await op.locator('[data-tab="advanced"]').click();await op.getByLabel('Обязательные моды подключать всегда',{exact:true}).waitFor({state:'attached'});assert.equal(await op.getByLabel('Обязательные моды подключать всегда',{exact:true}).isChecked(),true);assert.equal(await op.getByLabel('Обязательные моды подключать всегда',{exact:true}).isDisabled(),true);assert.equal(await op.getByLabel('ACE · обязательно',{exact:true}).isDisabled(),true);assert.equal(await op.getByLabel('Blastcore Murr Edition (TT Version) · обязательно',{exact:true}).isChecked(),true);await op.getByLabel('Включить все дополнительные моды',{exact:true}).check();await op.getByLabel('Включить все дополнительные моды',{exact:true}).uncheck();assert.equal(await op.getByLabel('ACE · обязательно',{exact:true}).isChecked(),true);
      await page.screenshot({path:path.join(out,'required-mods.png'),fullPage:true});await op.locator('[data-tab="devmode"]').click();
      await page.screenshot({path:path.join(out,'campaign-devmode.png'),fullPage:true});await op.locator('[data-tab="main"]').click();
    }
    await page.screenshot({path:path.join(out,'library-'+mode+'.png'),fullPage:true});
    if(mode==='airBattle'){
      await op.locator('#title').fill('UNSAVED QA');await page.locator('#missionsTab').click();await page.locator('#missionFilter').selectOption('assaultDefense');acceptDialogs=false;
      await page.locator('.mission-card').first().getByRole('button',{name:'Открыть сценарий'}).click();
      await page.waitForTimeout(100);assert((await page.locator('#operationsFrame').getAttribute('src')).includes('id='+row.id));acceptDialogs=true;
    }
    await page.locator('#missionsTab').click();
  }
  await page.locator('#missionFilter').selectOption('warlords');await page.locator('#missionSearch').fill('Наступление QA');
  await page.locator('.mission-card').getByRole('button',{name:'Открыть сценарий'}).click();await page.waitForFunction(()=>document.body.dataset.workspaceTab==='maps');
  assert.equal(await frame.evaluate(()=>NeroEditor.snapshot().title),'Наступление QA');
  await page.locator('#missionsTab').click();await page.locator('#missionSearch').fill('');await page.locator('#missionFilter').selectOption('all');
  await page.setViewportSize({width:1280,height:900});assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);await page.screenshot({path:path.join(out,'missions-1280.png'),fullPage:true});
  const landing=await context.newPage();await landing.goto('http://127.0.0.1:'+server.address().port);await landing.locator('.mission-card').first().waitFor();assert.equal(await landing.locator('#missionsPanel').isVisible(),true);await landing.close();
  assert.equal(errors.length,0,errors.join('\n'));
  const report={passed:true,checks:['unified library opens all three saved operation types by id','map library opens the chosen map preset','unsaved operation survives cancelled scenario switch','missions are the default landing page','DevMode master and individual flags save and reload','DevMode preset application restores flags','DevMode 1440 and 1280 layouts','one live setting per scenario parameter','map and launch saved together','bulk army changes and undo update map source','profile save failure preserves dirty state and can retry','map failure prevents launch','cancel map switch preserves edits','new map preset selected in one save','drag point and undo','single-placement tool resets','setups stay in same window','all three operation modes stay in same frame','1440 and 1280 layouts without horizontal overflow','reserved help strip'],posts:posts.map(p=>p.url),screenshots:fs.readdirSync(out).filter(f=>f.endsWith('.png'))};
  fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
 }finally{await browser.close();server.close();operationsServer.close();}
})().catch(error=>{console.error(error);server.close();operationsServer.close();process.exitCode=1;});
