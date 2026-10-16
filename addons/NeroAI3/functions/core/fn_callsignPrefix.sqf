/* NeroAI 4.7.0 [Any Warlords]: radio callsign prefix for a side, picked from the
 * mission's faction (fn_scenarioProfile) rather than hardwired to the Takistan
 * war. Known factions get their flavour; anything else falls back to a neutral
 * prefix per side, so a community port with an unknown faction still reads well.
 *
 *   [side] call NeroAI_fnc_callsignPrefix  ->  "Такистан-" */
params [["_side", west]];
private _key = switch (_side) do { case east: {"RED"}; case resistance: {"GREEN"}; default {"BLUE"} };
private _classes = missionNamespace getVariable ["NeroAI_factionClasses", createHashMap];
private _names = missionNamespace getVariable ["NeroAI_factionNames", createHashMap];
private _tag = toLower ((_classes getOrDefault [_key, ""]) + " " + (_names getOrDefault [_key, ""]));

private _table = [
    /* substring of faction class/name  -> prefix */
    ["tk_ins",      "Моджахеды-"], ["taliban", "Моджахеды-"], ["mujahid", "Моджахеды-"], ["tk_gue", "Моджахеды-"],
    ["takistan",    "Такистан-"],  ["tk_",     "Такистан-"],
    ["chdkz",       "Сокол-"],     ["napa",    "Гвардия-"],  ["cdf", "Беркут-"],
    ["rus",         "Гроза-"],     ["msv",     "Гроза-"],    ["vdv", "Купол-"], ["russia", "Гроза-"],
    ["usmc",        "Кобра-"],     ["usarmy",  "Рейдер-"],   ["usaf", "Рейдер-"], ["us_army", "Рейдер-"], ["usa", "Рейдер-"],
    ["blu_f",       "Альфа-"],     ["nato",    "Альфа-"],
    ["opf_f",       "Скорпион-"],  ["csat",    "Скорпион-"],
    ["ind_f",       "Эгида-"],     ["aaf",     "Эгида-"],
    ["syndikat",    "Синдикат-"],  ["ind_c_f", "Синдикат-"], ["paramilit", "Ополчение-"],
    ["sla",         "Кондор-"],    ["racs",    "Легион-"],   ["ukm", "Легион-"],
    ["fia",         "Партизан-"],  ["gue",     "Партизан-"], ["ins", "Ополчение-"], ["milit", "Ополчение-"]
];
private _prefix = "";
{ if ((_tag find (_x # 0)) >= 0) exitWith { _prefix = _x # 1; }; } forEach _table;
if (_prefix isEqualTo "") then {
    _prefix = switch (_key) do { case "RED": {"Гром-"}; case "GREEN": {"Партизан-"}; default {"Альфа-"} };
};
_prefix
