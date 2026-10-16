/* PURE: one outstanding request per group, bounded queue. */
params ["_groups","_group",["_limit",64]];
if (_group in _groups) exitWith {"DUPLICATE"};
if (count _groups >= _limit) exitWith {"FULL"};
"ACCEPT"
