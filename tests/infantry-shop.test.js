'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os'),vm=require('node:vm');
const editor=require('../control-center/warlords-editor'),parse=require('../tools/validate-mission').parseConfig;
const pick=side=>editor.inventory().assets.find(a=>a.side===side&&a.kind==='INFANTRY'&&a.faction&&(side!==1||a.faction!==editor.defaults().westFaction));
test('old presets retain automatic infantry, default prices and faction commanders',()=>{
 const army=editor.validate(editor.defaults());for(const p of ['west','east','green']){assert.equal(army[p+'Infantry'],null);assert.deepEqual(army[p+'InfantryCosts'],{});}
 const preset=parse(editor.preset(army)).classes.CfgWLRequisitionPresets.classes.NeroWL_RHSStart;
 for(const p of ['west','east']){const rows=editor.infantry(army,p);assert(rows.length>0&&rows.length<=12);assert(rows.every(a=>a.faction===army[p+'Faction']&&a.price===100));assert.deepEqual(Object.keys(preset.classes[p.toUpperCase()].classes.Infantry.classes),rows.map(a=>a.class));}
});
test('custom infantry and prices become exact CP catalogs, preserving commander faction',()=>{
 const w=pick(1),e=pick(0),army=editor.validate({...editor.defaults(),westInfantry:[w.class,w.class],eastInfantry:[e.class],westInfantryCosts:{[w.class]:245},eastInfantryCosts:{[e.class]:360}});
 assert.deepEqual(army.westInfantry,[w.class]);assert.equal(editor.commander(army,'west'),editor.commander(editor.defaults(),'west'));
 const preset=parse(editor.preset(army)).classes.CfgWLRequisitionPresets.classes.NeroWL_RHSStart;
 for(const [p,a,cost] of [['WEST',w,245],['EAST',e,360]]){const rows=preset.classes[p].classes.Infantry.classes;assert.deepEqual(Object.keys(rows),[a.class]);assert.equal(rows[a.class].values.cost,cost);}
 assert(editor.mods(army).includes(w.modPath));
 const auto=editor.validate({...editor.defaults(),westInfantryCosts:{[editor.infantry(editor.defaults(),'west')[0].class]:500}});assert.equal(editor.infantry(auto,'west')[0].price,500);
});
test('invalid classes, wrong side, empty lists and invalid CP prices fail before launch',()=>{
 const w=pick(1),e=pick(0),tank=editor.inventory().assets.find(a=>a.side===1&&a.kind==='TANK');
 for(const ids of [[],[e.class],[tank.class],['missing_class'],[w.class+'; bad'],Array(257).fill(w.class),'wrong'])assert.throws(()=>editor.validate({...editor.defaults(),westInfantry:ids}));
 for(const cost of [0,59,50001,100.5,'100',null])assert.throws(()=>editor.validate({...editor.defaults(),westInfantryCosts:{[w.class]:cost}}));
 assert.throws(()=>editor.validate({...editor.defaults(),westInfantryCosts:{[e.class]:100}}));assert.throws(()=>editor.validate({...editor.defaults(),westInfantryCosts:[]}));
});
test('three-side generated catalog respects chosen green infantry and CP',()=>{
 const g=pick(2),army=editor.validate({...editor.defaults(),greenInfantry:[g.class],greenInfantryCosts:{[g.class]:410}}),schema=require('../control-center/scenario-design'),d=schema.blank('Australia');
 d.mode='three';d.greenFaction='rhsgref_faction_cdf_ng';d.bases.push({id:'green',name:'Green',side:'GUER',position:[20000,20000],radius:200});
 const out=fs.mkdtempSync(path.join(os.tmpdir(),'nero-infantry-'));
 try{require('../tools/build-three-mission').build(d,{army,commanders:10},out,'');const rows=parse(fs.readFileSync(path.join(out,'neroDesign/preset.hpp'),'utf8')).classes.CfgWLRequisitionPresets.classes.NeroWL_RHSStart.classes.GUER.classes.Infantry.classes;assert.deepEqual(Object.keys(rows),[g.class]);assert.equal(rows[g.class].values.cost,410);assert(editor.mods(army).includes(g.modPath));}finally{fs.rmSync(out,{recursive:true,force:true});}
});
test('infantry UI keeps selections across filters, prices and profile roundtrip',()=>{
 const html=fs.readFileSync('control-center/index.html','utf8'),script=html.match(/<script>([\s\S]*?)<\/script>/)[1];new vm.Script(script);
 const elements=new Map();function el(){return {value:'',checked:false,children:[],style:{},classList:{toggle(){}},append(...x){this.children.push(...x);},replaceChildren(...x){this.children=x;},setAttribute(){},addEventListener(){}};}
 const by=id=>{if(!elements.has(id))elements.set(id,el());return elements.get(id);};
 const context=vm.createContext({document:{createElement:el},by,options:(element,entries)=>{element.entries=entries;},catalog:editor.inventory(),dirty:false,message(){}});
 vm.runInContext(script.slice(script.indexOf('const infState='),script.indexOf('async function readJournal()')),context);
 by('infSide').value='west';by('infShow').value='all';by('westFaction').value=editor.defaults().westFaction;by('eastFaction').value=editor.defaults().eastFaction;
 const w=pick(1),army=editor.validate({...editor.defaults(),westInfantry:[w.class],westInfantryCosts:{[w.class]:245}});context.army=army;
 vm.runInContext('applyInfantry(army)',context);by('infSearch').value='no-matching-unit';by('infSearch').oninput();
 let result=JSON.parse(vm.runInContext('JSON.stringify(infantrySelection())',context));assert.deepEqual(result.westInfantry,[w.class]);assert.equal(result.westInfantryCosts[w.class],245);
 by('infSearch').value='';by('infShow').value='selected';by('infSearch').oninput();const price=by('infRows').children[0].children[1];price.value='320';price.onchange();result=JSON.parse(vm.runInContext('JSON.stringify(infantrySelection())',context));assert.equal(result.westInfantryCosts[w.class],320);
 by('infMode').value='auto';by('infMode').onchange();result=JSON.parse(vm.runInContext('JSON.stringify(infantrySelection())',context));assert.equal(result.westInfantry,null);
 vm.runInContext('applyInfantry(army)',context);result=JSON.parse(vm.runInContext('JSON.stringify(infantrySelection())',context));assert.deepEqual(result.westInfantry,[w.class]);
});
