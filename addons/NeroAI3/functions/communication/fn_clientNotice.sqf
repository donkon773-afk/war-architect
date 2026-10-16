params ["_message"];
if (!hasInterface) exitWith {};
systemChat format ["[NeroAI 4.3.0] %1", _message];
