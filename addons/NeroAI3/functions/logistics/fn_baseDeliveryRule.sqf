/* PURE: only a supported cart inside its currently owned main base is ground. */
params ["_inside","_owned","_supported"];
if (_inside && {_owned} && {_supported}) then {"GROUND"} else {"AIR"}
