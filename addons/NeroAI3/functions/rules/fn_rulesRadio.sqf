/* 11.10 Tactical AI without LLM — short templated radio for phase changes.
 * Server only; per squad and per side cooldowns keep the side channel readable.
 *   [_group, _key, _place] call NeroAI_fnc_rulesRadio */
params ["_group", "_key", ["_place", ""]];
if (!isServer || {isNull _group} || {!(missionNamespace getVariable ["NeroAI_rulesRadioEnabled", true])}) exitWith {};
private _now = diag_tickTime;
if ((_now - (_group getVariable ["NeroWL_rulesRadioAt", -1e6])) < 45) exitWith {};
private _sideKey = format ["NeroWL_rulesRadioSide_%1", side _group];
if ((_now - (missionNamespace getVariable [_sideKey, -1e6])) < 6) exitWith {};
private _cs = _group getVariable ["NeroAI_callsign", groupId _group];
if (_place isEqualTo "") then {_place = "цель";};
private _lines = switch (_key) do {
    case "ADVANCE": {[
        "%1: выдвигаемся на рубеж атаки, %2. Приём.",
        "%1 пошёл к %2. Держим дистанцию, смотрим фланги.",
        "%1: марш к %2, по дорогам. Как выйдем — доложу."
    ]};
    case "STAGE": {[
        "%1 на рубеже у %2. Ждём остальных, ведём разведку.",
        "%1: на исходной у %2. Наблюдаю, без команды не лезем.",
        "%1 на месте. %2 перед нами, собираем кулак."
    ]};
    case "ASSAULT": {[
        "%1: штурм %2! Пошли, пошли!",
        "%1 начинает атаку на %2. Прикройте!",
        "%1: вперёд на %2, не останавливаться!"
    ]};
    case "COUNTER": {[
        "%1: контакт! Работаем по противнику.",
        "%1 под огнём, отвечаем! Давим их.",
        "%1: противник рядом, разворачиваемся к бою."
    ]};
    case "BREAK": {[
        "%1: тяжёлые потери, отходим к %2! Нужна поддержка!",
        "%1 откатывается к %2, нас прижали. Кто рядом — помогите!",
        "%1: отход на %2, прикройте огнём!"
    ]};
    case "DEFEND": {[
        "%1 держит %2. Никого не пускаем.",
        "%1: заняли оборону в %2. Ждём гостей.",
        "%1 на позиции, %2 под нашей защитой."
    ]};
    case "DEFEND_MOVE": {[
        "%1: противник лезет на %2, иду на помощь.",
        "%1 выдвигается на оборону %2.",
        "%1: понял, усиливаю %2."
    ]};
    case "RESERVE": {[
        "%1 в резерве у %2. Пополняемся, готовы.",
        "%1: стоим в резерве, %2. Зовите, если что."
    ]};
    default {[]};
};
if (_lines isEqualTo []) exitWith {};
_group setVariable ["NeroWL_rulesRadioAt", _now];
missionNamespace setVariable [_sideKey, _now];
[leader _group, format [selectRandom _lines, _cs, _place], "SIDE"] remoteExecCall ["NeroAI_fnc_clientSpeech", 0];
