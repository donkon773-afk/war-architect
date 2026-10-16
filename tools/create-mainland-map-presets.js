'use strict';
/* Additive map layouts. Never applies a design or changes the current selection. */
const fs=require('fs'),path=require('path'),schema=require('../control-center/scenario-design'),land=require('../control-center/campaign-land'),store=require('../control-center/map-presets');
function layout(w){
 const t=land.terrain(w),n=t.grid,original=Buffer.from(t.land,'base64'),step=w.size/n;
 // Exclude narrow shore strips and fords before choosing the campaign area.
 const clearance=Math.max(1,Math.ceil(120/step)),safe=new Uint8Array(n*n);
 for(let y=clearance;y<n-clearance;y++)for(let x=clearance;x<n-clearance;x++){
  const i=y*n+x;if(original[i]&&[-clearance,0,clearance].every(dy=>[-clearance,0,clearance].every(dx=>original[i+dy*n+dx]))&&land.contains(w,[(x+.5)*step,(y+.5)*step],130))safe[i]=1;
 }
 const a=land.largest(safe,n);
 const xy=i=>[(i%n+.5)*step,(Math.floor(i/n)+.5)*step];
 const index=p=>Math.floor(p[1]/step)*n+Math.floor(p[0]/step);
 const neighbours=i=>{const x=i%n,y=Math.floor(i/n);return [x?i-1:-1,x<n-1?i+1:-1,y?i-n:-1,y<n-1?i+n:-1].filter(j=>j>=0&&a[j]);};
 const v=JSON.parse(fs.readFileSync(path.join(__dirname,'../control-center/data/map-tiles',w.id,'vector.json'))).layers;
 const road=[];const raw=v.roadline||[];
 for(let k=0;k<raw.length;){const count=raw[k];k+=3;for(let j=0;j<count;j++,k+=2)road.push([raw[k]/10,raw[k+1]/10]);}
 if(!road.length)for(const kind of ['main','road','track']){const arr=v[kind]||[];for(let k=0;k<arr.length;k+=2)road.push([arr[k]/10,arr[k+1]/10]);}
 const unique=new Map();for(const p of road){if(p.some(x=>x<250||x>w.size-250)||!a[index(p)]||!land.contains(w,p,180))continue;unique.set(index(p),p);}
 let candidates=[...unique.values()];
 if(candidates.length<2)throw Error(w.id+': insufficient inland road sites');
 // Keep campaign compact even on Australia; do not put bases at opposite map edges.
 const centre=[w.size/2,w.size/2];const nearest=candidates.reduce((a,b)=>Math.hypot(...a.map((x,i)=>x-centre[i]))<Math.hypot(...b.map((x,i)=>x-centre[i]))?a:b);
 const maxSpan=Math.min(14000,w.size*.65),minSpan=Math.min(1800,w.size*.25);
 candidates=candidates.filter(p=>Math.hypot(p[0]-nearest[0],p[1]-nearest[1])<=maxSpan*.6);
 let west=candidates.reduce((a,b)=>a[0]<b[0]?a:b);
 let east=candidates.filter(p=>Math.hypot(p[0]-west[0],p[1]-west[1])<=maxSpan).reduce((a,b)=>Math.hypot(b[0]-west[0],b[1]-west[1])>Math.hypot(a[0]-west[0],a[1]-west[1])?b:a,west);
 if(east[0]<west[0])[west,east]=[east,west];
 if(Math.hypot(east[0]-west[0],east[1]-west[1])<minSpan)throw Error(w.id+': insufficient base separation');
 const start=index(west),end=index(east),parent=new Int32Array(n*n).fill(-1),queue=[start];parent[start]=start;
 for(let k=0;k<queue.length&&parent[end]<0;k++)for(const j of neighbours(queue[k]))if(parent[j]<0){parent[j]=queue[k];queue.push(j);}
 if(parent[end]<0)throw Error(w.id+': no dry route between bases');
 const route=[];for(let i=end;;i=parent[i]){route.push(i);if(i===start)break;}route.reverse();
 const count=w.size<8500?5:7,points=[];
 const title=p=>{let best=null,d=Infinity;for(const l of w.locations||[]){const dist=Math.hypot(l.position[0]-p[0],l.position[1]-p[1]);if(dist<d){d=dist;best=l;}}return best&&d<1800?best.name:'Узел маршрута';};
 for(let j=1;j<=count;j++){
  const target=xy(route[Math.round((route.length-1)*j/(count+1))]);
  const near=road.filter(p=>a[index(p)]&&land.contains(w,p,110)&&Math.hypot(p[0]-target[0],p[1]-target[1])<Math.min(1800,w.size/4));
  near.sort((a,b)=>Math.hypot(a[0]-target[0],a[1]-target[1])-Math.hypot(b[0]-target[0],b[1]-target[1]));
  const p=near.find(p=>[west,east,...points.map(x=>x.position)].every(q=>Math.hypot(p[0]-q[0],p[1]-q[1])>250))||target;
  if(!land.contains(w,p,100))throw Error(w.id+': sector lacks dry safety margin');
  points.push({id:'sector_'+j,name:j+' · '+title(p),side:'GUER',position:p.map(Math.round),radius:100,infantry:4,vehicles:0,vehicleClasses:[]});
 }
 const d={...schema.blank(w.id),title:w.label+' · компактный сухопутный фронт',playerRole:'commander',maxNPCs:160,maxVehicles:24,startCP:6000,income:100,greenFaction:'rhsgref_faction_cdf_ng',bases:[{id:'west',name:'База синих · '+title(west),side:'WEST',position:west.map(Math.round),radius:150},{id:'east',name:'База красных · '+title(east),side:'EAST',position:east.map(Math.round),radius:150}],sectors:points};
 for(const p of [...d.bases,...d.sectors])if(!land.contains(w,p.position,p.radius))throw Error(w.id+': rounded point left mainland');
 schema.validate(d,[],{draft:true});
 return {design:d,evidence:{grid:n,cellMetres:step,dryRouteCells:route.length,baseDistance:Math.round(Math.hypot(west[0]-east[0],west[1]-east[1])),roadCandidates:unique.size}};
}
function run(){const results=[];for(const w of schema.worlds()){const name=w.label+' · сухопутный фронт';const existing=store.list().find(p=>p.world===w.id&&p.name===name);if(existing){results.push({world:w.id,name,id:existing.id,sectors:existing.sectors,existing:true});console.log('EXISTS '+w.id);continue;}const r=layout(w);const saved=store.save(name,r.design,[]);results.push({world:w.id,name,id:saved.id,sectors:r.design.sectors.length,...r.evidence});console.log('SAVED '+w.id+' '+saved.id);}fs.mkdirSync(path.join(__dirname,'../dist/mainland-presets-20261016'),{recursive:true});fs.writeFileSync(path.join(__dirname,'../dist/mainland-presets-20261016/generation.json'),JSON.stringify(results,null,2));return results;}
if(require.main===module)run();module.exports={layout,run};
