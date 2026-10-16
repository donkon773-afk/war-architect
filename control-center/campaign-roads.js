'use strict';
// Read existing map geometry; keep legacy WRP roads and Terrain Builder roads.
const fs=require('node:fs'),path=require('node:path'),cache=new Map();
function fromVector(v){const segments=[],add=(a,b)=>{if(Math.hypot(a[0]-b[0],a[1]-b[1])>.2)segments.push([a,b]);};
 for(const kind of ['main','road','track']){const f=v.layers[kind]||[];for(let p=0;p+7<f.length;p+=8){const q=[0,1,3,2].map(i=>[f[p+i*2]/10,f[p+i*2+1]/10]),mid=(a,b)=>a.map((n,i)=>(n+b[i])/2),one=[mid(q[0],q[1]),mid(q[2],q[3])],two=[mid(q[1],q[2]),mid(q[3],q[0])],dist=s=>Math.hypot(s[0][0]-s[1][0],s[0][1]-s[1][1]);if(Math.min(dist(one),dist(two))>=3)add(...(dist(one)>dist(two)?one:two));}}
 const f=v.layers.roadline||[];for(let p=0;p<f.length;){const n=f[p++],width=f[p++];p++;let previous=null;for(let i=0;i<n;i++){const q=[f[p++]/10,f[p++]/10];if(previous&&width>=30)add(previous,q);previous=q;}}
 return segments;
}
function segments(w){const file=path.join(__dirname,'data','map-tiles',w.id,'vector.json');if(!fs.existsSync(file))return [];const stamp=fs.statSync(file).mtimeMs;if(cache.get(w.id)?.stamp===stamp)return cache.get(w.id).segments;const v=JSON.parse(fs.readFileSync(file,'utf8'));if(v.units!=='dm'||v.worldSize!==w.size)return [];const value=fromVector(v);if(cache.size>=4)cache.delete(cache.keys().next().value);cache.set(w.id,{stamp,segments:value});return value;}
function nearest(w,point){let best=null;for(const [a,b]of segments(w)){const dx=b[0]-a[0],dy=b[1]-a[1],length=Math.hypot(dx,dy),t=Math.max(0,Math.min(1,((point[0]-a[0])*dx+(point[1]-a[1])*dy)/(length*length))),position=[a[0]+dx*t,a[1]+dy*t],distance=Math.hypot(point[0]-position[0],point[1]-position[1]);if(!best||distance<best.distance)best={position,distance,normal:[-dy/length,dx/length]};}return best;}
function snap(w,point){const road=nearest(w,point);if(!road||road.distance>1600)return [...point];return road.position.map((n,i)=>Math.round(Math.max(500,Math.min(w.size-500,n+80*road.normal[i]))*100)/100);}
module.exports={fromVector,segments,nearest,snap};
