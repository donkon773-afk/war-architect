"use strict";
function adapt(source){
 if((source.match(/4 min BIS_WL_maxSubordinates/g)||[]).length!==3)throw Error("Native purchase FSM changed; inspect before adapting");
 let purchases=source.replaceAll("4 min BIS_WL_maxSubordinates","BIS_WL_maxSubordinates").replace('_maxCrew = BIS_WL_maxSubordinates;','_maxCrew = BIS_WL_maxSubordinates + 1;');
 const infantryGate='_maxToPurchase > 0';
 if(purchases.split(infantryGate).length-1!==3)throw Error('Native infantry transitions changed');
 purchases=purchases.replaceAll(infantryGate,infantryGate+' && !((group _this) getVariable [""NeroAI_active"",FALSE]) && ([_this] call NeroAI_fnc_nativeInfantryPurchaseAllowed)');
 const limit='_maxToPurchase = ((BIS_WL_maxSubordinates) - (count units _this) + 1) min (_maxCrew - count units _this);';
 if(purchases.split(limit).length-1!==3)throw Error("Native infantry purchase capacity changed");
 purchases=purchases.replaceAll(limit,limit.replace(';','; _reservePilot = if (([_this,_this getVariable [""BIS_WL_dropPos"",_this],[typeOf _this]] call NeroAI_fnc_baseDeliveryContext) # 0) then {0} else {1}; _maxToPurchase = _maxToPurchase min ((([""INFANTRY""] call NeroAI_fnc_designPurchaseCapacity)-_reservePilot) max 0); _maxToPurchase = _maxToPurchase min 8;'));
 const seats='_maxCrew = (_veh emptyPositions ""Commander"") + (_veh emptyPositions ""Driver"") + (_veh emptyPositions ""Gunner"") + (_veh emptyPositions ""Cargo"");';
 if(!purchases.includes(seats))throw Error("Native crew trimming changed; inspect before adapting");
 purchases=purchases.replace(seats,seats.replace(';','; _maxCrew = _maxCrew max (BIS_WL_maxSubordinates + 1);'));
 const gate='count ((group _this) getVariable [""BIS_WL_groupVehs"", []]) < 1';
 if(purchases.split(gate).length-1!==3)throw Error("Native ground purchase transitions changed");
 purchases=purchases.replaceAll(gate,gate+' && ([group _this] call NeroAI_fnc_nativeGroundPurchaseAllowed)');
 const catalog='"_purchasable = _this getVariable ""BIS_WL_purchasable"";"';
 if(!purchases.includes(catalog))throw Error("Native catalog assignment changed");
 purchases=purchases.replace(catalog,'"[group _this] call NeroAI_fnc_assignDefaultRole; _purchasable = _this getVariable ""BIS_WL_purchasable"";"');
 const {decode,encode}=require('./adapt-frontline');let protectedCharges=0;
 purchases=purchases.replace(/\/\*%FSM<STATEINIT""">\*\/([\s\S]*?)\/\*%FSM<\/STATEINIT""">\*\//g,(all,raw)=>{
  const code=decode(raw);
  if(!code.includes('[_this, _dropPool] call BIS_fnc_WLAirdrop;'))return all;
  const timer='\n_t = time;';
  if(code.split(timer).length!==2)throw Error('Native infantry purchase timer changed; inspect before adapting');
  protectedCharges++;
  const body=code.replace(timer,'');
  return all.replace(raw,encode('if ([_this] call NeroAI_fnc_nativeInfantryPurchaseAllowed) then {\n'+body+'\n} else {\n_this setVariable ["BIS_WL_AI_airdropping", FALSE];\n};\n_t = time;'));
 });
 if(protectedCharges!==1)throw Error('Native infantry charging block changed: '+protectedCharges);
 return purchases;
}
module.exports={adapt};
