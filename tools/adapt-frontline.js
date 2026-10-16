'use strict';
// Adapt the installed game's native FSM through decoded SQF script fields.
// Preserve native voting/purchases; quiesce movement while NeroAI owns a group.
const fs=require('node:fs'),path=require('node:path');
function decode(raw){return [...raw.matchAll(/"((?:""|[^"])*)"/g)].map(m=>m[1].replaceAll('""','"')).join('\n');}
function encode(code){return code.split('\n').map(s=>'"'+s.replaceAll('"','""')+'"').join(' \\n\n');}
const init=/\/\*%FSM<STATEINIT""">\*\/([\s\S]*?)\/\*%FSM<\/STATEINIT""">\*\//g;
const cond=/\/\*%FSM<CONDITION""">\*\/([\s\S]*?)\/\*%FSM<\/CONDITION""">\*\//g;
function fields(s,re,fn){return s.replace(re,(all,raw)=>all.replace(raw,encode(fn(decode(raw)))));}
const owned='(((group _this) getVariable ["NeroAI_active",false]) || {(group _this) getVariable ["NeroAI_playerHold",false]} || {diag_tickTime < ((group _this) getVariable ["NeroAI_manualOrderUntil",0])})';
function adaptCore(source){
 let changed=0;
 source=fields(source,cond,code=>{
  if(code==='_base in [BIS_WL_currentSector_WEST, BIS_WL_currentSector_EAST]'){changed++;return '[_this,_base] call NeroAI_fnc_wlNativeDefense';}
  return code.replaceAll('!isNull (missionNamespace getVariable _currentSectorVarID)','!isNull ([_this,missionNamespace getVariable _currentSectorVarID] call NeroAI_fnc_wlNativeAttackTarget)');
 });
 if(changed!==9)throw Error('Native base defense transition count changed: '+changed);
 source=source.replace(/\/\*%FSM<STATE "([^"]+)">\*\/[\s\S]*?\/\*%FSM<\/STATE>\*\//g,(state,name)=>{
  if(name==='INIT')state=fields(state,init,code=>code.replace('if (!isPlayer _this && alive _this && _this distance _oldPos < 1 && vehicle _this == _this)', 'if (!'+owned+' && {!isPlayer _this} && {alive _this} && {_this distance _oldPos < 1} && {vehicle _this == _this})'));
  else if(!['debug_info','terminate'].includes(name))state=fields(state,init,code=>{
   code=code.replace('_curSector = missionNamespace getVariable _currentSectorVarID;', '_curSector = [_this,missionNamespace getVariable _currentSectorVarID] call NeroAI_fnc_wlNativeAttackTarget;');
   // FSM links evaluate in the state scope, including lower-priority links.
   // Keep timers and the contact predicate there even while movement is owned.
   const bookkeeping=[];
   code=code.replace(/^(_t\w+\s*=\s*[^\n]+|_enemiesNear\s*=\s*[^\n]+)$/gm,line=>{bookkeeping.push(line.endsWith(';')?line:line+';');return '';});
   return bookkeeping.join('\n')+'\nif (!'+owned+') then {\n'+code+'\n};';
  });
  if(!['debug_info','terminate'].includes(name))state=state.replace(/class Links\s*\{/,'class Links {\nclass nero_owned {priority=20;to="nero_controlled";condition="'+owned.replaceAll('"','""')+'";action="";};');
  if(['defend','defend_1'].includes(name))state=state.replace(/class Links\s*\{/,'class Links {\nclass reconsider {priority=5;to="status_";condition="!([_this,_base] call NeroAI_fnc_wlNativeDefense)";action="";};');
  return state;
 });
 const extra=`class nero_controlled {
 name="NeroAI control";
 init=${encode('_tVoting = (call BIS_fnc_WLSyncedTime) + (BIS_WL_selectionTimeout * 0.2) + random (BIS_WL_selectionTimeout * 0.5);\n_neroNext = time+1;\n[_this] call NeroAI_fnc_wlControlledTick;')};
 class Links {
 class dead {priority=30;to="debug_info";condition="isPlayer _this || {!alive _this}";action="";};
 class released {priority=20;to="status_";condition=${encode('!'+owned)};action="";};
 class tick {priority=0;to="nero_controlled";condition="time >= _neroNext";action="";};
 } };
`;
 const end=/\n\s*};\s*initState="INIT";/;
 if(!end.test(source))throw Error('Native FSM states terminator changed');
 if(!/finalStates\[\]\s*=\s*\{[^}]*"defend_1"/.test(source))throw Error('Native terminal defense state changed');
 source=source.replace(/finalStates\[\]\s*=\s*\{[^}]*};/,'finalStates[]={"terminate"};');
 return source.replace(end,'\n'+extra+'\n};\ninitState="INIT";');
}
function adaptCapture(source){
 let changed=0;
 source=fields(source,init,code=>{
  for(const side of ['EAST','WEST']){
   const before=`(this && (((thisTrigger getVariable 'BIS_WL_parentSector') in BIS_WL_conqueredSectors_${side}) || (thisTrigger getVariable 'BIS_WL_parentSector') == BIS_WL_currentSector_${side}))`;
   const after=`(this && ([(thisTrigger getVariable 'BIS_WL_parentSector'),${side}] call NeroAI_fnc_wlCaptureAllowed))`;
   if(code.includes(before)){code=code.replace(before,after);changed++;}
   const ownership=`(thisTrigger getVariable 'BIS_WL_parentSector') setVariable ['BIS_WL_sectorSide', ${side}, TRUE];`;
   if(code.includes(ownership))code=code.replace(ownership,ownership+" missionNamespace setVariable ['NeroWL_frontlineFrame',[-1,createHashMap]];");
  }return code;
 });
 if(changed!==2)throw Error('Native capture trigger conditions changed: '+changed);
 return source;
}
function adaptPath(source){
 const anchor='(leader _grp) setVariable ["BIS_WL_curWP", _wp1];';
 if(!source.includes(anchor))throw Error('Native path ownership anchor changed');
 return 'if ((_this # 0) getVariable ["NeroAI_active",false]) exitWith {};\n'+source.replace(anchor,anchor+'\n_grp setVariable ["NeroWL_nativeWaypoints",[_wp1,_wp2]];');
}
function write(root=path.resolve(__dirname,'..')){
 const jobs=[['fn_WLAICore.fsm',adaptCore],['fn_WLSectorHandleServer.fsm',adaptCapture],['fn_WLAIPathSegmentation.sqf',adaptPath]];
 return jobs.map(([name,fn])=>{const out=path.join(root,'addons/NeroAI3/functions/native',name);fs.writeFileSync(out,fn(fs.readFileSync(path.join(root,'research/native/Warlords',name),'latin1')),'latin1');return out;});
}
if(require.main===module)console.log(write().join('\n'));module.exports={decode,encode,adaptCore,adaptCapture,adaptPath,write};
