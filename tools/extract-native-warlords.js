'use strict';
// Reconstruct local comparison sources from the user's own Arma installation.
const fs=require('node:fs'),path=require('node:path'),{indexEntries,readEntry}=require('./read-pbo-entry');
function extract(armaRoot,output=path.resolve(__dirname,'../research/native')){
 const archive=path.resolve(armaRoot,'Addons/functions_f_warlords.pbo'),base=path.resolve(output);let count=0;
 for(const entry of indexEntries(archive)){
  const name=entry.name.replaceAll('\\','/');if(!/^(Warlords|Misc)\/fn_\w+\.(sqf|fsm)$/i.test(name))continue;
  const target=path.resolve(base,name);if(!target.startsWith(base+path.sep))throw Error('Invalid archive path');
  fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,readEntry(archive,entry.name));count++;
 }
 if(!count)throw Error('No native Warlords sources found');return {files:count,output:base};
}
if(require.main===module){if(!process.argv[2]){console.error('Usage: node tools/extract-native-warlords.js <Arma 3 directory>');process.exitCode=1;}else console.log(JSON.stringify(extract(process.argv[2]),null,2));}
module.exports={extract};
