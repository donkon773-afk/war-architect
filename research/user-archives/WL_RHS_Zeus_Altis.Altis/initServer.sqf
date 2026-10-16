/*
    BFX Zeus для Warlords.

    Кто получает Зевса (клавиша Y):
      * хост (если игра запущена через «Мультиплеер -> Создать сервер»);
      * залогиненный админ выделенного сервера (#login <пароль>);
      * игроки, чьи Steam UID записаны в BFX_zeusUIDs[] в description.ext;
      * все игроки — если в параметрах миссии выбран режим «Все игроки».

    Зевс переназначается после смерти/респауна и снимается, когда админ разлогинивается.
    Всё, что появляется на карте (в т.ч. юниты и техника Warlords), автоматически
    становится редактируемым для всех Зевсов.
*/
if (!isServer) exitWith {};

BFX_zeusMode = ["BFX_ZeusMode", 0] call BIS_fnc_getParamValue;
BFX_zeusUIDs = getArray (missionConfigFile >> "BFX_zeusUIDs");
BFX_curators = createHashMap; // UID -> логика куратора

BFX_fnc_zeusAllowed = {
    params ["_unit"];
    if (BFX_zeusMode == 1) exitWith { true };
    if ((getPlayerUID _unit) in BFX_zeusUIDs) exitWith { true };
    if (hasInterface && {local _unit}) exitWith { true }; // хост listen-сервера
    (admin (owner _unit)) == 2
};

BFX_fnc_curatorFor = {
    params ["_uid", "_name"];
    private _cur = BFX_curators getOrDefault [_uid, objNull];
    if (isNull _cur) then {
        private _grp = createGroup [sideLogic, false];
        _cur = _grp createUnit ["ModuleCurator_F", [0, 0, 0], [], 0, "NONE"];
        _cur setVariable ["Owner", "", true];
        _cur setVariable ["Name", _name, true];
        _cur setVariable ["Addons", 3, true];
        _cur setVariable ["Forced", 0, true];
        _cur addCuratorAddons activatedAddons;
        _cur addCuratorEditableObjects [allUnits + vehicles, true];
        BFX_curators set [_uid, _cur];
    };
    _cur
};

[] spawn {
    private _tick = 0;
    while {true} do {
        {
            private _unit = _x;
            private _uid = getPlayerUID _unit;
            if (_uid != "" && {alive _unit} && {!(_unit isKindOf "HeadlessClient_F")}) then {
                if ([_unit] call BFX_fnc_zeusAllowed) then {
                    private _cur = [_uid, name _unit] call BFX_fnc_curatorFor;
                    if ((getAssignedCuratorUnit _cur) != _unit && {isNull (getAssignedCuratorLogic _unit)}) then {
                        if (!isNull (getAssignedCuratorUnit _cur)) then {
                            unassignCurator _cur;
                            sleep 0.5;
                        };
                        _unit assignCurator _cur;
                    };
                } else {
                    private _cur = BFX_curators getOrDefault [_uid, objNull];
                    if (!isNull _cur && {(getAssignedCuratorUnit _cur) == _unit}) then { unassignCurator _cur };
                };
            };
        } forEach allPlayers;

        _tick = _tick + 1;
        if (_tick % 5 == 0) then {
            private _objs = allUnits + vehicles;
            { _x addCuratorEditableObjects [_objs, true] } forEach allCurators;
        };
        sleep 3;
    };
};
