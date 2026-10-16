'use strict';
const fs=require('node:fs'),editor=require('./warlords-editor');
function catalog(){return editor.inventory().mods.filter(m=>{try{return fs.statSync(m.path).isDirectory();}catch{return false;}}).map(m=>({id:m.path,label:m.name,patches:m.patches}));}
function validate(value=[]){
 const known=new Set(editor.inventory().mods.map(m=>m.path)),used=new Set();
 if(!Array.isArray(value)||value.length>known.size)throw Error('Выберите установленные дополнительные моды.');
 return value.map(id=>{if(typeof id!=='string'||!known.has(id)||used.has(id))throw Error('Дополнительный мод не установлен или повторяется.');used.add(id);return id;});
}
module.exports={catalog,validate};
