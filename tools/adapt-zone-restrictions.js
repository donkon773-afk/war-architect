"use strict";
const fs=require('node:fs'),path=require('node:path');
function adapt(source,name){source=source.replaceAll('\r\n','\n');
 const anchor=name==='fn_WLSectorsSetup.sqf'?'_hub spawn {\n\t\tscriptName "WLSectorsSetup (AI zone restriction)";':'_hub spawn {\n\t\t\tscriptName "WLSectorsCommonInit (zone restriction)";';
 if(!source.includes(anchor))throw Error('Native zone-restriction anchor changed: '+name);
 return source.replace(anchor,anchor+'\n        if (getNumber (missionConfigFile >> "NeroWL_useDesigner") == 1 && {getNumber (missionConfigFile >> "NeroWL_lethalZones") == 0}) exitWith {};');
}
function write(root=path.resolve(__dirname,'..')){for(const name of ['fn_WLSectorsSetup.sqf','fn_WLSectorsCommonInit.sqf'])fs.writeFileSync(path.join(root,'addons/NeroAI3/functions/native',name),adapt(fs.readFileSync(path.join(root,'research/native/Warlords',name),'utf8'),name));}
if(require.main===module)write();module.exports={adapt,write};
