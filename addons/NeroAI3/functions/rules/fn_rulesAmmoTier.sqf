/* PURE conservative capability hint, not a penetration/hit guarantee.
 * 0 = not AT, 1 = light armour, 2 = heavy armour. AA-only never counts as AT. */
params [["_simulation","",[""]],["_hit",0,[0]],["_caliber",0,[0]],
    ["_airLock",0,[0]],["_warhead","",[""]],["_childTier",0,[0]]];
if (_airLock == 2) exitWith {0};
private _sim = toLower _simulation;
private _head = toUpper _warhead;
if (_childTier >= 2) exitWith {2};
if (_sim in ["shotrocket","shotmissile","shotshell"] && {_hit >= 100} &&
    {_head in ["HEAT","TANDEMHEAT","APFSDS","AP"] || {_caliber >= 5}}) exitWith {2};
if (_sim in ["shotbullet","shotshell"] && {_hit >= 70} && {_caliber >= 3}) exitWith {1};
if (_childTier >= 1) exitWith {1};
0
