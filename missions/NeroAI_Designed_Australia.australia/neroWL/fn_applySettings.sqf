if (!isServer) exitWith {};
private _param = {
    params ["_name","_default","_allowed"];
    private _value = [_name,_default] call BIS_fnc_getParamValue;
    if !(_value in _allowed) then {_value = _default;};
    _value
};
NeroAI_enemyAIEnabled = (["NeroWL_LLM",1,[0,1]] call _param) == 1;
NeroWL_airLimit = ["NeroWL_Air",5,[0,1,3,5]] call _param;
NeroAI_airEnabled = NeroWL_airLimit > 0;
NeroAI_airMaxConcurrentPerSide = NeroWL_airLimit;
NeroWL_aggression = ["NeroWL_Aggression",1,[0,1,2]] call _param;
NeroWL_skill = ["NeroWL_Skill",1,[0,1,2]] call _param;
// Prevent the addon's historical top-up from overriding the chosen lobby CP.
NeroAI_warlordsStartFunds = ["BIS_WLStartCP",3000,[1000,1500,3000,6000,10000]] call _param;
NeroWL_garrisonCaps = [["NeroWL_EastGarrison",-1,[-1,0,6,12,18,24,36,60]] call _param,["NeroWL_WestGarrison",-1,[-1,0,6,12,18,24,36,60]] call _param,["NeroWL_GreenGarrison",-1,[-1,0,6,12,18,24,36,60]] call _param];
NeroWL_friendlyMode=["NeroWL_FriendlyLLM",1,[0,1,2]] call _param;
NeroAI_friendlyLLMEnabled=NeroWL_friendlyMode>0;
NeroAI_friendlyAutoEnrollEnabled=NeroWL_friendlyMode==2;
NeroAI_maxFriendlyGroups=["NeroWL_FriendlyLimit",4,[1,2,4,8,12,16]] call _param;
{publicVariable _x;} forEach ["NeroWL_garrisonCaps","NeroWL_friendlyMode","NeroAI_friendlyLLMEnabled","NeroAI_friendlyAutoEnrollEnabled","NeroAI_maxFriendlyGroups"];
diag_log format ["[NeroWL Settings] garrisonCaps EAST/WEST/GREEN=%1 friendlyMode=%2 friendlyLimit=%3",NeroWL_garrisonCaps,NeroWL_friendlyMode,NeroAI_maxFriendlyGroups];
NeroWL_settingsApplied = true;
{publicVariable _x;} forEach ["NeroAI_enemyAIEnabled","NeroAI_airEnabled","NeroAI_airMaxConcurrentPerSide","NeroWL_airLimit","NeroWL_aggression","NeroWL_skill","NeroWL_settingsApplied"];
diag_log format ["[NeroWL Settings] applied: LLM=%1 airLimit=%2 skill=%3 aggression=%4",NeroAI_enemyAIEnabled,NeroWL_airLimit,NeroWL_skill,NeroWL_aggression];
// Units bought later receive the same bounded difficulty. Players are untouched.
[] spawn {
    private _values = [[0.3,0.12],[0.5,0.2],[0.7,0.3]] # NeroWL_skill;
    while {true} do {
        {
            if (local _x && {alive _x} && {!isPlayer _x} && {!(_x getVariable ["NeroWL_skillApplied",false])}) then {
                _x setSkill ["general",_values # 0];
                _x setSkill ["aimingAccuracy",_values # 1];
                _x setSkill ["aimingShake",_values # 0];
                _x setSkill ["spotDistance",_values # 0];
                _x setSkill ["courage",_values # 0];
                _x setVariable ["NeroWL_skillApplied",true];
            };
        } forEach allUnits;
        sleep 15;
    };
};
