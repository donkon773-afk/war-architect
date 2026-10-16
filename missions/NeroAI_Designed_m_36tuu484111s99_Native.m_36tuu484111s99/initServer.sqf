diag_log format ["[NeroWL Mission] NeroAI_Designed_m_36tuu484111s99_Native: world=%1 multiplayer=%2 server=%3", worldName, isMultiplayer, isServer];
NeroAI_maxEnemyArmyGroups=16;
NeroAI_maxEnemyGroups=3;
call compile preprocessFileLineNumbers "neroWL\fn_applySettings.sqf";

NeroAI_warlordsStartFunds=6000; NeroAI_baseAssetsEnabled=false; NeroAI_greenGarrisonEnabled=false;
[] spawn NeroWL_Design_fnc_start;
