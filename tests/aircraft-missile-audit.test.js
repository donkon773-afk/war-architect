'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),{category,reference}=require('../tools/aircraft-missile-references');
const row=(ammoClass,label='',simulation='shotMissile')=>({ammoClass,label,game:{simulation}});
test('aircraft missile inventory excludes simulated missile bombs, tanks and sensor pods',()=>{
 for(const id of ['Bo_Mk82','ace_missile_gbu_12','TT_agm154','M_MAML_AT'])assert.equal(category(row(id)),'Бомба/планирующий боеприпас');
 for(const id of ['DummyPylonAmmo','rhs_ammo_ptb1150','js_a_fa18_altflir_pod','rhs_ammo_l159_fuelpod_proxy'])assert.equal(category(row(id)),'Служебная подвеска/не ракета');
 assert.equal(category(row('CUP_AGM65pod_AT','1x AGM65')),'Управляемая ракета');
 assert.equal(category(row('rhs_ammo_s25l')),'Управляемая ракета');assert.equal(category(row('rhs_ammo_s25of')),'НАР');assert.equal(category(row('UK3CB_BAF_M_CRV7_PG_FAT')),'Управляемая ракета');
});
test('case and inherited convenience names do not confuse real prototype families',()=>{
 assert.equal(reference('ace_missile_aim120_r77').id,'Р-77 / РВВ-АЕ');assert.equal(reference('CUP_M_9K121_Vikhr_AT16_Scallion_AT').id,'9М127 Вихрь');assert.equal(reference('ACE_Hydra70_DAGR').id,'DAGR / PGM');assert.equal(reference('rhs_ammo_r74m2').id,'Р-73 / Р-74');assert.equal(reference('ammo_Missile_AMRAAM_D').id,'AIM-120');assert.equal(reference('unknown'),null);
});
