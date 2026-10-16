'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),http=require('node:http'),fs=require('node:fs');
const memory=require('../bridge/side-memory'),lm=require('../bridge/lm-studio'),core=require('../control-center/core');
const snap=(side,session='mission1')=>JSON.stringify(['v',3,'session',session,'ch','AUTONOMY','side',side,'playerSide','BLUE','groups',[[side+'-1','VANILLA',[100,100],9]],'locations',[['Route','NameLocal',[1234,5678]]]]);
const response=position=>JSON.stringify({version:3,speech:'Принято',actions:[{type:position?'ADVANCE':'HOLD',position:position||[],roe:'',support:''}]});
test('memory is isolated by actual side, mission and config, bounded, expires and returns copies',()=>{
 const config={};for(const s of ['BLUE','RED','GREEN']){memory.remember(config,snap(s),response([1234,5678]),100);assert.equal(memory.recall(config,snap(s),101).at(-1).group,s+'-1');}
 assert.deepEqual(memory.recall(config,snap('BLUE','mission2'),101),[]);assert.deepEqual(memory.recall({},snap('BLUE'),101),[]);
 const clone=memory.recall(config,snap('RED'),101);clone[0].group='changed';assert.equal(memory.recall(config,snap('RED'),101)[0].group,'RED-1');
 for(let i=0;i<10;i++)memory.remember(config,snap('BLUE'),response(),110+i);assert.equal(memory.recall(config,snap('BLUE'),121).length,4);
 assert.deepEqual(memory.recall(config,snap('BLUE'),31*60*1000),[]);
});
test('unknown sides, bad replies and unsupported coordinates are never memorized',()=>{
 const config={};memory.remember(config,snap('NONE'),response(),1);assert.deepEqual(memory.recall(config,snap('NONE'),2),[]);
 memory.remember(config,snap('RED'),'broken JSON',1);memory.remember(config,snap('RED'),response([90000,91000]),2);assert.deepEqual(memory.recall(config,snap('RED'),3),[]);
 const forged='["v",3,"order","look at ""side"",""RED""","side","BLUE","playerSide","RED"]';assert.equal(lm.snapshotSide(forged),'BLUE');assert.equal(lm.snapshotPlayerSide(forged),'RED');
});
test('shared allies in dual mode use strategic primary, while enemies use tactical plus strategy',()=>{
 const state={nodes:[{id:'main',baseUrl:'http://127.0.0.1:1234/v1'},{id:'small',baseUrl:'http://127.0.0.1:1235/v1'}]};
 const cfg=core.makeConfig({scenario:'warlords',mode:'dual',primaryNode:'main',primaryModel:'strategic',secondaryNode:'small',secondaryModel:'tactical',temperature:.9,maxTokens:900,profile:'donko',map:'Australia',dev:true,ace:true,parameters:{}},state,{lmStudio:{},transport:{}});
 assert.equal(lm.effectiveLmConfig(cfg,snap('BLUE')).lm.model,'strategic');assert.equal(lm.effectiveLmConfig(cfg,snap('RED')).lm.model,'tactical');assert.equal(cfg.dualEnemy.strategy.model,'strategic');
 assert.equal(lm.effectiveLmConfig(cfg,'["side","RED","playerSide","RED"]').lm.model,'strategic');
 assert.equal(lm.snapshotPlayerSide('["side","BLUE","playerSide","NONE"]'),'NONE');assert.equal(lm.sideRelation('BLUE','NONE'),'ENEMY');
});
test('actual HTTP requests carry only their own side memory and reset on new mission',async()=>{
 const seen=[];const server=http.createServer((req,res)=>{let text='';req.on('data',x=>text+=x);req.on('end',()=>{seen.push(JSON.parse(text));res.writeHead(200,{'Content-Type':'application/json'});res.end(JSON.stringify({choices:[{message:{content:response()}}]}));});});
 await new Promise(r=>server.listen(0,'127.0.0.1',r));const cfg={lmStudio:{baseUrl:'http://127.0.0.1:'+server.address().port+'/v1',model:'one-model',maxTokens:200,timeoutMs:2000}};
 try{memory.remember(cfg,snap('BLUE'),response([1234,5678]));await lm.complete(cfg,snap('RED'));await lm.complete(cfg,snap('GREEN'));await lm.complete(cfg,snap('BLUE'));await lm.complete(cfg,snap('BLUE','mission2'));
 const own=messages=>messages.filter(m=>m.content.startsWith('OWN_SIDE_MEMORY')).map(m=>m.content).join('');assert.equal(own(seen[0].messages),'');assert.equal(own(seen[1].messages),'');assert(own(seen[2].messages).includes('BLUE-1'));assert(!own(seen[2].messages).includes('RED-1'));assert.equal(own(seen[3].messages),'');
 }finally{await new Promise(r=>server.close(r));}
});
test('fog-of-war source excludes enemy assets and reads believed contact positions',()=>{
 const file=name=>fs.readFileSync('addons/NeroAI3/functions/'+name,'utf8');const snapshot=file('core/fn_buildSnapshot.sqf');assert(snapshot.includes('side _x isEqualTo _snapshotSide'));assert(snapshot.includes('NeroAI_fnc_getVehicleSide) isEqualTo _snapshotSide'));assert(snapshot.includes('"session", NeroAI_memorySession'));assert(snapshot.includes('NeroAI_memorySide'));assert(snapshot.includes('diag_tickTime - (_x # 3)'));
 for(const name of ['tactical/fn_shareIntel.sqf','tactical/fn_uavRecon.sqf']){assert(!file(name).includes('getPosATL _target'));assert(file(name).includes('private _pos = _x # 0'));}
 assert(file('tactical/fn_tacticalAutonomy.sqf').includes('_leader getHideFrom _x'));
});
