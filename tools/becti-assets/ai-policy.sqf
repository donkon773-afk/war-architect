/* Deterministic policy; no engine mutations, time is an explicit input. */
params ["_ready","_role","_reason","_power","_threat","_infantrySupport","_armorSupport","_stageDistance","_waited","_townDistance"];
if (_reason in ["DAMAGED","FUEL","AMMO","CREW"]) exitWith {"WITHDRAW"};
if (!_ready) exitWith {"PREPARE"};
if (_role in ["AirIntercept","AirCAS","AirHeli","AirBomber","AirAttack"]) exitWith {"AIR"};
if (_role=="AntiAir") exitWith {"COVER"};
if (_stageDistance>180 && {_townDistance>900}) exitWith {"ASSEMBLE"};
if (_threat>_power*1.4+_armorSupport*6+_infantrySupport*3) exitWith {if (_waited>120) then {"RETARGET"} else {"WAIT_SUPPORT"}};
if (_role in ["Armored","Motorized"] && {_infantrySupport==0} && {_threat>_power*.6}) exitWith {if (_waited>120) then {"RETARGET"} else {"WAIT_SUPPORT"}};
if (_role in ["Infantry","InfantryAT","InfantryAA"] && {_armorSupport==0} && {_threat>_power}) exitWith {if (_waited>120) then {"RETARGET"} else {"WAIT_SUPPORT"}};
if (_townDistance<850) then {"ASSAULT"} else {"ADVANCE"}
