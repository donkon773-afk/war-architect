'use strict';
/* 8.10: "after Save it is 100% saved". Write a temp file, flush it to the disk
 * (fsync), atomically rename it over the target, then read the file back and
 * compare it with what was meant to be written. Any difference is an error the
 * user sees — never a silent half-save. */
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const stable=v=>Array.isArray(v)?v.map(stable):v&&typeof v==='object'?Object.fromEntries(Object.keys(v).sort().map(k=>[k,stable(v[k])])):v;
const hash=v=>crypto.createHash('sha256').update(JSON.stringify(stable(v))).digest('hex').slice(0,16);
function write(file,value){
 fs.mkdirSync(path.dirname(file),{recursive:true});
 const text=JSON.stringify(value,null,2),temp=file+'.'+process.pid+'.'+crypto.randomUUID().slice(0,8)+'.tmp';
 const fd=fs.openSync(temp,'w');
 try{fs.writeSync(fd,text);fs.fsyncSync(fd);}finally{fs.closeSync(fd);}
 fs.renameSync(temp,file);
 let back;try{back=JSON.parse(fs.readFileSync(file,'utf8').replace(/^﻿/,''));}catch(e){throw Error('Проверка записи не прошла: файл не читается после сохранения ('+e.message+').');}
 if(hash(back)!==hash(value))throw Error('Проверка записи не прошла: файл на диске отличается от сохранённых данных.');
 return back;
}
module.exports={write,hash,stable};
