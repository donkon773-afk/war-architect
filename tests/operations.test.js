'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os'),crypto=require('node:crypto');
const ops=require('../control-center/operations'),builder=require('../tools/build-operation'),validator=require('../tools/validate-operation');
function temp(prefix){return fs.mkdtempSync(path.join(os.tmpdir(),prefix));}
function clean(dir,prefix){assert.equal(path.dirname(dir),path.resolve(os.tmpdir()));assert(path.basename(dir).startsWith(prefix));fs.rmSync(dir,{recursive:true,force:true});}
test('air operation defaults have real installed aircraft, pilot role, 24 active and 72 finite airframes',()=>{const d=ops.defaults();assert.equal(d.world,'Australia');assert.equal(d.playerRole,'pilot');assert.equal(d.sides.reduce((n,a)=>n+a.active,0),24);assert.equal(d.sides.reduce((n,a)=>n+a.active+a.reserve,0),72);assert(d.sides.every(a=>a.classes.every(id=>ops.catalog().some(c=>c.class===id&&c.side===a.side))));assert(ops.modPaths(d).some(p=>/Australia/i.test(p)));});
test('invalid side, UAV, class, unlimited stock, close formations, impossible score and NaN are rejected',()=>{
 const change=(apply,pattern)=>{const d=ops.defaults();apply(d);assert.throws(()=>ops.validate(d),pattern);};
 change(d=>d.sides[0].classes=d.sides[1].classes,/своей стороны/);change(d=>d.sides[0].classes=['invalid_plane'],/самолётов/);change(d=>d.sides[0].classes=[],/самолётов/);
 const uav=require('../control-center/warlords-editor').inventory().assets.find(a=>a.kind==='PLANE'&&a.isUav&&a.side===1);if(uav)change(d=>d.sides[0].classes=[uav.class],/самолётов/);
 change(d=>d.sides[0].reserve=65,/Резерв/);change(d=>d.sides[0].active=21,/Одновременно|одновременно/);change(d=>d.sides[1].side='WEST',/синие и красные/);
 change(d=>d.sides[1].entry=[...d.sides[0].entry],/8 км/);change(d=>d.sides[0].entry=[0,0],/Точка входа/);change(d=>d.altitude=NaN,/Высота/);change(d=>d.duration=0,/Длительность/);change(d=>d.scoreTarget=37,/полный запас/);change(d=>d.playerClass=d.sides[1].classes[0],/Самолёт игрока/);change(d=>d.title='bad\nname',/Название/);
 const d=ops.defaults();d.untrustedSQF='call compile';assert(!Object.hasOwn(ops.validate(d),'untrustedSQF'));
});
test('durable operation store keeps ID and version, rejects stale save and preserves the unsaved draft',()=>{
 const dir=temp('nero-operation-store-');try{const store=ops.createStore(dir),d=ops.defaults(),a=store.save({design:d});assert.equal(a.verified,true);assert.equal(store.get(a.id).id,a.id);assert.equal(a.revision,1);d.duration=35;const b=store.save({id:a.id,revision:a.revision,design:d});assert.equal(b.revision,2);const unsaved=structuredClone(d);unsaved.duration=20;assert.throws(()=>store.save({id:a.id,revision:1,design:unsaved}),/другом окне/);assert.equal(store.get(a.id).design.duration,35);assert.equal(unsaved.duration,20);const copy=store.save({design:unsaved});assert.notEqual(copy.id,a.id);assert.equal(store.list().length,2);assert.throws(()=>store.get('../profiles'),/ID/);}finally{clean(dir,'nero-operation-store-');}
});
test('pilot and observer missions have complete functions and multiplayer metadata; generator output is repeatable',()=>{
 const dir=temp('nero-operation-build-');try{for(const role of ['pilot','observer']){const d={...ops.defaults(),playerRole:role};const result=builder.build(d,dir),v=validator.validate(dir);assert.equal(v.slots,role==='pilot'?4:1);assert.equal(v.functions,22);assert.equal(v.stock,72);assert.doesNotMatch(fs.readFileSync(path.join(dir,'mission.sqm'),'utf8'),/ModuleWLInit_F/);
  for(const fn of builder.functions)assert.equal(fs.readFileSync(path.join(dir,'neroOps','fn_'+fn+'.sqf'),'utf8'),fs.readFileSync(path.join(__dirname,(fn.startsWith('zeus')||fn.startsWith('aiG'))?'../tools/operation-common':'../tools/operation-assets','fn_'+fn+'.sqf'),'utf8'));
  const before=new Map(fs.readdirSync(dir).filter(n=>fs.statSync(path.join(dir,n)).isFile()).map(n=>[n,fs.readFileSync(path.join(dir,n))]));const again=builder.build(d,dir);assert.equal(again.name,result.name);for(const [name,bytes]of before)assert.deepEqual(fs.readFileSync(path.join(dir,name)),bytes);
  const desc=path.join(dir,'description.ext'),saved=fs.readFileSync(desc,'utf8');fs.writeFileSync(desc,saved.replace('class NeroOP_fnc_airRequest {allowedTargets=2;}','class NeroOP_fnc_airRequest {allowedTargets=0;}'));assert.throws(()=>validator.validate(dir),/must target server/);fs.writeFileSync(desc,saved);
  const helper=path.join(dir,'neroOps','fn_airBoard.sqf');fs.renameSync(helper,helper+'.saved');assert.throws(()=>validator.validate(dir),/missing: airBoard/);fs.renameSync(helper+'.saved',helper);
 }
 }finally{clean(dir,'nero-operation-build-');}
});
test('production SQF executes finite stock, score, replay, outcome and formation separation regressions',()=>{const r=require('../tools/verify-operation-sqf').verify();assert.equal(r.parsedFiles,22);assert.equal(r.assertions,255);assert.equal(r.engineExecuted,false);});
test('FA18 avionics adapter calls functions actually exported by the installed cockpit mod',()=>{
 const reader=require('../tools/read-pbo-entry'),decode=require('../tools/read-world-config').decodeRap,folder='H:/SteamLibrary/steamapps/common/Arma 3/!Workshop/@FA-18 Super Hornet/addons';
 const coreFile=path.join(folder,'js_jc_fa18_core.pbo'),mainFile=path.join(folder,'js_jc_fa18.pbo'),core=decode(reader.readEntry(coreFile,'config.bin'));
 const exported=core.classes.cfgFunctions.classes.js_jc_fa18_core.classes.functions.classes;
 for(const fn of ['aircraftEntered','systemStop']){assert(exported[fn]);assert(reader.readEntry(coreFile,exported[fn].values.file.replace(/^js_jc_fa18_core\\/,'' )).length>0);}
 const source=reader.readEntry(mainFile,'scripts/Init_FA18E.sqf').toString('utf8');assert.match(source,/addEventHandler \["GetIn".*js_jc_fa18_core_fnc_aircraftEntered/);
 const aircraft=decode(reader.readEntry(mainFile,'config.bin')).classes.CfgVehicles.classes.JS_JC_FA18E;
 assert(aircraft.values.js_jc_fa18_systems.includes('cockpit'));assert(aircraft.values.js_jc_fa18_systems.includes('mfd'));
 const helper=fs.readFileSync(path.join(__dirname,'../tools/operation-assets/fn_airAvionics.sqf'),'utf8');assert.doesNotMatch(helper,/execVM|compile/);assert.match(helper,/js_jc_fa18_core_fnc_aircraftEntered/);
});
test('helmet initialization matches the installed native HMD display gate and keeps its manual toggle',()=>{
 const reader=require('../tools/read-pbo-entry'),decode=require('../tools/read-world-config').decodeRap,folder='H:/SteamLibrary/steamapps/common/Arma 3/!Workshop/@FA-18 Super Hornet/addons';
 const native=reader.readEntry(path.join(folder,'js_jc_fa18_cockpit.pbo'),'functions/buttons/hmd.sqf').toString('utf8');
 assert.match(native,/setUserMFDValue\s*\[48,1\]/);assert.match(native,/setVariable\s*\["FA18_JHMCS",true\]/);assert.match(native,/animate\s*\["Switch_hmd",1,/);
 const cfg=decode(reader.readEntry(path.join(folder,'js_jc_fa18.pbo'),'config.bin')).classes.CfgVehicles.classes.JS_JC_FA18E;
 const nodes=[];function visit(n){nodes.push(n);for(const c of Object.values(n.classes||{}))visit(c);}visit(cfg);
 assert(nodes.some(n=>n.values?.helmetMountedDisplay===1));assert(nodes.some(n=>n.values?.condition==='user48'));
 const helmet=fs.readFileSync(path.join(__dirname,'../tools/operation-assets/fn_airHelmet.sqf'),'utf8');
 assert.match(helmet,/setUserMFDValue \[48,_value\]/);assert.match(helmet,/setVariable \["FA18_JHMCS",_enabled\]/);assert.match(helmet,/animate \["Switch_hmd",_value,true\]/);
 assert.match(helmet,/driver _plane!=_unit/);assert.match(helmet,/!local _plane/);assert.doesNotMatch(helmet.replace(/\/\/[^\n]*/g,''),/\b(?:compile|execVM|remoteExec|addEventHandler|while)\b/);
 const avionics=fs.readFileSync(path.join(__dirname,'../tools/operation-assets/fn_airAvionics.sqf'),'utf8'),client=fs.readFileSync(path.join(__dirname,'../tools/operation-assets/fn_airClient.sqf'),'utf8');
 assert.match(avionics,/\[_plane,_unit\] call NeroOP_fnc_airHelmet/);assert.match(client,/\[vehicle player,player,true\] call NeroOP_fnc_airHelmet/);
});
test('saving production UI rebinds fleet controls and does not discard edits made while saving',async()=>{
 const vm=require('node:vm'),source=fs.readFileSync(path.join(__dirname,'../control-center/operations-ui.js'),'utf8').match(/^async function save\(copy=false\).*$/m)[0];let resolve;
 const context={structuredClone,draft:ops.defaults(),record:null,dirty:true,saving:false,fillCount:0,boundSides:null,summary(){},refreshSaved:async()=>{},status(){},api:async(url,data)=>new Promise(r=>resolve=()=>r({id:'test',revision:1,design:data.design}))};
 context.fill=()=>{context.fillCount++;context.boundSides=context.draft.sides;};vm.createContext(context);vm.runInContext(source,context);
 const first=context.save();context.draft.duration=35;resolve();await first;assert.equal(context.draft.duration,35);assert.equal(context.dirty,true);assert.equal(context.fillCount,0);
 const next=context.save();resolve();await next;assert.equal(context.dirty,false);assert.equal(context.fillCount,1);context.boundSides[0].active=9;assert.equal(context.draft.sides[0].active,9);
});
test('production launcher bypasses the launcher and only succeeds after observing the correct game mods',()=>{
 const dir=temp('nero-operation-launch-');try{
  const request=path.join(dir,'request.json'),harness=path.join(dir,'harness.ps1'),script=path.join(__dirname,'../control-center/operations-launch.ps1');
  fs.writeFileSync(request,JSON.stringify({title:'Launch regression',mods:ops.modPaths(ops.defaults())}));
  fs.writeFileSync(harness,`param([string]$RequestFile,[string]$LaunchScript,[string]$Case)
$script:LaunchElapsed=0
function Get-Date {[DateTime]::new(2026,10,13,12,0,0,[DateTimeKind]::Utc).AddSeconds($script:LaunchElapsed)}
function Get-Process {param([string[]]$Name,$ErrorAction) if ($Case -eq 'existingGame' -and $Name -contains 'arma3_x64') {[pscustomobject]@{Id=43210}} elseif ($Case -eq 'existingLauncher' -and $Name -contains 'arma3launcher') {[pscustomobject]@{Id=43211}}}
function Start-Process {param($FilePath,$ArgumentList,$WindowStyle) [Console]::WriteLine('ARGS:'+ $ArgumentList)
 if($Case -in @('hiddenCommandLine','wrongReport','staleReport')) {
  $env:LOCALAPPDATA=Join-Path (Split-Path $RequestFile) $Case
  $folder=Join-Path $env:LOCALAPPDATA 'Arma 3';[IO.Directory]::CreateDirectory($folder)|Out-Null
  $par=[regex]::Match($ArgumentList,'-par=([^\"]+)').Groups[1].Value
  if($Case -eq 'wrongReport') {$par='unrelated-parameters.txt'}
  $rpt=Join-Path $folder 'Arma3_x64_test.rpt'
  [IO.File]::WriteAllText($rpt,('== '+[IO.Path]::Combine('H:/SteamLibrary/steamapps/common/Arma 3','arma3_x64.exe').Replace('/',[IO.Path]::DirectorySeparatorChar)+' -par='+$par),[Text.UTF8Encoding]::new($false))
  if($Case -eq 'staleReport') {(Get-Item -LiteralPath $rpt).CreationTimeUtc=[datetime]::new(2026,10,12)}
 }
}
function Start-Sleep {param($Milliseconds) $script:LaunchElapsed+=$Milliseconds/1000}
function Get-CimInstance {param($Filter) if($Case -eq 'neverAppears' -or ($Case -eq 'lateGame' -and $script:LaunchElapsed -lt 25)){return};$mods=(Get-Content -LiteralPath $RequestFile -Raw -Encoding UTF8|ConvertFrom-Json).mods;[pscustomobject]@{ProcessId=543210;CommandLine=$(if($Case -eq 'wrongMods') {'arma3_x64.exe -mod=unrelated'} elseif($Case -in @('hiddenCommandLine','wrongReport','staleReport')) {$null} else {'arma3_x64.exe -mod='+($mods -join ';')})}}
function Test-Path {param($LiteralPath,$PathType='Any') if($LiteralPath.EndsWith('NeroAirDefense.pbo')){return $Case -ne 'missingDefense'} if($Case -eq 'missingCompat' -and $LiteralPath.EndsWith('NeroStrategic.pbo')) {return $false};Microsoft.PowerShell.Management\\Test-Path -LiteralPath $LiteralPath -PathType $PathType}
try {& $LaunchScript -RequestFile $RequestFile} catch {[Console]::Error.WriteLine($_.ToString());exit 1}
`, 'utf8');
  const shell=['C:/Program Files/PowerShell/7/pwsh.exe',path.join(process.env.USERPROFILE||'','.cache/codex-runtimes/codex-primary-runtime/dependencies/native/powershell/pwsh.exe')].find(p=>fs.existsSync(p))||'powershell.exe';
  const run=mode=>require('node:child_process').spawnSync(shell,['-NoProfile','-File',harness,'-RequestFile',request,'-LaunchScript',script,'-Case',mode],{encoding:'utf8',windowsHide:true,timeout:10000});
  const good=run('ok');assert.equal(good.status,0,good.stderr);assert.match(good.stdout,/-noLauncher -win64 -useBE/);assert.match(good.stdout,/"pid":543210/);
  const late=run('lateGame');assert.equal(late.status,0,late.stderr);assert.match(late.stdout,/"launched":true/);
  const absent=run('neverAppears');assert.notEqual(absent.status,0);assert.match(absent.stderr,/не появился за 90 секунд/);assert.doesNotMatch(absent.stdout,/"launched":true/);
  for(const mode of ['existingGame','existingLauncher','wrongMods']){const bad=run(mode);assert.notEqual(bad.status,0,mode);assert.doesNotMatch(bad.stdout,/"launched":true/);if(mode!=='wrongMods')assert.doesNotMatch(bad.stdout,/ARGS:/);}
  const original=ops.modPaths(ops.defaults()),compat=path.resolve(__dirname,'../dist/strategic-compat/@NeroAI_Strategic');
  fs.writeFileSync(request,JSON.stringify({title:'Стратегическая кампания',mods:[...original,compat]}));
  const strategic=run('ok');assert.equal(strategic.status,0,strategic.stderr);assert.match(strategic.stdout,/"launched":true/);
  const launched=JSON.parse(strategic.stdout.split('\n').find(l=>l.startsWith('{'))),parameters=fs.readFileSync(launched.parameters,'utf8'),compact=p=>p.startsWith('H:\\SteamLibrary\\steamapps\\common\\Arma 3\\')?p.slice('H:\\SteamLibrary\\steamapps\\common\\Arma 3\\'.length):p;assert(parameters.includes(compat));assert(parameters.includes('-mod="'+[...original,compat].map(compact).join(';')+'"'));assert.match(strategic.stdout,/-par=/);assert.doesNotMatch(strategic.stdout,/ARGS:.*-mod=/);
  const everyMod=[...require('../control-center/operation-mods').catalog().map(m=>m.id),compat];fs.writeFileSync(request,JSON.stringify({title:'Все моды',mods:everyMod}));const all=run('ok');assert.equal(all.status,0,all.stderr);const allResult=JSON.parse(all.stdout.split('\n').find(l=>l.startsWith('{'))),allText=fs.readFileSync(allResult.parameters,'utf8');assert(Buffer.byteLength(allText)<4000);assert(allText.includes('!Workshop\\@CBA_A3'));assert(allText.includes('!Workshop\\@CUP Vehicles'));assert(allText.includes('!Workshop\\@DISMEMBERMENT+GORE [SP-MP]'));for(const p of everyMod)assert(allText.includes(compact(p)));fs.writeFileSync(request,JSON.stringify({title:'Стратегическая кампания',mods:[...original,compat]}));
  const hidden=run('hiddenCommandLine');assert.equal(hidden.status,0,hidden.stderr);assert.match(hidden.stdout,/"verification":"freshReport"/);
  for(const mode of ['wrongReport','staleReport']){const rejected=run(mode);assert.notEqual(rejected.status,0,mode);assert.doesNotMatch(rejected.stdout,/"launched":true/);assert.match(rejected.stderr,/набор модов не удалось подтвердить/);}
  const missingCompat=run('missingCompat');assert.notEqual(missingCompat.status,0);assert.match(missingCompat.stderr,/Не найден дополнительный мод NeroAI Strategic/);assert.doesNotMatch(missingCompat.stdout,/ARGS:/);
  for(const mod of [dir,compat+'-other',original[0]+';injected',original[0]+'"injected']){fs.writeFileSync(request,JSON.stringify({title:'Invalid path',mods:[mod]}));const bad=run('ok');assert.notEqual(bad.status,0,mod);assert.doesNotMatch(bad.stdout,/ARGS:/);}
  fs.writeFileSync(request,JSON.stringify({title:'Missing path',mods:['H:\\SteamLibrary\\steamapps\\common\\Arma 3\\@NeroLaunch_missing_20261013']}));
  const missing=run('ok');assert.notEqual(missing.status,0);assert.match(missing.stderr,/Недоступна папка мода операции:/);assert.doesNotMatch(missing.stdout,/ARGS:/);
  if(process.platform==='win32'){
   fs.writeFileSync(request,JSON.stringify({title:'Стратегическая кампания',mods:[...original,compat]}));
   const legacy=require('node:child_process').spawnSync('powershell.exe',['-NoProfile','-File',harness,'-RequestFile',request,'-LaunchScript',script,'-Case','ok'],{encoding:'utf8',windowsHide:true,timeout:10000});assert.equal(legacy.status,0,legacy.stderr);const legacyResult=JSON.parse(legacy.stdout.split('\n').find(l=>l.startsWith('{')));assert(fs.readFileSync(legacyResult.parameters,'utf8').includes(compat));
   const legacyError=require('node:child_process').spawnSync('powershell.exe',['-NoProfile','-File',harness,'-RequestFile',request,'-LaunchScript',script,'-Case','existingGame'],{encoding:'utf8',windowsHide:true,timeout:10000});assert.notEqual(legacyError.status,0);assert.match(legacyError.stderr,/Arma уже открыта/);
  }
 }finally{clean(dir,'nero-operation-launch-');}
});
test('unavailable optional mods remain in saved preferences but are omitted from launch; required mods remain required',()=>{
 const d=ops.defaults(),required=ops.modPaths(d),extra=require('../control-center/warlords-editor').inventory().mods.find(m=>!required.includes(m.path)).path,stat=fs.statSync;
 d.extraMods=[extra];
 try {fs.statSync=function(p,...args){if(String(p)===extra){const e=new Error('Unavailable test mod');e.code='ENOENT';throw e;}return stat.call(this,p,...args);};
  assert(!require('../control-center/operation-mods').catalog().some(m=>m.id===extra));assert.deepEqual(require('../control-center/operation-mods').validate(d.extraMods),[extra]);assert(!ops.modPaths(d).includes(extra));assert.deepEqual(d.extraMods,[extra]);
  const mandatory=required[0];fs.statSync=function(p,...args){if(String(p)===mandatory){const e=new Error('Unavailable required mod');e.code='ENOENT';throw e;}return stat.call(this,p,...args);};assert(ops.modPaths(d).includes(mandatory));
 }finally{fs.statSync=stat;}
});
test('HTTP service requires session and origin, refuses stale builds and serializes concurrent builds',async()=>{
 const dir=temp('nero-operation-http-'),store=ops.createStore(dir);let builds=0,release;const gate=new Promise(r=>release=r),started=new Promise(r=>{globalThis.operationBuildStarted=r;});
 const server=require('../control-center/operations-server').createServer({store,builder:{build:async()=>{builds++;globalThis.operationBuildStarted();await gate;return {title:'test',sourceVerified:true};}}});
 try{await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));const base='http://127.0.0.1:'+server.address().port,html=await (await fetch(base+'/operations')).text(),token=html.match(/API_SESSION="([a-f0-9]+)"/)[1],headers={'X-Nero-Session':token,'Content-Type':'application/json'};
  assert.equal((await fetch(base+'/api/operations')).status,403);assert.equal((await fetch(base+'/api/operations',{headers:{...headers,Origin:'http://example.com'}})).status,403);
  const response=await fetch(base+'/api/operation',{method:'POST',headers,body:JSON.stringify({design:ops.defaults()})});assert.equal(response.status,200);const saved=await response.json();
  const stale=await fetch(base+'/api/operation-build',{method:'POST',headers,body:JSON.stringify({id:saved.id,revision:0})});assert.equal(stale.status,400);assert.equal(builds,0);
  const first=fetch(base+'/api/operation-build',{method:'POST',headers,body:JSON.stringify({id:saved.id,revision:saved.revision})});await started;
  const second=await fetch(base+'/api/operation-build',{method:'POST',headers,body:JSON.stringify({id:saved.id,revision:saved.revision})});assert.equal(second.status,400);assert.match((await second.json()).error,/текущей сборки/);release();assert.equal((await first).status,200);assert.equal(builds,1);
  const health=await (await fetch(base+'/health')).json();assert.equal(health.busy,false);
 }finally{release();delete globalThis.operationBuildStarted;await new Promise(resolve=>server.close(resolve));clean(dir,'nero-operation-http-');}
});
