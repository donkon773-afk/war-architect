/* Radio is server-originated only: a remoteExec from any client (owner >= 3) is
 * dropped. Owner 0 = not remote-executed / singleplayer host, 2 = server. */
if (isRemoteExecuted && {!(remoteExecutedOwner in [0, 2])}) exitWith {};
params [["_unit", objNull], ["_text", ""], ["_channel", "SIDE"]];
if (isNull _unit || {_text isEqualTo ""}) exitWith {};

switch (toUpper _channel) do {
    case "SIDE";
    case "SIDECHAT": { _unit sideChat _text; };
    case "GROUP";
    case "GROUPCHAT": { _unit groupChat _text; };
    case "COMMAND";
    case "COMMANDCHAT": { _unit commandChat _text; };
    /* 4.7.0a: there is no "direct chat" scripting command in Arma 3 (the line broke the whole
     * function at compile time — radio was silent since 16.09). A "shout" is the
     * global channel, shown only on clients standing within earshot. */
    case "DIRECT";
    case "DIRECTCHAT": { if (hasInterface && {!isNull player} && {(player distance _unit) <= 60}) then { _unit globalChat _text; }; };
    default { _unit sideChat _text; };
};
