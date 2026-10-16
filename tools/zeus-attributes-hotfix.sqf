// Execute LOCALLY in the host's debug console, then reopen Zeus.
private _z = getAssignedCuratorLogic player;
if (isNull _z) exitWith {hint "Zeus is not assigned";};
if !(_z getVariable ["NeroWL_attributeHandlers",false]) then {
    {
        _z addEventHandler [_x,{
            if (!dialog) then {
                private _opened = (_this # 1) call BIS_fnc_showCuratorAttributes;
                diag_log format ["[NeroWL Zeus] hotfix attributes opened=%1 target=%2",_opened,_this # 1];
            };
        }];
    } forEach ["CuratorObjectDoubleClicked","CuratorGroupDoubleClicked","CuratorWaypointDoubleClicked","CuratorMarkerDoubleClicked"];
    _z setVariable ["NeroWL_attributeHandlers",true];
};
{_z setVariable ["BIS_fnc_curatorAttributes"+_x,["%ALL"]];} forEach ["object","group","waypoint","marker"];
_z addCuratorEditableObjects [allUnits + vehicles,true];
hint "Zeus attributes enabled. Reopen Zeus and double-click an NPC or vehicle.";
