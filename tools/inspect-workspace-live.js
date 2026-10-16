'use strict';
// Read-only visual smoke against the running panel. Refuse any browser POST.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require(process.env.NEROAI_PLAYWRIGHT||'playwright');
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.NEROAI_CHROME||'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 const operations=process.argv.includes('--operations'),devmode=process.argv.includes('--devmode'),missions=process.argv.includes('--missions');
 const page=await browser.newPage({viewport:{width:1440,height:1000}}),errors=[],writes=[];
 page.on('pageerror',e=>errors.push(e.message));
 await page.route('**/*',route=>{if(route.request().method()!=='GET'){const url=route.request().url();writes.push(url);if(!(operations&&new URL(url).pathname==='/api/operations-panel'))return route.abort();}return route.continue();});
 try{
  await page.goto(process.env.NEROAI_PANEL_URL||'http://127.0.0.1:18775/?tab=launch',{waitUntil:'domcontentloaded'});
  await page.waitForSelector('#editor-title',{state:'attached',timeout:30000});
  const title=await page.locator('#editor-title').inputValue();await page.locator('#mapPresetsTab').click();
  const frame=page.frames().find(f=>f.url().includes('/designer'));await frame.waitForSelector('#map');
  const result={loaded:true,title,world:await page.locator('#map').inputValue(),sectors:await frame.evaluate(()=>NeroEditor.snapshot().sectors.length),errors,writes};
  if(operations){await page.locator('#operationsTab').click();await page.frameLocator('#operationsFrame').locator('#world option').first().waitFor({state:'attached',timeout:30000});result.operations=await page.locator('#operationsFrame').getAttribute('src');}
  if(missions){await page.locator('#missionsTab').click();await page.locator('.mission-card').first().waitFor();result.library=await page.evaluate(()=>api('/api/scenario-library').then(r=>({counts:r.counts,total:r.items.length})));}
  if(devmode){await page.locator('#devmodeTab').click();assert(await page.locator('#devmodePanel').isVisible());result.devMode=await page.evaluate(()=>selection().devMode);}
  await page.waitForLoadState('networkidle',{timeout:10000});
  const out=path.resolve(__dirname,'../dist/ui-review');fs.mkdirSync(out,{recursive:true});await page.screenshot({path:path.join(out,missions?'live-missions.png':devmode?'live-devmode.png':operations?'live-operations.png':'live-map.png')});
  assert.equal(errors.length,0,errors.join('\n'));assert(writes.every(url=>operations&&new URL(url).pathname==='/api/operations-panel'),'Live inspection attempted a data write');
  fs.writeFileSync(path.join(out,missions?'live-missions.json':devmode?'live-devmode.json':operations?'live-operations.json':'live-readonly.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result,null,2));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
