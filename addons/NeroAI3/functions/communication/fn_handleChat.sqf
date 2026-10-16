params ["_channel", "_owner", "_from", "_text", "_speaker"];
if (!hasInterface || {_speaker != player} || {!isPlayer _speaker}) exitWith {false};
/* Standard Arma AI mode: side chat is ordinary chat again. */
if (missionNamespace getVariable ["NeroAI_vanillaMode", false]) exitWith {false};
/* Tactical AI without LLM: nobody parses free text — the chat stays ordinary. */
if (missionNamespace getVariable ["NeroAI_rulesMode", false]) exitWith {false};

/* NeroAI accepts commands only from faction chat. A full callsign selects one
 * group and the word "все" selects every active friendly group. */
if !(_channel isEqualTo 1) exitWith {false};

private _command = [_text, 240] call NeroAI_fnc_normalizeText;
if (_command isEqualTo "") exitWith {false};
diag_log format ["[NeroAI4][DEBUG] Faction chat accepted: chars=%1.", count _command];
[_speaker, "SIDE", _command] remoteExecCall ["NeroAI_fnc_receiveClientCommand", 2];
false
