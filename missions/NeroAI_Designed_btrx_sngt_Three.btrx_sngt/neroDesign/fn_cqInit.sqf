/* Independent three-side conquest. Stock two-side Warlords modules are absent. */
diag_log format ["[NeroWL CQ] INIT world=%1 server=%2 interface=%3",worldName,isServer,hasInterface];
if(isServer)then{
 private _cfg=missionConfigFile >> "CfgNeroDesign";
 NeroWL_CQballots=[[],[],[]];
 {missionNamespace setVariable[format["NeroWL_CQvote_%1",_x],[0,objNull,0,0],true];}forEach[west,east,resistance];
 {private _a=_x;{_a setFriend[_x,if(_a isEqualTo _x)then{1}else{0}];}forEach[west,east,resistance];}forEach[west,east,resistance];
 BIS_WL_sectors=[];BIS_WL_unitsPool=[[],[],[]];BIS_WL_factionsPool=[getText(missionConfigFile >> "CfgNeroArmies" >> "east"),getText(missionConfigFile >> "CfgNeroArmies" >> "west"),getText(_cfg >> "greenFaction")];
 BIS_WL_startCP=getNumber(_cfg >> "startCP");BIS_WL_maxCP=50000;BIS_WL_maxSubordinates=["BIS_WLMaxSubordinates",9]call BIS_fnc_getParamValue;if(!(BIS_WL_maxSubordinates in [9,12]))then{BIS_WL_maxSubordinates=9;};BIS_WL_dropCost=25;NeroAI_warlordsStartFunds=BIS_WL_startCP;
 {private _category=_x;{
  private _side=[west,east,resistance]#(["WEST","EAST","GUER"]find getText(_x >> "side"));
  private _g=createGroup[sideLogic,true];private _hub=_g createUnit["Logic",getArray(_x >> "position"),[],0,"NONE"];
  _hub setVariable["Name",getText(_x >> "name"),true];_hub setVariable["Size",getNumber(_x >> "radius"),true];_hub setVariable["BIS_WL_sectorSide",_side,true];_hub setVariable["BIS_WL_sectorName",getText(_x >> "name"),true];_hub setVariable["NeroWL_designId",configName _x,true];_hub setVariable["NeroWL_isBase",_category=="Bases",true];_hub setVariable["BIS_WL_sectorSpecial",if(_category=="Bases")then{["A","H"]}else{["H"]},true];
  BIS_WL_sectors pushBack _hub;
  if(_category=="Bases")then{missionNamespace setVariable[format["BIS_WL_base_%1",_side],_hub,true];[_side,getPosATL _hub,getText(_x >> "name")]call BIS_fnc_addRespawnPosition;};
 }forEach("true"configClasses(_cfg >> _category));}forEach["Bases","Garrisons"];
 {
  private _side=_x;private _key=str _side;private _preset=missionConfigFile >> "CfgWLRequisitionPresets" >> "NeroWL_RHSStart" >> _key;
  private _cat=[[],[],[],[],[],[],[],[]];
  {private _bucket=_forEachIndex;private _name=_x;{
   private _class=configName _x;if(isClass(configFile >> "CfgVehicles" >> _class))then{(_cat#_bucket)pushBack[_class,getNumber(_x >> "cost"),getArray(_x >> "requirements"),getText(configFile >> "CfgVehicles" >> _class >> "displayName")];};
  }forEach("true"configClasses(_preset >> _name));}forEach["Infantry","Vehicles","Gear","Defences","Aircraft","Naval","Gear_custom","Services"];
  BIS_WL_unitsPool set [[east,west,resistance]find _side,(_cat#0)apply{_x#0}];missionNamespace setVariable["BIS_WL_purchasable"+_key,_cat,true];
 }forEach[west,east,resistance];
 {
 private _s=_x;private _base=missionNamespace getVariable[format["BIS_WL_base_%1",_s],objNull];private _bots=allUnits select{side group _x==_s && {!isPlayer _x} && {alive _x}};
 if(_bots isEqualTo [])then{private _cls=getText(missionConfigFile >> "CfgNeroArmies" >> (switch(_s)do{case west:{"westCommander"};case east:{"eastCommander"};default{"greenCommander"};}));for "_i" from 1 to getNumber(missionConfigFile >> "CfgNeroArmies" >> "commanders")do{if(count allUnits>=getNumber(_cfg >> "maxNPCs"))exitWith{};private _p=(getPosATL _base)findEmptyPosition[15,150,_cls];if(!(_p isEqualTo []))then{private _g=createGroup[_s,true];_g createUnit[_cls,_p,[],0,"NONE"];};};};
 }forEach[west,east,resistance];
 BIS_WL_allWarlords=allUnits select {side group _x in [west,east,resistance] && {!(_x isKindOf "Logic")}};
 {private _u=_x;private _s=side group _u;private _base=missionNamespace getVariable[format["BIS_WL_base_%1",_s],objNull];private _p=(getPosATL _base)findEmptyPosition[15,150,typeOf _u];if(!(_p isEqualTo []))then{_u setPosATL _p;};_u setVariable["BIS_WL_funds",BIS_WL_startCP,true];_u setVariable["BIS_WL_purchasable",missionNamespace getVariable["BIS_WL_purchasable"+str _s,[]],true];_u setVariable["BIS_WL_pointer",_u,true];_u setVariable["BIS_WL_purchased",[],true];group _u setVariable["BIS_WL_groupVehs",[],true];}forEach BIS_WL_allWarlords;
 {publicVariable _x;}forEach["BIS_WL_sectors","BIS_WL_unitsPool","BIS_WL_factionsPool","BIS_WL_allWarlords","BIS_WL_maxSubordinates","BIS_WL_startCP","BIS_WL_maxCP","BIS_WL_dropCost"];
 addMissionEventHandler["EntityRespawned",{params["_u","_old"];if(_old in (missionNamespace getVariable["BIS_WL_allWarlords",[]]))then{BIS_WL_allWarlords=BIS_WL_allWarlords-[_old];BIS_WL_allWarlords pushBackUnique _u;_u setVariable["BIS_WL_funds",_old getVariable["BIS_WL_funds",0],true];_u setVariable["BIS_WL_purchasable",_old getVariable["BIS_WL_purchasable",[]],true];publicVariable "BIS_WL_allWarlords";};}];
 missionNamespace setVariable["NeroWL_CQready",true,true];
 diag_log format ["[NeroWL CQ] READY world=%1 sectors=%2 commanders=%3",worldName,count BIS_WL_sectors,count BIS_WL_allWarlords];
 []spawn NeroWL_Design_fnc_cqLoop;[]spawn NeroWL_Design_fnc_start;
};
if(hasInterface)then{[]spawn NeroWL_Design_fnc_cqClient;};
