'use strict';
const fs=require('node:fs'),path=require('node:path'),{parseConfig}=require('./validate-mission'),{readEntry}=require('./read-pbo-entry'),{decodeRap}=require('./read-world-config');
function validateConfig(text,native){
 const cfg=parseConfig(text),weapons=cfg.classes.CfgWeapons?.classes,base=weapons?.weapon_VLSBase,launcher=weapons?.weapon_Flamingo_01;
 const nativeBase=native.classes.CfgWeapons.classes.weapon_VLSBase;
 if(base?.parent!==nativeBase.parent||!weapons[base.parent]||!base.classes.Cruise||launcher?.parent!=='weapon_VLSBase'||launcher.classes.Cruise?.parent!=='Cruise')throw Error('NeroAI Strategic: не объявлен внешний режим Cruise с сохранением наследования weapon_VLSBase.');
 const proxy=cfg.classes.CfgVehicles.classes.NeroOP_CruiseTrack_W,hook=cfg.classes.CfgFunctions.classes.FP5.classes.scripts.classes.neroArtillery;
 if(proxy.parent!=='B_UAV_02_F'||proxy.values.simulation!==undefined)throw Error('NeroAI Strategic: radar proxy must preserve native fixed-wing simulation.');
 if(hook?.values.preInit!==1||!hook.values.file.endsWith('fn_fpArtillery.sqf'))throw Error('NeroAI Strategic: native artillery target hook missing.');
 return {externalWeaponBase:base.parent,nestedMode:'Cruise',rounds:cfg.classes.CfgMagazines.classes.magazine_FP5.values.count};
}
function verify(){
 const fp=require('../control-center/warlords-editor').inventory().mods.find(m=>m.patches.includes('kba_fp5_flamingo'));
 if(!fp)throw Error('Не найден установленный FP‑5 Flamingo.');
 const native=decodeRap(readEntry(path.join(fp.path,'addons/kba_fp5_flamingo.pbo'),'config.bin'));
 const file=path.resolve(__dirname,'../dist/strategic-compat/@NeroAI_Strategic/addons/NeroStrategic.pbo');
 const drone=decodeRap(readEntry('H:/SteamLibrary/steamapps/common/Arma 3/addons/drones_f.pbo','Air_F_Gamma/UAV_02/config.bin'));
 if(drone.classes.CfgVehicles.classes.B_UAV_02_F?.parent!=='UAV_02_base_F'||drone.classes.CfgVehicles.classes.UAV?.parent!=='Plane')throw Error('Native fixed-wing proxy base missing.');
 return {...validateConfig(readEntry(file,'config.cpp').toString('utf8'),native),pbo:file};
}
if(require.main===module)console.log(JSON.stringify(verify(),null,2));
module.exports={validateConfig,verify};
