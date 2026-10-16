/*
    BFX Warlords Builder — автосборка сценария Warlords в редакторе Eden.

    Что делает:
      * берёт реальные населённые пункты и аэродромы текущей карты (из конфига карты);
      * расставляет модули Warlords: Init, 2 базы (BLUFOR/OPFOR) и сектора;
      * связывает сектора синхронизацией (граф «соседей» + остовное дерево, чтобы всё было связно);
      * выставляет фракции RHS и пресет закупки (CfgWLRequisitionPresets из description.ext);
      * переносит игровые слоты к своим базам и ставит маркеры respawn_west / respawn_east;
      * проверяет, что все классы из пресета закупки существуют в загруженных модах.

    Запуск (Eden: Инструменты -> Консоль отладки, кнопка «Локально»):
        call compile preprocessFileLineNumbers "tools\wl_build.sqf";

    Можно запускать повторно: старые модули Warlords и маркеры респауна удаляются.
    Отчёт копируется в буфер обмена.
*/

private _S = createHashMapFromArray [
    ["title", "Australia"],
    ["sectorCount", 20], // сколько секторов захватывать (без 2 баз)
    ["minSpacing", 1800], // мин. расстояние между секторами, м
    ["sectorRadius", 400], // радиус сектора, м
    ["airportRadius", 700], // радиус сектора-аэродрома, м
    ["neighbours", 2], // связей с ближайшими секторами (плюс остовное дерево)
    ["swapBases", false], // true — поменять базы BLUFOR и OPFOR местами
    ["westFactions", ["rhs_faction_usarmy_d", "BLU_F"]], // берётся первая существующая фракция
    ["eastFactions", ["rhs_faction_msv", "OPF_F"]],
    ["indepFactions", ["IND_F", "IND_G_F"]], // защитники нейтральных секторов
    ["assetList", ["BFX_RHS_D"]] // пресеты закупки из bfx\presets.hpp
];

if (!is3DEN) exitWith { "BFX: запускайте этот скрипт в редакторе Eden (Инструменты -> Консоль отладки)" };

private _log = [];
private _say = { _log pushBack _this; diag_log text ("[BFX WL] " + _this); };
private _has = { params ["_s", "_subs"]; (_subs findIf { (_s find _x) >= 0 }) >= 0 };

format ["Карта: %1 (worldSize %2), сценарий: %3", worldName, worldSize, _S get "title"] call _say;

// ---------------------------------------------------------------- классы модулей
private _findModule = {
    params ["_preferred", "_keyword"];
    if (isClass (configFile >> "CfgVehicles" >> _preferred)) exitWith { _preferred };
    private _cond = format ["(getNumber (_x >> 'scope') == 2) && {((toLower configName _x) find 'modulewl') >= 0} && {((toLower configName _x) find '%1') >= 0}", _keyword];
    private _hits = _cond configClasses (configFile >> "CfgVehicles");
    if (_hits isEqualTo []) exitWith { "" };
    configName (_hits select 0)
};
private _clsInit   = ["ModuleWLInit_F", "init"] call _findModule;
private _clsSector = ["ModuleWLSector_F", "sector"] call _findModule;
private _clsBase   = ["ModuleWLBase_F", "base"] call _findModule;
format ["Модули: init=%1 sector=%2 base=%3", _clsInit, _clsSector, _clsBase] call _say;
if ("" in [_clsInit, _clsSector, _clsBase]) exitWith {
    copyToClipboard (_log joinString endl);
    "BFX: модули Warlords не найдены в конфиге игры. Отчёт в буфере обмена."
};

// ---------------------------------------------------------------- атрибуты модулей
private _attrList = {
    params ["_class"];
    private _out = [];
    {
        private _prop = getText (_x >> "property");
        if (_prop == "") then { _prop = configName _x };
        _out pushBack [_x, configName _x, _prop];
    } forEach ("true" configClasses (configFile >> "CfgVehicles" >> _class >> "Attributes"));
    _out
};
private _attrType = {
    params ["_cfg"];
    private _t = toUpper getText (_cfg >> "typeName");
    if (_t in ["NUMBER", "SCALAR"]) exitWith { "NUMBER" };
    if (_t in ["STRING", "BOOL", "ARRAY"]) exitWith { _t };
    private _d = "";
    if (isText (_cfg >> "defaultValue")) then {
        _d = getText (_cfg >> "defaultValue");
    } else {
        if (isNumber (_cfg >> "defaultValue")) then { _d = str getNumber (_cfg >> "defaultValue") };
    };
    if (_d == "") exitWith { "STRING" };
    private _v = call compile _d;
    if (isNil "_v") exitWith { "STRING" };
    switch (typeName _v) do {
        case "SCALAR": { "NUMBER" };
        case "BOOL": { "BOOL" };
        case "ARRAY": { "ARRAY" };
        default { "STRING" };
    }
};
private _coerce = {
    params ["_v", "_t"];
    switch (_t) do {
        case "NUMBER": { if (_v isEqualType true) then { [0, 1] select _v } else { if (_v isEqualType "") then { parseNumber _v } else { _v } } };
        case "BOOL": { if (_v isEqualType 0) then { _v > 0 } else { _v } };
        case "STRING": { if (_v isEqualType "") then { _v } else { str _v } };
        default { _v };
    }
};
private _setAttr = {
    params ["_ent", "_entry", "_value", "_label"];
    _entry params ["_cfg", "_cn", "_prop"];
    private _val = [_value, [_cfg] call _attrType] call _coerce;
    private _ok = _ent set3DENAttribute [_prop, _val];
    if (_label != "") then {
        format ["%1: %2 = %3%4", _label, _prop, _val, ["  (НЕ УДАЛОСЬ — выставьте вручную)", ""] select _ok] call _say;
    };
    _ok
};
// значение стороны для атрибута-комбобокса базы
private _sideValue = {
    params ["_cfg", "_side"];
    private _keys = if (_side == "WEST") then { ["west", "blu"] } else { ["east", "opf", "red"] };
    private _res = nil;
    {
        private _n = toLower (configName _x + " " + getText (_x >> "name"));
        if ([_n, _keys] call _has) exitWith {
            _res = if (isNumber (_x >> "value")) then { getNumber (_x >> "value") } else { getText (_x >> "value") };
        };
    } forEach ("true" configClasses (_cfg >> "Values"));
    if (isNil "_res") then {
        _res = if (([_cfg] call _attrType) == "NUMBER") then { [0, 1] select (_side == "WEST") } else { _side };
    };
    _res
};

private _initAttrs   = [_clsInit] call _attrList;
private _sectorAttrs = [_clsSector] call _attrList;
private _baseAttrs   = [_clsBase] call _attrList;
"Атрибуты Init:   " + ((_initAttrs apply { _x select 2 }) joinString ", ") call _say;
"Атрибуты Sector: " + ((_sectorAttrs apply { _x select 2 }) joinString ", ") call _say;
"Атрибуты Base:   " + ((_baseAttrs apply { _x select 2 }) joinString ", ") call _say;

// ---------------------------------------------------------------- фракции
private _pickFaction = {
    params ["_list", "_label"];
    private _i = _list findIf { isClass (configFile >> "CfgFactionClasses" >> _x) };
    if (_i < 0) exitWith { format ["Фракция %1: ни один класс из %2 не найден — останется по умолчанию", _label, _list] call _say; "" };
    _list select _i
};
private _facW = [_S get "westFactions", "BLUFOR"] call _pickFaction;
private _facE = [_S get "eastFactions", "OPFOR"] call _pickFaction;
private _facI = [_S get "indepFactions", "INDEP"] call _pickFaction;

// ---------------------------------------------------------------- кандидаты в сектора
private _ws = worldSize;
private _margin = 400;
private _inMap = {
    params ["_p"];
    (_p select 0) > _margin && {(_p select 1) > _margin} && {(_p select 0) < (_ws - _margin)} && {(_p select 1) < (_ws - _margin)} && {!(surfaceIsWater [_p select 0, _p select 1])}
};
private _cands = []; // [pos2D, имя, приоритет, аэродром?]

private _wcfg = configFile >> "CfgWorlds" >> worldName;
{
    private _p = getArray (_x >> "ilsPosition");
    private _taxi = getArray (_x >> "ilsTaxiIn");
    if (count _taxi >= 4) then {
        private _sx = 0;
        private _sy = 0;
        private _n = 0;
        for "_i" from 0 to ((count _taxi) - 2) step 2 do {
            _sx = _sx + (_taxi select _i);
            _sy = _sy + (_taxi select (_i + 1));
            _n = _n + 1;
        };
        _p = [_sx / _n, _sy / _n];
    };
    if ((count _p) >= 2 && {[_p] call _inMap}) then {
        private _near = nearestLocations [_p, ["NameCityCapital", "NameCity", "NameVillage", "NameLocal"], 4000];
        private _nm = if (_near isEqualTo []) then { "Аэродром" } else { "Аэродром " + text (_near select 0) };
        _cands pushBack [[_p select 0, _p select 1], _nm, 4, true];
    };
} forEach ([_wcfg] + ("true" configClasses (_wcfg >> "SecondaryAirports")));

private _locTypes = ["NameVillage", "NameCity", "NameCityCapital"];
{
    private _p = locationPosition _x;
    if (([_p] call _inMap) && {text _x != ""}) then {
        _cands pushBack [[_p select 0, _p select 1], text _x, 1 + (_locTypes find (type _x)), false];
    };
} forEach (nearestLocations [[_ws / 2, _ws / 2], _locTypes, _ws]);

format ["Кандидатов: %1 (аэродромов: %2)", count _cands, {_x select 3} count _cands] call _say;

// ---------------------------------------------------------------- выбор: аэродромы + farthest-point по населённым пунктам
private _target = (_S get "sectorCount") + 2; // + 2 базы
private _sel = [];
{
    if (_x select 3) then {
        private _p = _x select 0;
        if ((_sel findIf { ((_x select 0) distance2D _p) < 2000 }) < 0) then { _sel pushBack _x };
    };
} forEach _cands;
if ((count _sel) > (_target / 2)) then { _sel resize (floor (_target / 2)) };

private _pool = _cands select { !(_x select 3) };
if (_sel isEqualTo [] && {_pool isNotEqualTo []}) then {
    private _bi = 0;
    { if ((_x select 2) > ((_pool select _bi) select 2)) then { _bi = _forEachIndex } } forEach _pool;
    _sel pushBack (_pool deleteAt _bi);
};
private _minDist = {
    params ["_p"];
    private _m = 1e9;
    { _m = _m min ((_x select 0) distance2D _p) } forEach _sel;
    _m
};
private _spacing = _S get "minSpacing";
for "_k" from 1 to 500 do {
    if ((count _sel) >= _target || {_pool isEqualTo []}) exitWith {};
    private _bestI = -1;
    private _bestS = -1;
    {
        private _d = [_x select 0] call _minDist;
        private _score = _d * (1 + 0.35 * (_x select 2));
        if (_d >= _spacing && {_score > _bestS}) then { _bestS = _score; _bestI = _forEachIndex };
    } forEach _pool;
    if (_bestI < 0) exitWith {};
    _sel pushBack (_pool deleteAt _bestI);
};
if ((count _sel) < 4) exitWith {
    copyToClipboard (_log joinString endl);
    "BFX: на карте слишком мало населённых пунктов — уменьшите minSpacing в начале скрипта."
};

// базы — самая удалённая пара точек
private _bW = 0;
private _bE = 1;
private _bd = -1;
for "_i" from 0 to ((count _sel) - 2) do {
    for "_j" from (_i + 1) to ((count _sel) - 1) do {
        private _d = ((_sel select _i) select 0) distance2D ((_sel select _j) select 0);
        if (_d > _bd) then { _bd = _d; _bW = _i; _bE = _j };
    };
};
if (_S get "swapBases") then { private _t = _bW; _bW = _bE; _bE = _t };
format ["Базы: BLUFOR — %1, OPFOR — %2 (%3 км)", (_sel select _bW) select 1, (_sel select _bE) select 1, round (_bd / 100) / 10] call _say;

// ---------------------------------------------------------------- граф связей
private _n = count _sel;
private _edges = createHashMap;
private _addEdge = {
    params ["_a", "_b"];
    _edges set [format ["%1_%2", _a min _b, _a max _b], [_a min _b, _a max _b]];
};
// остовное дерево (Прим) — гарантирует связность
private _inTree = [0];
private _rest = [];
for "_i" from 1 to (_n - 1) do { _rest pushBack _i };
private _mst = [];
for "_it" from 1 to (_n - 1) do {
    private _best = [1e12, -1, -1];
    {
        private _pi = (_sel select _x) select 0;
        private _from = _x;
        {
            private _d = _pi distance2D ((_sel select _x) select 0);
            if (_d < (_best select 0)) then { _best = [_d, _x, _from] };
        } forEach _rest;
    } forEach _inTree;
    _best params ["", "_j", "_f"];
    [_f, _j] call _addEdge;
    _mst pushBack (format ["%1_%2", _f min _j, _f max _j]);
    _inTree pushBack _j;
    _rest deleteAt (_rest find _j);
};
// + ближайшие соседи
private _kNear = _S get "neighbours";
{
    private _i = _forEachIndex;
    private _p = _x select 0;
    private _others = [];
    { if (_forEachIndex != _i) then { _others pushBack [_p distance2D (_x select 0), _forEachIndex] } } forEach _sel;
    _others sort true;
    for "_k" from 0 to ((_kNear min (count _others)) - 1) do { [_i, (_others select _k) select 1] call _addEdge };
} forEach _sel;
// базы не соединяем напрямую (если это не единственный путь)
private _bKey = format ["%1_%2", _bW min _bE, _bW max _bE];
if (!(_bKey in _mst)) then { _edges deleteAt _bKey };

// ---------------------------------------------------------------- создание сущностей
private _wlClasses = [_clsInit, _clsSector, _clsBase];
private _ents = [];
private _wPos = [];
private _ePos = [];
private _moved = 0;

// очистка от прошлого запуска
private _old = (all3DENEntities select 3) select { (typeOf _x) in _wlClasses };
if (_old isNotEqualTo []) then { delete3DENEntities _old };
private _oldM = (all3DENEntities select 5) select { _x in ["respawn_west", "respawn_east"] };
if (_oldM isNotEqualTo []) then { delete3DENEntities _oldM };

// Init
private _init = create3DENEntity ["Logic", _clsInit, [_ws * 0.5, _margin, 0]];
_init set3DENAttribute ["name", "BFX_WL_init"];
{
    private _key = toLower ((_x select 1) + " " + (_x select 2));
    private _t = [_x select 0] call _attrType;
    if (_t == "STRING" && {[_key, ["faction"]] call _has}) then {
        if ([_key, ["blu", "west"]] call _has) exitWith { if (_facW != "") then { [_init, _x, _facW, "Init"] call _setAttr } };
        if ([_key, ["opf", "east"]] call _has) exitWith { if (_facE != "") then { [_init, _x, _facE, "Init"] call _setAttr } };
        if ([_key, ["ind", "guer", "res", "grn"]] call _has) exitWith { if (_facI != "") then { [_init, _x, _facI, "Init"] call _setAttr } };
    };
    if (_t in ["STRING", "ARRAY"] && {[_key, ["asset", "requisition", "preset"]] call _has}) then { [_init, _x, _S get "assetList", "Init"] call _setAttr };
} forEach _initAttrs;

// базы и сектора
private _r = _S get "sectorRadius";
private _rAp = _S get "airportRadius";
private _canArea = { params ["_cls"]; getNumber (configFile >> "CfgVehicles" >> _cls >> "canSetArea") == 1 };
{
    _x params ["_p", "_nm", "_prio", "_isAp"];
    private _i = _forEachIndex;
    private _isBase = _i in [_bW, _bE];
    private _cls = [_clsSector, _clsBase] select _isBase;
    private _e = create3DENEntity ["Logic", _cls, [_p select 0, _p select 1, 0]];
    _e set3DENAttribute ["name", format ["BFX_WL_%1_%2", ["sector", "base"] select _isBase, _i]];
    private _rad = [_r, _rAp] select _isAp;
    if ([_cls] call _canArea) then {
        _e set3DENAttribute ["size2", [_rad, _rad]];
        _e set3DENAttribute ["size3", [_rad, _rad, 50]];
    };
    if (_isBase) then {
        private _side = ["EAST", "WEST"] select (_i == _bW);
        {
            private _key = toLower ((_x select 1) + " " + (_x select 2));
            if ([_key, ["side", "owner"]] call _has) then {
                [_e, _x, [_x select 0, _side] call _sideValue, "База " + _side] call _setAttr;
            };
            if ([_key, ["name"]] call _has && {([_x select 0] call _attrType) == "STRING"}) then {
                [_e, _x, _nm, ""] call _setAttr;
            };
        } forEach _baseAttrs;
    } else {
        {
            private _key = toLower ((_x select 1) + " " + (_x select 2));
            if ([_key, ["name"]] call _has && {([_x select 0] call _attrType) == "STRING"}) then {
                [_e, _x, _nm, ""] call _setAttr;
            };
            if (_isAp && {[_key, ["runway", "airstrip", "airfield"]] call _has} && {([_x select 0] call _attrType) in ["BOOL", "NUMBER"]}) then {
                [_e, _x, true, "Сектор " + _nm] call _setAttr;
            };
        } forEach _sectorAttrs;
    };
    _ents pushBack _e;
} forEach _sel;

// синхронизация
{
    _y params ["_a", "_b"];
    add3DENConnection ["Sync", [_ents select _a], _ents select _b];
} forEach _edges;

// маркеры респауна у баз
_wPos = (_sel select _bW) select 0;
_ePos = (_sel select _bE) select 0;
{
    _x params ["_mName", "_mPos"];
    private _m = create3DENEntity ["Marker", "Empty", [_mPos select 0, _mPos select 1, 0]];
    _m set3DENAttribute ["markerName", _mName];
} forEach [["respawn_west", _wPos], ["respawn_east", _ePos]];

// игровые слоты — к своим базам
{
    private _u = _x;
    if (_u isKindOf "CAManBase" && {((_u get3DENAttribute "ControlMP") select 0) || ((_u get3DENAttribute "ControlSP") select 0)}) then {
        private _bp = switch (side group _u) do {
            case west: { _wPos };
            case east: { _ePos };
            default { [] };
        };
        if (_bp isNotEqualTo []) then {
            private _dst = [_bp select 0, _bp select 1, 0] getPos [15 + random 45, random 360];
            private _free = _dst findEmptyPosition [0, 40, typeOf _u];
            if (_free isNotEqualTo []) then { _dst = _free };
            _u set3DENAttribute ["position", [_dst select 0, _dst select 1, 0]];
            _moved = _moved + 1;
        };
    };
} forEach (all3DENEntities select 0);

format ["Создано: 1 Init, 2 базы, %1 секторов, %2 связей; слотов перенесено к базам: %3", (count _sel) - 2, count _edges, _moved] call _say;
"Сектора: " + ((_sel apply { _x select 1 }) joinString ", ") call _say;

// ---------------------------------------------------------------- проверка пресетов закупки
private _missing = [];
private _checked = 0;
{
    private _preset = missionConfigFile >> "CfgWLRequisitionPresets" >> _x;
    if (!isClass _preset) then {
        format ["Пресет %1 не найден в description.ext (сохраните миссию и откройте заново, затем перезапустите скрипт)", _x] call _say;
    };
    {
        {
            {
                _checked = _checked + 1;
                if (!isClass (configFile >> "CfgVehicles" >> configName _x)) then { _missing pushBackUnique (configName _x) };
            } forEach ("true" configClasses _x);
        } forEach ("true" configClasses _x);
    } forEach ("true" configClasses _preset);
} forEach (_S get "assetList");
if (_missing isEqualTo []) then {
    format ["Пресеты закупки: проверено %1 классов, всё на месте", _checked] call _say;
} else {
    format ["ВНИМАНИЕ: в пресетах нет в модах %1 классов — удалите их из bfx\presets.hpp: %2", count _missing, _missing joinString ", "] call _say;
};

copyToClipboard (_log joinString endl);
["BFX: Warlords собран. Отчёт скопирован в буфер обмена. Сохраните миссию (Ctrl+S).", 0, 10] call BIS_fnc_3DENNotification;
format ["BFX: готово — %1 секторов, базы: %2 / %3. Отчёт в буфере обмена.", (count _sel) - 2, (_sel select _bW) select 1, (_sel select _bE) select 1]
