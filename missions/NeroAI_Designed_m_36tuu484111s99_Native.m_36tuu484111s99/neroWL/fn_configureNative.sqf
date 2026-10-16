/* Mission-scoped native FSM adaptation. Existing CP, delivery, vehicle capacity
 * and native fast travel remain under Warlords control. No new economy. */
// BIS functions are final: the addon selects the FSM before compilation.
private _path = getText (configFile >> "CfgFunctions" >> "A3_Warlords" >> "Warlords" >> "WLAIPurchases" >> "file");
private _expected = "\NeroWL\functions\native\fn_WLAIPurchases.fsm";
diag_log format ["[NeroWL Native] purchase FSM configured=%1 path=%2; native AI core and fast travel unchanged",_path == _expected,_path];
