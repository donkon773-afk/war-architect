/* War Architect replacement for BECTI's legacy MapMarkersTitling.sqf.
   The marker display owns its handlers and releases them when it closes.
   Never clear an event list from inside that list's running callback.
   Keep native map input and other mods' handlers intact. */
if (!hasInterface) exitWith {};
if (missionNamespace getVariable ["WA_BECTI_markerTitlingStarted",false]) exitWith {};
missionNamespace setVariable ["WA_BECTI_markerTitlingStarted",true];
disableSerialization;

// Also handles displays opened by keyboard or another map UI. No input lock,
// busy loop, or replacement of the map's double-click behavior is needed.
while {true} do {
    waitUntil {uiSleep 0.05; !isNull (findDisplay 54)};
    private _display = findDisplay 54;
    if (!isNull _display && {!(_display getVariable ["WA_BECTI_markerTitleAttached",false])}) then {
        _display setVariable ["WA_BECTI_markerTitleAttached",true];
        _display displayAddEventHandler ["KeyDown",{
            params ["_display","_key"];
            if (_key in [28,156] && {!(_display getVariable ["WA_BECTI_markerTitleApplied",false])}) then {
                private _control = _display displayCtrl 101;
                if (!isNull _control && {!isNull player}) then {
                    private _text = ctrlText _control;
                    _control ctrlSetText (if (_text == "") then {name player} else {format ["%1: %2",name player,_text]});
                    _display setVariable ["WA_BECTI_markerTitleApplied",true];
                };
            };
            // Let the engine handle Enter/Escape and close its own display.
            false
        }];
    };
    waitUntil {uiSleep 0.05; isNull _display};
};
