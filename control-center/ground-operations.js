'use strict';
const worlds=require('./scenario-design'),editor=require('./warlords-editor');
const sides=['WEST','EAST'];
function catalog(){return editor.inventory().assets.filter(a=>a.kind==='INFANTRY'&&[0,1].includes(a.side)&&!/(?:^|_)VR(?:_|$)/i.test(a.class)).map(a=>({class:a.class,label:require("./asset-names").label(a),side:a.side===1?'WEST':'EAST',faction:a.faction,mod:a.mod,modPath:a.modPath}));}
function number(n,min,max,name,integer=true){if(typeof n!=='number'||!Number.isFinite(n)||(integer&&!Number.isInteger(n))||n<min||n>max)throw Error(`${name}: от ${min} до ${max}.`);return n;}
function point(p,w,name){if(!Array.isArray(p)||p.length!==2)throw Error(`${name}: нужны X и Y.`);return p.map(n=>number(n,500,w.size-500,name,false));}
function validate(v){
 if(!v||v.version!==1||v.type!=='assaultDefense')throw Error('Неизвестный наземный сценарий.');
 const w=worlds.world(v.world),x=catalog();if(w.size<5000)throw Error('Для штурма нужна карта от 5 км.');
 if(typeof v.title!=='string'||!v.title.trim()||v.title.trim().length>100||/[\x00-\x1f]/.test(v.title))throw Error('Название: 1–100 символов.');
 if(!['commander','observer'].includes(v.playerRole)||!sides.includes(v.playerSide)||!sides.includes(v.attackerSide))throw Error('Выберите роль игрока и атакующую сторону.');
 if(!Array.isArray(v.sides)||v.sides.length!==2||sides.some(s=>v.sides.filter(a=>a.side===s).length!==1))throw Error('Нужны синие и красные наземные силы.');
 const armies=sides.map(side=>{const a=v.sides.find(a=>a.side===side);if(!Array.isArray(a.classes)||!a.classes.length||a.classes.some(id=>typeof id!=='string'||!x.some(c=>c.class===id&&c.side===side)))throw Error('Выберите классы доступной пехоты своей стороны.');return {side,classes:[...new Set(a.classes)],active:number(a.active,1,20,'Активных отрядов'),reserve:number(a.reserve,0,12,'Резервных отрядов'),groupSize:number(a.groupSize,2,8,'Бойцов AI в отряде'),skill:number(a.skill,.2,1,'Уровень AI',false),entry:point(a.entry,w,'Точка подкреплений')};});
 if(Math.hypot(...armies[0].entry.map((n,i)=>n-armies[1].entry[i]))<1500)throw Error('Разведите точки сторон минимум на 1,5 км.');
 const zone={position:point(v.zone?.position,w,'Цель штурма'),radius:number(v.zone?.radius,100,600,'Радиус захвата')};
 for(const a of armies)if(Math.hypot(...a.entry.map((n,i)=>n-zone.position[i]))<zone.radius+300)throw Error('Точка подкреплений должна находиться вне цели, с запасом 300 м.');
 const slots=number(v.playerSlots,1,20,'Слотов на сторону');if(slots>Math.min(...armies.map(a=>a.active)))throw Error('Слотов игроков не должно быть больше активных отрядов на сторону.');
 return {version:1,type:'assaultDefense',world:w.id,title:v.title.trim(),playerRole:v.playerRole,playerSide:v.playerSide,attackerSide:v.attackerSide,sides:armies,zone,playerSlots:slots,duration:number(v.duration,5,120,'Длительность'),captureSeconds:number(v.captureSeconds,30,600,'Время захвата'),reinforcementDelay:number(v.reinforcementDelay,15,180,'Интервал подкреплений'),hour:number(v.hour,0,23,'Час начала'),overcast:number(v.overcast,0,.8,'Облачность',false),extraMods:require('./operation-mods').validate(v.extraMods)};
}
function defaults(world='Australia'){
 const w=worlds.world(world),x=catalog(),choose=(side,ids)=>ids.filter(id=>x.some(c=>c.side===side&&c.class===id));
 const west=choose('WEST',['rhsusf_army_ocp_rifleman','rhsusf_army_ocp_autorifleman','rhsusf_army_ocp_grenadier','rhsusf_army_ocp_medic']),east=choose('EAST',['rhs_msv_rifleman','rhs_msv_machinegunner','rhs_msv_grenadier','rhs_msv_medic']);
 if(!west.length)west.push(x.find(c=>c.side==='WEST')?.class);if(!east.length)east.push(x.find(c=>c.side==='EAST')?.class);
 const center=(w.locations?.find(p=>p.name==='Alice Springs')||w.locations?.find(p=>p.position[0]>2000&&p.position[1]>2000&&p.position[0]<w.size-2000&&p.position[1]<w.size-2000))?.position||[w.size/2,w.size/2];
 return validate({version:1,type:'assaultDefense',world:w.id,title:'NeroAI — '+w.label+': штурм и оборона',playerRole:'commander',playerSide:'WEST',attackerSide:'WEST',sides:[{side:'WEST',classes:west,active:3,reserve:3,groupSize:6,skill:.65,entry:[center[0]-1200,center[1]-500]},{side:'EAST',classes:east,active:3,reserve:3,groupSize:6,skill:.65,entry:[center[0]+900,center[1]+600]}],zone:{position:[...center],radius:250},playerSlots:2,duration:30,captureSeconds:120,reinforcementDelay:45,hour:9,overcast:.15});
}
module.exports={catalog,validate,defaults};
