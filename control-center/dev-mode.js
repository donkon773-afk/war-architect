'use strict';
// One registry for the UI, saved profiles and generated mission configuration.
const catalog = [
  {id:'transportDrop',title:'Десант с транспортного самолёта',description:'ИИ доставляет пополнение вне базы физическим самолётом и выбирает безопасный союзный сектор. На базе бойцы появляются на земле. При отключении вне базы используется обычная доставка Warlords.',stage:'experimental',default:true,field:'transportDrop'},
  {id:'vehicleCrew',title:'Покупка техники с экипажем',description:'Купленная через NeroAI наземная техника получает необходимый экипаж. При отключении бойцы занимают машину обычным способом.',stage:'experimental',default:true,field:'vehicleCrew'},
  {id:'fieldRepair',title:'Самостоятельный ремонт и прикрытие',description:'В тактическом режиме повреждённая техника запрашивает механика или прикрытие, ремонтируется либо отходит по обстановке. При отключении автоматический цикл выключен; ручной приказ ремонта остаётся доступен.',stage:'experimental',default:true,field:'fieldRepair'}
];
function normalize(value,entries=catalog){
  if(value===undefined)value={enabled:true,features:{}}; // Preserve pre-DevMode profiles.
  if(!value||typeof value!=='object'||Array.isArray(value)||typeof value.enabled!=='boolean')throw Error('DevMode: некорректный переключатель режима.');
  const features=value.features??{};
  if(!features||typeof features!=='object'||Array.isArray(features))throw Error('DevMode: некорректный список обновлений.');
  for(const [key,v] of Object.entries(features))if(!entries.some(e=>e.id===key)||typeof v!=='boolean')throw Error('DevMode: неизвестное обновление или неверное значение: '+key);
  return {enabled:value.enabled,features:Object.fromEntries(entries.map(e=>[e.id,features[e.id]??e.default]))};
}
function effective(selection,entries=catalog){
  const mode=normalize(selection.devMode,entries);
  return Object.fromEntries(entries.map(e=>[e.field,e.stage==='stable' ? (selection.parameters?.[e.parameter]??Number(mode.features[e.id]))===1 : mode.enabled&&mode.features[e.id]]));
}
function config(selection){
  return 'class CfgNeroExperiments { '+Object.entries(effective(selection)).map(([key,v])=>key+'='+Number(v)+';').join(' ')+' };\n';
}
module.exports={catalog,normalize,effective,config};
