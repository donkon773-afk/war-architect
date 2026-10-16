"use strict";
// Read-only RAP metadata decoder, based on BI's documented Elite RAP format.
const fs = require("node:fs"), path = require("node:path");
function decodeRap(buf) {
  if (buf.subarray(0,4).toString("latin1") !== "\0raP") throw new Error("Not a RAP config");
  function cursor(offset) {
    return {offset, byte(){if(this.offset>=buf.length)throw new Error("RAP truncated");return buf[this.offset++];},
      str(){const end=buf.indexOf(0,this.offset);if(end<0)throw new Error("RAP string truncated");const v=buf.toString("utf8",this.offset,end);this.offset=end+1;return v;},
      u32(){const v=buf.readUInt32LE(this.offset);this.offset+=4;return v;},
      number(type){if(type===0||type===4)return this.str();if(type===1){const v=buf.readFloatLE(this.offset);this.offset+=4;return v;}if(type===2){const v=buf.readInt32LE(this.offset);this.offset+=4;return v;}if(type===6){const v=Number(buf.readBigInt64LE(this.offset));this.offset+=8;return v;}if(type===3)return array(this);throw new Error(`RAP value type ${type}`);},
      count(){let n=0,s=0,b;do{b=this.byte();n|=(b&127)<<s;s+=7;if(s>35)throw new Error("RAP count too long");}while(b&128);if(n<0||n>100000)throw new Error("RAP count excessive");return n;}};
  }
  function array(c){return Array.from({length:c.count()},()=>c.number(c.byte()));}
  const active=new Set();
  function body(offset) {
    if (offset<16||offset>=buf.length||active.has(offset))throw new Error("Invalid RAP class offset");
    active.add(offset);const c=cursor(offset), node={parent:c.str(),values:{},classes:{}};
    const entries=c.count();
    for(let i=0;i<entries;i++) {
      const type=c.byte();
      if(type===0){const name=c.str(),pos=c.u32();node.classes[name]=body(pos);}
      else if(type===1){const sub=c.byte(),name=c.str();node.values[name]=c.number(sub);}
      else if(type===2){const name=c.str();node.values[name]=array(c);}
      else if(type===3||type===4){c.str();}
      else if(type===5){c.u32();const name=c.str();node.values[name]=array(c);}
      else throw new Error(`RAP entry ${type} at ${c.offset-1}`);
    }
    active.delete(offset);return node;
  }
  return body(16);
}
function worldMetadata(file,name) {
  const root=decodeRap(fs.readFileSync(file));
  const world=Object.entries(root.classes.CfgWorlds?.classes||{}).find(([n])=>n.toLowerCase()===name.toLowerCase())?.[1];
  if(!world)throw new Error(`World ${name} absent`);
  const locations=Object.entries(world.classes.Names?.classes||{}).map(([id,node])=>({id,...node.values})).filter(v=>Array.isArray(v.position));
  const airports=[{id:0,...world.values},...Object.values(world.classes.SecondaryAirports?.classes||{}).map((n,i)=>({id:i+1,...n.values}))]
    .filter(a=>Array.isArray(a.ilsPosition)).map(a=>({id:a.id,position:a.ilsPosition,direction:a.ilsDirection}));
  return {name,source:path.resolve(file),size:world.values.worldSize,locations,airports};
}
if(require.main===module){const [,,file,name]=process.argv;const data=worldMetadata(file,name);const out=path.join(path.dirname(file),"metadata.json");fs.writeFileSync(out,JSON.stringify(data,null,2));console.log(`${name}: ${data.locations.length} locations, ${data.airports.length} configured airports`);}
module.exports={decodeRap,worldMetadata};
