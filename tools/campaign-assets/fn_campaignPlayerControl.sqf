/* BIS publishes this controller tag; remoteControlled alone requires locality. */
params ["_subject"];
private _units=if (_subject isEqualType grpNull) then {units _subject} else {if (_subject isKindOf "CAManBase") then {[_subject]} else {crew _subject}};
private _controlled=(_subject isEqualType grpNull && {_subject getVariable ["NeroOP_hcUID",""]!=""}) || {_units findIf {isPlayer _x || {(_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull]) in allPlayers} || {local _x && {!isNull remoteControlled _x}}}>=0};
if (!_controlled && {_subject isEqualType objNull} && {getNumber(configFile >> "CfgVehicles" >> typeOf _subject >> "isUav")==1}) then {private _uav=UAVControl _subject;_controlled=count _uav>=2 && {!isNull (_uav#0)} && {(_uav#1)!=""};if (count _uav>=4 && {!isNull (_uav#2)} && {(_uav#3)!=""}) then {_controlled=true;};};
_controlled
