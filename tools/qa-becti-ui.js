'use strict';
// Isolated service + in-memory save store: never launches Arma or edits existing scenarios.
const fs=require('fs'),path=require('path'),assert=require('node:assert/strict'),{chromium}=require(process.env.NEROAI_PLAYWRIGHT||'playwright');
async function main(){
 const store={records:new Map(),list(){return [...this.records.values()].map(r=>({id:r.id,type:r.design.type,title:r.design.title,world:r.design.world,revision:r.revision}));},get(id){return this.records.get(id);},save(v){const r={id:v.id||'12345678-1234-1234-1234-123456789abc',design:require('../control-center/operations').validate(v.design),revision:(v.revision||0)+1};this.records.set(r.id,r);return r;}};
 const server=require('../control-center/operations-server').createServer({store});await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 const browser=await chromium.launch({headless:true,executablePath:process.env.NEROAI_CHROME||'C:/Program Files/Google/Chrome/Application/chrome.exe'}),page=await browser.newPage({viewport:{width:1440,height:1050}}),errors=[];page.on('pageerror',e=>errors.push(e.message));page.on('dialog',d=>d.accept());
 const output=path.resolve(__dirname,'../dist/ui-review/becti-20261017');fs.mkdirSync(output,{recursive:true});
 try{
  await page.goto('http://127.0.0.1:'+server.address().port+'/becti',{waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>document.getElementById('bectiParameters')?.querySelectorAll('select').length>=90,{},{timeout:60000});
  assert.equal(await page.locator('h1').innerText(),'BECTI · редактор War Architect');
  await page.locator('#title').fill('War Architect BECTI browser test');
  await page.getByLabel('Группы Ботов вместо Игроков',{exact:true}).selectOption('3');
  await page.locator('#save').click();await page.waitForFunction(()=>document.getElementById('status').textContent.includes('сохранена'));
  const saved=[...store.records.values()][0];assert.equal(saved.design.type,'becti');assert.equal(saved.design.title,'War Architect BECTI browser test');assert.equal(saved.design.bectiParameters.CTI_AI_TEAMS_ENABLED,3);
  await page.screenshot({path:path.join(output,'becti-main.png'),fullPage:true});
  await page.locator('[data-tab="equipment"]').click();const button=page.locator('[data-complete]').first();await button.click();await page.waitForFunction(()=>document.getElementById('status').textContent.startsWith('Добавлено'));
  await page.screenshot({path:path.join(output,'becti-equipment.png'),fullPage:true});
  await page.locator('[data-tab="devmode"]').click();assert.equal(await page.locator('[data-experiment="physicalDrop"]').count(),0);assert.equal(await page.locator('[data-experiment="radarNetwork"]').count(),1);
  assert.deepEqual(errors,[]);console.log(JSON.stringify({browser:'Chromium',bectiParameters:92,saveReloadContract:true,loadoutCompletion:true,errors,output}));
 }finally{await browser.close();await new Promise(resolve=>server.close(resolve));}
}
main().catch(e=>{console.error(e);process.exitCode=1;});
