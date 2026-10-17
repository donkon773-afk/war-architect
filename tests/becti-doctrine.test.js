'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {roles}=require('../tools/becti-doctrine-config');
test('combat doctrine separates fighters, bombers and air defense and excludes radar/UAV from crewed AA',()=>{
 const rows=[{class:'F16_B52_BLU',category:'PLANE',cargo:0},{class:'RHS_TU95MS_vvs_tambov',category:'PLANE',cargo:0},{class:'testSam',category:'SAM'},{class:'testRadar',category:'RADAR'},{class:'testDrone',category:'SAM',isUav:true},{class:'testTank',category:'TANK'}];
 const result=roles({classes:['B_Soldier_F','B_Soldier_LAT_F'],shop:rows.map(r=>({class:r.class}))},new Map(rows.map(r=>[r.class,r])));
 const pool=name=>result.find(r=>r[0]===name)?.[1].map(r=>r[0]);
 assert.deepEqual(pool('AirIntercept'),['F16_B52_BLU']);assert.deepEqual(pool('AirBomber'),['RHS_TU95MS_vvs_tambov']);assert.deepEqual(pool('AntiAir'),['testSam']);assert.deepEqual(pool('Armored'),['testTank']);assert.deepEqual(pool('InfantryAT'),['B_Soldier_LAT_F']);assert.equal(pool('Mechanized'),undefined);
});
test('an infantry-only edited preset cannot make the AI order an unselected vehicle',()=>{
 const result=roles({classes:['custom_rifleman'],shop:[]},new Map([['testTank',{class:'testTank',category:'TANK'}]]));
 assert.deepEqual(result,[['Infantry',[['custom_rifleman',1]],'Barracks','INFANTRY']]);
});
