'use strict';
const fs=require('node:fs'),p=require('node:path').join(__dirname,'campaign-assets/fn_campaignAirDefense.sqf');let s=fs.readFileSync(p,'utf8');
const start=s.indexOf('   if !(_v getVariable ["NeroOP_adInit",false]) then {'),end=s.indexOf('   if (_static) then {',start);if(start<0||end<0)throw Error('AD init anchors absent');
const init=s.slice(start,end);s=s.slice(0,start)+s.slice(end);
const anchor=' private _radars=_all select';if(!s.includes(anchor))throw Error('AD frame anchor absent');
s=s.replace(anchor,' {private _v=_x;private _original=getText(configFile >> "CfgVehicles" >> typeOf _v >> "NeroAD_original");if (_original=="") then {_original=typeOf _v;};_v setVariable ["NeroOP_adOriginal",_original];private _cfg=configFile >> "CfgNeroAirDefense" >> _original;\n'+init+' } forEach _all;\n'+anchor);
// Every turret owner converts its own magazines; the vehicle owner alone drives AI/radar policy.
const anchor2=' {private _v=_x;if (local _v) then {\n  private _original=_v getVariable';
const converter=' {private _v=_x;private _o=_v getVariable ["NeroOP_adOriginal",typeOf _v];private _cfg=configFile >> "CfgNeroAirDefense" >> _o;if (getNumber(_cfg >> "stationary")==1 && {getText(_cfg >> "category") in ["AAA","SAM"]}) then {private _side=[west,east] find side group effectiveCommander _v;private _linked=_radars findIf {private _f=_x getVariable ["NeroOP_adRadarFrame",[-10,-1,0,[]]];(_f#1)==_side && {_side in [0,1]} && {_v distance _x<=3000} && {serverTime-(_f#0)<=2}}>=0;[_v,_linked] call NeroOP_fnc_campaignADMagazine;};} forEach _all;\n';
if(!s.includes(anchor2))throw Error('AD owner anchor absent');s=s.replace(anchor2,converter+anchor2);
fs.writeFileSync(p,s);
const mag=require('node:path').join(__dirname,'campaign-assets/fn_campaignADMagazine.sqf');let m=fs.readFileSync(mag,'utf8');m=m.replace('!local _v || {_v getVariable ["NeroOP_adMagazineLinked",false] isEqualTo _linked}','_v getVariable ["NeroOP_adMagazineLinked",false] isEqualTo _linked');fs.writeFileSync(mag,m);
const t=require('node:path').join(__dirname,'../tests/campaign-operations.test.js');let ts=fs.readFileSync(t,'utf8');ts=ts.replace('report.parsedFiles,87','report.parsedFiles,92').replace('report.assertions,184','report.assertions,203').replace('report.pureFunctions.length,26','report.pureFunctions.length,28');fs.writeFileSync(t,ts);
console.log('Turret ownership and extended regression counts integrated');
