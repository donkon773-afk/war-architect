/* Pure composition helpers shared by the library, launcher and map editor. */
const NeroSideSetups=(()=>{
  const sides={west:'Синие',east:'Красные',green:'Зелёные'};
  function side(p){if(!Object.hasOwn(sides,p))throw Error('Неизвестная сторона сетапа.');return p;}
  function draft(army,p){side(p);return {side:p,faction:army[p+'Faction'],assets:[...(army[p+'Assets']||[])],infantry:army[p+'Infantry']==null?null:[...army[p+'Infantry']],infantryCosts:{...(army[p+'InfantryCosts']||{})}};}
  function apply(army,value,p=value.side){side(p);if(value.side!==p)throw Error('Сетап предназначен для другой стороны.');return {...structuredClone(army),[p+'Faction']:value.faction,[p+'Assets']:[...value.assets],[p+'Infantry']:value.infantry===null?null:[...value.infantry],[p+'InfantryCosts']:{...value.infantryCosts}};}
  function clear(value,part='all'){if(!['all','assets','infantry'].includes(part))throw Error('Неизвестный состав.');const v=structuredClone(value);if(part!=='infantry')v.assets=[];if(part!=='assets'){v.infantry=[];v.infantryCosts={};}return v;}
  return {sides,side,draft,apply,clear};
})();
if(typeof module==='object')module.exports=NeroSideSetups;
