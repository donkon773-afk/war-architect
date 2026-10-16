params ["_side"];
if(!(_side in [west,east,resistance]))exitWith{[]};
private _defender=_side==resistance && {getText(missionConfigFile >> "CfgNeroDesign" >> "greenRole")=="defender"};
(missionNamespace getVariable["BIS_WL_sectors",[]])select{
 !(_x getVariable["NeroWL_isBase",false]) && {
  if(_defender)then{(_x getVariable["BIS_WL_sectorSide",sideUnknown])==_side}else{(_x getVariable["BIS_WL_sectorSide",sideUnknown])!=_side}
 }
}
