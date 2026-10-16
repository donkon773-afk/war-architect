"use strict";
// Native Warlords purchase list. Each item is stored in the listbox as
// "class|requirements|name|preview|text|category" and read back with
// splitString "|", which DROPS empty fields. RHS infantry (and some RHS/CUP
// vehicles) have no editorPreview, so the category slid from index 5 to 4:
// live 7.10 the player could not buy infantry ("Категория покупки не готова").
// Empty name/preview/text fields get a non-empty stand-in before formatting,
// so every reader (availability, details, purchase) sees the real category.
const fs=require("node:fs"),path=require("node:path");
const PREVIEW='"\\A3\\Data_F_Warlords\\Data\\preview_empty.jpg"';
function adapt(source){
 source=source.replaceAll("\r\n","\n");
 const replace=(before,after)=>{if(source.split(before).length!==2)throw new Error("Native purchase list source changed: "+before);source=source.replace(before,after);};
 replace('\t(_display displayCtrl 101) lbAdd (_x # 3);',
  '\tprivate _neroRow = +_x;\n'+
  '\t{if ((_neroRow # (_x # 0)) isEqualTo "") then {_neroRow set [_x # 0, _x # 1]};} forEach [[3, "?"], [4, '+PREVIEW+'], [5, " "]];\n'+
  '\t(_display displayCtrl 101) lbAdd (_x # 3);');
 replace('format ["%1|%2|%3|%4|%5|%6|%7", _x # 0, _x # 2, _x # 3, _x # 4, _x # 5, _x # 6, _x # 7]',
  'format ["%1|%2|%3|%4|%5|%6|%7", _neroRow # 0, _neroRow # 2, _neroRow # 3, _neroRow # 4, _neroRow # 5, _neroRow # 6, _neroRow # 7]');
 replace('format ["%1|%2|%3|%4|%5|%6", _x # 0, _x # 2, _x # 3, _x # 4, _x # 5, _x # 6]',
  'format ["%1|%2|%3|%4|%5|%6", _neroRow # 0, _neroRow # 2, _neroRow # 3, _neroRow # 4, _neroRow # 5, _neroRow # 6]');
 return source;
}
function write(root=path.resolve(__dirname,"..")){
 const out=path.join(root,"addons/NeroAI3/functions/native/fn_WLSubroutine_purchaseMenuSetItemsList.sqf");
 fs.writeFileSync(out,adapt(fs.readFileSync(path.join(root,"research/native/Warlords/fn_WLSubroutine_purchaseMenuSetItemsList.sqf"),"latin1")),"latin1");return out;
}
if(require.main===module)console.log(write());module.exports={adapt,write};
