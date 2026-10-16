'use strict';
// Isolated UI acceptance; no saved scenarios, services or game files are changed.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('playwright'),{createServer}=require('../control-center/operations-server');
async function main(){
 const server=createServer({store:{list:()=>[],get:()=>{throw Error('No saved scenario writes in QA');},save:()=>{throw Error('No saved scenario writes in QA');}},builder:{}});
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'}),page=await browser.newPage({viewport:{width:1440,height:1000}});
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 try{
  for(const mode of ['campaign','ground']){
   await page.goto('http://127.0.0.1:'+server.address().port+'/'+mode);
   await page.waitForFunction(()=>typeof draft!=='undefined'&&draft&&document.querySelectorAll('#fleets [data-setup] option').length>2,{},{timeout:30000});
   const fixture=await page.evaluate(()=>{
    const candidate=bootstrap.setups.find(s=>s.side==='west'&&typeof s.infantry==='number'&&s.infantry>32&&s.infantry<=256&&bootstrap.catalog.filter(c=>c.side==='WEST'&&c.faction===s.faction).length>=s.infantry);
    if(!candidate)throw Error('No large installed setup fixture');
    const a=draft.sides.find(a=>a.side==='WEST');a.faction='QA_OTHER_FACTION';
    const before=structuredClone(a);if(typeof renderArmies==='function')renderArmies();else renderFleets();
    const tab=document.querySelector('[data-tab="armies"]')||document.querySelector('[data-tab="forces"]');if(tab)tab.click();
    return {candidate,before};
   });
   const card=page.locator('#fleets > .card').first();
   await card.locator('[data-setup]').selectOption(fixture.candidate.id);
   await card.locator('[data-import]').click({force:true});
   await page.waitForFunction(()=>document.getElementById('status').textContent.startsWith('Пехота сетапа перенесена:'));
   const result=await page.evaluate(()=>structuredClone(draft.sides.find(a=>a.side==='WEST')));
   assert(result.classes.length>32);assert.equal(result.faction,'');assert.deepEqual(result.shop,fixture.before.shop);assert.deepEqual(result.gear,fixture.before.gear);assert.equal(result.truckClass,fixture.before.truckClass);assert.equal(result.groupSize,fixture.before.groupSize);
   const catalog=require('../control-center/'+mode+'-operations').catalog();assert(result.classes.every(id=>catalog.some(c=>c.side==='WEST'&&c.class===id)));
   const design=await page.evaluate(()=>structuredClone(draft));require('../control-center/'+mode+'-operations').validate(design);
   fs.mkdirSync(path.resolve('dist/ui-review'),{recursive:true});await page.screenshot({path:path.resolve('dist/ui-review/infantry-import-'+mode+'.png'),fullPage:true});
   await card.locator('[data-undo]').click({force:true});
   assert.deepEqual(await page.evaluate(()=>structuredClone(draft.sides.find(a=>a.side==='WEST'))),fixture.before);
   const automatic=await page.evaluate(faction=>setupInfantry({setup:{infantry:null,faction}},'WEST'),fixture.candidate.faction);assert(automatic.ids.length>32);
   console.log(mode+': imported '+result.classes.length+' classes, faction filter released, settings retained, server validation and undo passed');
  }
  assert.deepEqual(errors,[]);console.log('INFANTRY_IMPORT_UI_OK');
 }finally{await browser.close();server.closeAllConnections();await new Promise(resolve=>server.close(resolve));}
}
main().catch(e=>{console.error(e);process.exitCode=1;});
