/* Native FSM calls both at its transition and again before its atomic charge. */
params ["_buyer"];
private _group = group _buyer;
if (!isServer || {_group getVariable ["NeroAI_active",false]} || {!([_group,false] call NeroAI_fnc_validateGroup)}) exitWith {false};
if (_group getVariable ["NeroWL_purchaseBlocked",false]) exitWith {false};
if (((_group getVariable ["NeroWL_supplyManifest",[]]) findIf {alive _x}) >= 0) exitWith {false};
private _anchor = _buyer getVariable ["BIS_WL_dropPos",_buyer];
private _cart = [];
private _room = ((missionNamespace getVariable ["BIS_WL_maxSubordinates",9])+1-({alive _x} count units _group)) min 8;
if (_room <= 0) exitWith {false};
if (([_buyer,_anchor,[typeOf _buyer]] call NeroAI_fnc_baseDeliveryContext) # 0) exitWith {true};
if !(missionNamespace getVariable ["NeroAI_transportDropEnabled",true]) exitWith {true};
_room = _room min ((["INFANTRY"] call NeroAI_fnc_designPurchaseCapacity)-1);
for "_i" from 1 to _room do {_cart pushBack typeOf _buyer;};
private _offer = [_group,_cart,_anchor] call NeroAI_fnc_airdropPlan;
if (_offer # 0) then {_buyer setVariable ["NeroWL_supplyOffer",[_offer,diag_tickTime+2]];};
_offer # 0
