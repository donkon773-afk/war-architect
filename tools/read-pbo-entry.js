"use strict";
// Read one uncompressed entry without loading large terrain/model PBOs in RAM.
const fs=require("node:fs"),path=require("node:path");
function expandLzss(input,expected){
  if(expected>16777216||input.length<5)throw new Error("Compressed config size invalid");
  const output=Buffer.alloc(expected);let pos=0,read=0,sum=0;
  const limit=input.length-4;
  while(pos<expected){if(read>=limit)throw new Error("LZSS truncated");const flags=input[read++];
    for(let bit=0;bit<8&&pos<expected;bit++){
      if(flags&(1<<bit)){if(read>=limit)throw new Error("LZSS literal truncated");output[pos++]=input[read++];}
      else {if(read+2>limit)throw new Error("LZSS reference truncated");const a=input[read++],b=input[read++];let from=pos-(a+((b&240)<<4));const count=(b&15)+3;
        if(from>=pos)throw new Error("LZSS reference is not backward");
        for(let i=0;i<count&&pos<expected;i++,from++)output[pos++]=from<0?32:output[from];}
    }}
  for(const byte of output)sum=(sum+byte)>>>0;
  if(sum!==input.readUInt32LE(limit))throw new Error("LZSS checksum mismatch");
  return output;
}
function readEntry(file,wanted) {
  const fd=fs.openSync(file,"r");
  try {
    let size=65536;
    while(size<=16777216){
      const b=Buffer.alloc(size),length=fs.readSync(fd,b,0,size,0);let p=0;
      function str(){const end=b.indexOf(0,p);if(end<0||end>=length)throw new RangeError("header incomplete");const v=b.toString("latin1",p,end);p=end+1;return v;}
      function u32(){if(p+4>length)throw new RangeError("header incomplete");const v=b.readUInt32LE(p);p+=4;return v;}
      const entries=[];
      try {
        while(true){const name=str(),packing=u32(),original=u32();u32();u32();const dataSize=u32();
          if(name===""&&packing===0x56657273){while(str()!=="")str();continue;}
          if(name==="")break;entries.push({name,packing,original,size:dataSize});}
      }catch(e){if(e instanceof RangeError&&length===size){size*=2;continue;}throw e;}
      let offset=p;
      for(const e of entries){if(e.name.toLowerCase().replaceAll("\\","/")===wanted.toLowerCase().replaceAll("\\","/")){
        if(e.packing!==0&&e.packing!==0x43707273)throw new Error(`Unsupported packing ${e.name}: ${e.packing}`);
        const data=Buffer.alloc(e.size);if(fs.readSync(fd,data,0,e.size,offset)!==e.size)throw new Error("Entry truncated");return e.packing===0?data:expandLzss(data,e.original);}
        offset+=e.size;}
      throw new Error(`Entry missing: ${wanted}`);
    }
    throw new Error("PBO header exceeds limit");
  } finally{fs.closeSync(fd);}
}
if(require.main===module){const [,,file,entry,out]=process.argv;fs.mkdirSync(path.dirname(out),{recursive:true});fs.writeFileSync(out,readEntry(file,entry));console.log(`Read ${entry} from ${path.basename(file)}`);}
function indexEntries(file){
 const fd=fs.openSync(file,'r');try{for(let size=65536;size<=16777216;size*=2){const b=Buffer.alloc(size),n=fs.readSync(fd,b,0,size,0);let p=0,prefix='',entries=[];
 const str=()=>{const end=b.indexOf(0,p);if(end<0||end>=n)throw new RangeError('header');const v=b.toString('latin1',p,end);p=end+1;return v;};const u=()=>{if(p+4>n)throw new RangeError('header');const x=b.readUInt32LE(p);p+=4;return x;};
 try{while(true){const name=str(),packing=u(),original=u();u();u();const length=u();if(!name&&packing===0x56657273){let k;while((k=str())!==''){const v=str();if(k==='prefix')prefix=v;}continue;}if(!name)break;entries.push({name,packing,original,size:length});}}catch(e){if(e instanceof RangeError&&n===size)continue;throw e;}
 let offset=p;return entries.map(e=>{const row={...e,offset,prefix,virtual:(prefix+'\\'+e.name).replaceAll('\\','/').replace(/^\/+/,'').toLowerCase()};offset+=e.size;return row;});}throw Error('Header excessive');}finally{fs.closeSync(fd);}}
module.exports={readEntry,expandLzss,indexEntries};
