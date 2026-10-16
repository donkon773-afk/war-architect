diag_log format ["[NeroWL Mission] NeroAI_WL_RHS_Zeus_Altis: world=%1 multiplayer=%2 server=%3", worldName, isMultiplayer, isServer];
NeroAI_maxEnemyArmyGroups=10;
NeroAI_maxEnemyGroups=3;
call compile preprocessFileLineNumbers "neroWL\fn_applySettings.sqf";
