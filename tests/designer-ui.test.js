'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const schema=require('../control-center/scenario-design');
function setup(){
 const html=fs.readFileSync('control-center/designer.html','utf8'),script=html.match(/<script>([\s\S]*?)<\/script>/)[1];new vm.Script(script);
 const elements=new Map(),tabs=['scenario','points','start','resources','llm','background'];
 function el(){return {value:'',checked:false,children:[],dataset:{},style:{},classList:{toggle(){}},append(...a){this.children.push(...a);},replaceChildren(...a){this.children=a;},setAttribute(k,v){this[k]=v;},addEventListener(){},get options(){return this.children;},get selectedOptions(){return this.children.filter(x=>x.selected);},click(){return this.onclick?.();}};}
 const by=id=>{if(!elements.has(id))elements.set(id,el());return elements.get(id);};
 const panels=tabs.map(t=>({...el(),dataset:{panel:t}})),buttons=tabs.map(t=>({...el(),dataset:{tab:t}}));const calls=[];
 const document={getElementById:by,createElement:el,querySelector:()=>el(),querySelectorAll:s=>s==='[data-panel]'?panels:s==='[data-tab]'?buttons:[]};
 const context=vm.createContext({document,window:{addEventListener(){}},confirm:()=>true,crypto:{randomUUID:()=>String(Math.random())},URLSearchParams,location:{search:''},setInterval(){},structuredClone,console});
 vm.runInContext(script.slice(0,script.indexOf('Promise.all([api')),context);
 context.fixture={worlds:[{id:'Australia',size:40960,label:'Australia',locations:[]}],catalog:require('../control-center/warlords-editor').inventory(),state:{nodes:[{id:'mac'}],armyDefaults:require('../control-center/warlords-editor').defaults(),selected:{primaryModel:'model'}}};
 context.defaults=schema.blank('Australia');context.calls=calls;
 vm.runInContext("worlds=fixture.worlds;catalog=fixture.catalog;state=fixture.state;paint=()=>{};api=async(url,data)=>{calls.push({url,data});if(url.startsWith('/api/design-defaults'))return structuredClone(defaults);if(data)return data.design;return structuredClone(defaults);};",context);
 const design=schema.blank('Australia');design.title='Saved campaign';design.sectors=[{id:'town',name:'Town',side:'GUER',position:[12000,16000],radius:250,infantry:12,vehicles:0,vehicleClasses:[]}];design.maxNPCs=200;
 context.initial=design;vm.runInContext('renderDesign(structuredClone(initial))',context);return {context,by,calls,panels,buttons,html};
}
test('reset stays a reversible draft; save uses the explicit existing action',async()=>{
 const {context,by,calls}=setup();by('title').value='Unsaved title';await by('reset').onclick();const draft=JSON.parse(vm.runInContext('JSON.stringify(design)',context));assert.equal(draft.title,schema.blank('Australia').title);assert.equal(draft.sectors.length,0);assert.equal(by('maxNPCs').value,160);assert.equal(by('undoReset').hidden,false);assert(calls.every(c=>!c.data));
 by('undoReset').onclick();const restored=JSON.parse(vm.runInContext('JSON.stringify(design)',context));assert.equal(restored.title,'Unsaved title');assert.equal(restored.sectors.length,1);assert.equal(restored.maxNPCs,200);assert(calls.every(c=>!c.data));
 await by('save').onclick();const posts=calls.filter(c=>c.data);assert.equal(posts.length,1);assert.equal(posts[0].data.design.title,'Unsaved title');assert.equal(posts[0].url,'/api/design');
});
test('tabs, search, focus and coordinates operate on selected points',()=>{
 const {context,by,panels,buttons,html}=setup();vm.runInContext("showTab('resources')",context);assert.equal(panels.find(p=>p.dataset.panel==='resources').hidden,false);assert(panels.filter(p=>p.dataset.panel!=='resources').every(p=>p.hidden));assert.equal(buttons.find(p=>p.dataset.tab==='resources')['aria-selected'],'true');
 vm.runInContext("choose(design.sectors[0],'sectors')",context);assert.equal(by('pointX').value,12000);by('pointX').value='12500';by('pointY').value='16500';by('apply').onclick();assert.deepEqual(JSON.parse(vm.runInContext('JSON.stringify(selected.position)',context)),[12500,16500]);by('focusPoint').onclick();assert.equal(JSON.parse(vm.runInContext('JSON.stringify(view)',context))[2],1500);
 by('pointSearch').value='unmatched';by('pointSearch').oninput();assert.equal(by('points').children.length,0);
 const ids=[...html.matchAll(/id="([^"]+)"/g)].map(x=>x[1]);assert.equal(new Set(ids).size,ids.length);
});
test('switching to native mode removes third base and invalid green player selection',()=>{
 const {context,by}=setup();by('mode').value='three';by('mode').onchange();assert.equal(vm.runInContext('design.bases.length',context),3);by('playerSide').value='GUER';by('mode').value='native';by('mode').onchange();assert.equal(vm.runInContext('design.bases.length',context),2);assert.equal(by('playerSide').value,'WEST');
});

test('green army edits persist in collected design and undo/redo restores its catalog',()=>{const {context,by}=setup();by('armySide').value='green';by('armySide').onchange();const rows=by('armyRows').children;assert(rows.length>0);const checkbox=rows[0].children[0];checkbox.checked=true;checkbox.onchange();const chosen=JSON.parse(vm.runInContext('JSON.stringify(collectDesign().army.greenAssets)',context));assert.equal(chosen.length,1);by('undoEdit').onclick();assert.equal(vm.runInContext('design.army.greenAssets.length',context),0);by('redoEdit').onclick();assert.deepEqual(JSON.parse(vm.runInContext('JSON.stringify(design.army.greenAssets)',context)),chosen);assert.equal(by('redoEdit').disabled,true);});
test('side and type filters select only matching points without deleting anything',()=>{const {context,by}=setup();by('pointSideFilter').value='GUER';by('pointSideFilter').onchange();assert.equal(by('points').children.length,2);by('pointTypeFilter').value='bases';by('pointTypeFilter').onchange();assert.equal(by('points').children.length,0);assert.equal(vm.runInContext('design.sectors.length',context),1);assert.equal(vm.runInContext('design.bases.length',context),2);});
test('collected map army is already normalized for verified save/read-back',()=>{const {context}=setup();const d=JSON.parse(vm.runInContext('JSON.stringify(collectDesign())',context)),normalized=schema.validate(d);assert.deepEqual(d.army,normalized.army);});
test('map clears a whole side including infantry and prices, with undo preserving the original setup',()=>{
 const {context,by}=setup(),editor=require('../control-center/warlords-editor');context.NeroSideSetups=require('../control-center/side-setup-client');context.sample={vehicle:editor.inventory().assets.find(a=>a.side===2&&a.kind==='TANK').class,unit:editor.inventory().assets.find(a=>a.side===2&&a.kind==='INFANTRY').class};
 vm.runInContext('design.army.greenAssets=[sample.vehicle];design.army.greenInfantry=[sample.unit];design.army.greenInfantryCosts={[sample.unit]:200};renderDesign(structuredClone(design));',context);by('armySide').value='green';by('armySide').onchange();const before=JSON.parse(vm.runInContext('JSON.stringify(design.army)',context));by('armyClearAll').onclick();assert.equal(vm.runInContext('design.army.greenAssets.length',context),0);assert.equal(vm.runInContext('design.army.greenInfantry.length',context),0);assert.equal(vm.runInContext('Object.keys(design.army.greenInfantryCosts).length',context),0);by('undoEdit').onclick();assert.deepEqual(JSON.parse(vm.runInContext('JSON.stringify(design.army)',context)),before);by('redoEdit').onclick();assert.equal(vm.runInContext('design.army.greenInfantry.length',context),0);
});
test('applying a library setup to the map replaces only its side and saves the reusable composition',async()=>{
 const {context,by}=setup(),contract=require('../control-center/side-setup-client');context.NeroSideSetups=contract;context.sample={name:'Ready green',setup:contract.clear(contract.draft(require('../control-center/warlords-editor').validate(require('../control-center/warlords-editor').defaults()),'green'))};const west=JSON.parse(vm.runInContext('JSON.stringify(design.army.westAssets)',context));by('armySide').value='green';by('armySetupPick').value='fixture';vm.runInContext('api=async()=>sample;',context);await by('armySetupApply').onclick();assert.equal(vm.runInContext('design.army.greenInfantry.length',context),0);assert.deepEqual(JSON.parse(vm.runInContext('JSON.stringify(design.army.westAssets)',context)),west);const normalized=schema.validate(JSON.parse(vm.runInContext('JSON.stringify(collectDesign())',context)));assert.deepEqual(normalized.army.greenInfantry,[]);
});
