/* ACE Repair converts the vanilla trait to ACE_IsEngineer (boolean or skill level). */
params ["_trait","_aceRole"];
_trait isEqualTo true || {_aceRole isEqualTo true} || {_aceRole isEqualType 0 && {_aceRole>0}}
