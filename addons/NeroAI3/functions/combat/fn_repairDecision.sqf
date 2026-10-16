/* PURE: no engineer leaves into recent direct fire, even after a timeout. */
params [["_damaged",false],["_mobile",true],["_knownNear",1e9],["_sinceHit",1e9],["_engineer",false],["_tools",false],["_cover",false],["_manual",false],["_critical",false]];
if (_manual) exitWith {"DEFER"};
if (!_damaged) exitWith {"IGNORE"};
if (_critical) exitWith {"EVACUATE"};
if (_knownNear < 200 || {_sinceHit < 20}) exitWith {if (_mobile) then {"WITHDRAW"} else {"WAIT_COVER"}};
if (!_engineer) exitWith {"REQUEST_ENGINEER"};
if (!_tools) exitWith {"NEED_TOOLS"};
if (!_cover && {_knownNear < 600}) exitWith {"WAIT_COVER"};
"REPAIR"
