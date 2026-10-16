"use strict";
// Native Warlords airdrop (byte-identical to functions_f_warlords.pbo on 7.10).
// Live 7.10: its two AI-vehicle watchers made NeroAI squads abandon bought
// tanks — "stuck" = no 0.5 m movement in 180 s (a vehicle waiting for its
// infantry or for a re-route), and "leader not in this vehicle after 180 s"
// (a squad split between two vehicles). NeroAI owns boarding, routing and
// shelving of its groups, so both watchers skip groups with NeroAI_active.
// Non-NeroAI groups keep the native behaviour unchanged.
const fs=require("node:fs"),path=require("node:path");
function adapt(source){
 source=source.replaceAll("\r\n","\n");
 const replace=(before,after)=>{if(source.split(before).length!==2)throw new Error("Native airdrop source changed: "+before);source=source.replace(before,after);};
 replace('if (!canMove _veh || (time > _t && vehicle leader _grp != _veh)) then {',
  'if ((!canMove _veh || (time > _t && vehicle leader _grp != _veh)) && !(_grp getVariable ["NeroAI_active", FALSE])) then {');
 replace('if ((crew _this) findIf {alive _x} >= 0 && (crew _this) findIf {isPlayer _x} == -1 && (position _this) distance _pos < 0.5) then {',
  'if ((crew _this) findIf {alive _x} >= 0 && (crew _this) findIf {isPlayer _x} == -1 && (position _this) distance _pos < 0.5 && !((group effectiveCommander _this) getVariable ["NeroAI_active", FALSE])) then {');
 replace('_unit move position _unit;', 'if !((group _unit) getVariable ["NeroAI_active", FALSE]) then {_unit move position _unit;};');
 replace('if (_away && _this distance leader _this > 400 && vehicle _this == _this) then {','if (_away && _this distance leader _this > 400 && vehicle _this == _this && {!((group _this) getVariable ["NeroAI_active",FALSE])}) then {');
 replace('_itemPool = [];',`_itemPool = [];
private _neroGround = ([(_this # 0),_pos,(_this # 1)] call NeroAI_fnc_baseDeliveryContext) # 0;
private _neroPlanned = [];
private _neroPlan = (_this # 0) getVariable ["NeroWL_groundDeliveryPlan",[]];
(_this # 0) setVariable ["NeroWL_groundDeliveryPlan",nil];
if (_neroGround && {count _neroPlan == 4} && {(_neroPlan # 0) isEqualTo (_this # 1)} && {(_neroPlan # 2) isEqualTo _pos} && {diag_tickTime <= (_neroPlan # 3)}) then {_neroPlanned = _neroPlan # 1;};`);
 const searchStart=source.indexOf('\t_finalPos = [];'),paraStart=source.indexOf('\t_para = createVehicle');
 if(searchStart<0||paraStart<searchStart)throw Error('Native drop position block changed');
 const search=source.slice(searchStart,paraStart);
 // Branch-local assignments disappear before createUnit/createVehicle unless
 // the output is declared in the enclosing per-item scope first.
 source=source.slice(0,searchStart)+'\tprivate _finalPos = [];\n\tif (_neroPlanned isNotEqualTo []) then {_finalPos = _neroPlanned # _forEachIndex;} else {\n'+search+'\t};\n'+source.slice(paraStart);
 const paraBlock='\t_para = createVehicle [if (_isMan) then {"Steerable_Parachute_F"} else {"B_Parachute_02_F"}, _finalPos, [], 0, "FLY"];\n\t_para setPos [_finalPos # 0, _finalPos # 1, if (_isMan) then {50 + random 50} else {150 + random 100}];\n\t_para setVariable ["finalPos", _finalPos];';
 replace(paraBlock,'\t_para = objNull;\n\tif (!_neroGround) then {\n'+paraBlock+'\n\t};');
 replace('_item = group (_this # 0) createUnit [_x, position (_this # 0), [], 0, "NONE"];','_item = group (_this # 0) createUnit [_x, if (_neroGround) then {_finalPos} else {position (_this # 0)}, [], 0, "NONE"];');
 const manPara='\t\t_item assignAsDriver _para;\n\t\t_item moveInDriver _para;\n\t\t_item addEventHandler ["HandleDamage", {if ((_this # 3) in [objNull, _this # 0]) then {0}}];\n\t\t_para addEventHandler ["HandleDamage", {if ((_this # 3) == (_this # 0)) then {0}}];';
 replace(manPara,'\t\tif (!_neroGround) then {\n'+manPara+'\n\t\t};');
 const manStart=source.indexOf('\t\t_item spawn {\n\t\t\tscriptName "WLAirdrop (man)";'),manEnd=source.indexOf('\t\t_item addEventHandler ["Fired", BIS_WL_mineRestrictionCode];',manStart);
 if(manStart<0||manEnd<manStart)throw Error('Native infantry landing worker changed');
 source=source.slice(0,manStart)+'\t\tif (!_neroGround) then {\n'+source.slice(manStart,manEnd)+'\t\t};\n'+source.slice(manEnd);
 replace('_item attachTo [_para, _bBoxCenter];','if (!_neroGround) then {_item attachTo [_para, _bBoxCenter];};');
 const vehStart=source.indexOf('\t\t_null = [_para, _item, _refundEH, _itemConfig] spawn {'),vehEnd=source.indexOf('\t\tif (_orderedByAI) then {',vehStart);
 if(vehStart<0||vehEnd<vehStart)throw Error('Native vehicle landing worker changed');
 source=source.slice(0,vehStart)+'\t\tif (!_neroGround) then {\n'+source.slice(vehStart,vehEnd)+'\t\t} else {_item removeEventHandler ["Killed",_refundEH];};\n'+source.slice(vehEnd);
 replace('if !(_orderedByAI || _isMan) then {','if !(_orderedByAI || _isMan || _neroGround) then {');
 replace('if ((_this # 0) == player || isServer) then {','if (!_neroGround && {(_this # 0) == player || isServer}) then {');
 const flightHeader=`
if (isServer && {!isPlayer (_this # 0)} && {isNull ((_this # 0) getVariable ["BIS_WL_pointer",objNull])}) then {
 (_this # 0) setVariable ["BIS_WL_pointer",_this # 0,true];
 (_this # 0) setVariable ["BIS_WL_purchased",(_this # 0) getVariable ["BIS_WL_purchased",[]],true];
};
private _neroFlight = objNull;
private _neroFlightPlan = [];
private _neroFlightRequired = !_neroGround && {missionNamespace getVariable ["NeroAI_transportDropEnabled",true]} && {isServer} && {!isPlayer (_this # 0)} && {(_this # 1) isNotEqualTo []} && {((_this # 1) findIf {!(_x isKindOf "Man")}) < 0};
if (_neroFlightRequired) then {
 private _offer = (_this # 0) getVariable ["NeroWL_supplyOffer",[]];
 (_this # 0) setVariable ["NeroWL_supplyOffer",nil];
 _neroFlightPlan = if (count _offer == 2 && {diag_tickTime <= (_offer # 1)}) then {_offer # 0} else {[group (_this # 0),_this # 1,_pos] call NeroAI_fnc_airdropPlan};
 if (_neroFlightPlan param [0,false]) then {_neroFlight = [_this # 0,_this # 1,_neroFlightPlan] call NeroAI_fnc_airdropStart;};
};
if (_neroFlightRequired && {isNull _neroFlight}) exitWith {(group (_this # 0)) setVariable ["NeroWL_purchaseBlocked",true,true];[]};
`;
 replace('_orderedByAI = FALSE;',flightHeader+'\n_orderedByAI = FALSE;');
 source=source.replaceAll('if (!_neroGround) then {','if (!_neroGround && {isNull _neroFlight}) then {');
 replace('if (_neroPlanned isNotEqualTo []) then {_finalPos = _neroPlanned # _forEachIndex;} else {', 'if (!isNull _neroFlight) then {_finalPos = getPosATL _neroFlight;} else {if (_neroPlanned isNotEqualTo []) then {_finalPos = _neroPlanned # _forEachIndex;} else {');
 replace('\t_para = objNull;','\t};\n\t_para = objNull;');
 const createMan='_item = group (_this # 0) createUnit [_x, if (_neroGround) then {_finalPos} else {position (_this # 0)}, [], 0, "NONE"];';
 replace(createMan,createMan.replace('if (_neroGround)','if (_neroGround || {!isNull _neroFlight})')+`
        if (!isNull _neroFlight && {!isNull _item}) then {
            _item setVariable ["NeroWL_deliveryPending",true,true];
            _item moveInCargo _neroFlight;
            if (objectParent _item != _neroFlight) then {deleteVehicle _item;_item = objNull;};
        };
        if (isNull _item) exitWith {};
 `);
 replace('((_this # 0) getVariable "BIS_WL_pointer") setVariable ["BIS_WL_purchased", (((_this # 0) getVariable "BIS_WL_pointer") getVariable "BIS_WL_purchased") + _itemPool, TRUE];',`((_this # 0) getVariable "BIS_WL_pointer") setVariable ["BIS_WL_purchased", (((_this # 0) getVariable "BIS_WL_pointer") getVariable "BIS_WL_purchased") + _itemPool, TRUE];
if (!isNull _neroFlight) then {
    _neroFlight setVariable ["NeroWL_airdropManifest",_itemPool];
    [_neroFlight,_this # 0,_itemPool,_neroFlightPlan] spawn NeroAI_fnc_airdropWorker;
};`);
 replace('\t_itemPool pushBack _item;','\tif (!isNull _item) then {\n\t_itemPool pushBack _item;');
 replace('} forEach (_this # 1);','\t};\n} forEach (_this # 1);');
 replace('if (!_neroGround && {(_this # 0) == player || isServer}) then {','if (!_neroGround && {isNull _neroFlight} && {(_this # 0) == player || isServer}) then {');
 return source;
}
function write(root=path.resolve(__dirname,"..")){
 const out=path.join(root,"addons/NeroAI3/functions/native/fn_WLAirdrop.sqf");
 fs.writeFileSync(out,adapt(fs.readFileSync(path.join(root,"research/native/Warlords/fn_WLAirdrop.sqf"),"latin1")),"latin1");return out;
}
if(require.main===module)console.log(write());module.exports={adapt,write};
