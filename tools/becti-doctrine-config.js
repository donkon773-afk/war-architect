'use strict';
const equipment=require('../control-center/campaign-equipment');
function roles(army,catalog){
 const infantry=army.classes.map(c=>[c,1]),selected=army.shop.map(r=>catalog.get(r.class)).filter(Boolean);
 const pool=fn=>selected.filter(fn).map(r=>[r.class,1]);
 return [
  ['Infantry',infantry,'Barracks','INFANTRY'],
  ['InfantryAT',infantry.filter(r=>/_at|_lat|maaws|antitank/i.test(r[0])),'Barracks','INFANTRY'],
  ['InfantryAA',infantry.filter(r=>/_aa|anti.?air/i.test(r[0])),'Barracks','INFANTRY'],
  ['Motorized',pool(r=>r.category==='CAR'),'Light','LIGHT'],
  ['Mechanized',pool(r=>r.category==='APC'),'Heavy','HEAVY'],
  ['Armored',pool(r=>r.category==='TANK'),'Heavy','HEAVY'],
  ['AntiAir',pool(r=>['AAA','SAM'].includes(r.category)&&!r.isUav),'Light','LIGHT'],
  ...[['AirIntercept','FIGHTER'],['AirCAS','CAS'],['AirHeli','ATTACK_HELI'],['AirBomber','BOMBER']].map(([name,role])=>[name,pool(r=>equipment.aiRole(r)===role),'Air','AIR'])
 ].filter(r=>r[1].length);
}
module.exports={roles};
