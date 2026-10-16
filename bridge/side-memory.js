'use strict';
const {parseSqfValue,validateModelResponse,isGroundedPosition}=require('./protocol');
// Config instances identify bridge runs; mission + actual side identify memories.
const stores=new WeakMap();const TTL=30*60*1000;
function field(snapshot,name,fallback=''){try{const a=parseSqfValue(String(snapshot));if(!Array.isArray(a))return fallback;for(let i=0;i<a.length;i+=2)if(a[i]===name)return a[i+1];}catch{}return fallback;}
function identity(snapshot){const side=field(snapshot,'side');if(!['BLUE','RED','GREEN'].includes(side))return '';const session=field(snapshot,'session','bridge');if(typeof session!=='string'||session.length>160)return '';return session+'/'+side;}
function store(config){let s=stores.get(config);if(!s){s=new Map();stores.set(config,s);}return s;}
function recall(config,snapshot,now=Date.now()){const key=identity(snapshot);if(!key)return [];const s=store(config);for(const [k,v] of s)if(now-v.at>TTL)s.delete(k);return (s.get(key)?.rows||[]).map(r=>structuredClone(r));}
function remember(config,snapshot,raw,now=Date.now()){
 const key=identity(snapshot);if(!key)return;let result;try{result=validateModelResponse(raw,config.limits);}catch{return;}
 if(result.ok!==true)return;
 const actions=result.actions.filter(a=>!a[1]?.length||isGroundedPosition(a[1],snapshot)).slice(0,4);
 // Remember validated decisions only, not a second copy of all enemy observations.
 const row={group:String((field(snapshot,'groups',[])?.[0]||[])[0]||'').slice(0,60),actions};
 if(!actions.length)return;
 const rows=recall(config,snapshot,now);rows.push(row);const s=store(config);s.set(key,{at:now,rows:rows.slice(-4)});while(s.size>32)s.delete(s.keys().next().value);
}
module.exports={field,identity,recall,remember};
