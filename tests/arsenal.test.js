"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const addonRoot = path.join(__dirname, "..", "addons", "NeroAI3");
const read = rel => fs.readFileSync(path.join(addonRoot, rel), "utf8");

test("indirect fire refuses danger-close, stale and repeat grids before any round flies", () => {
  const fire = read("functions/tactical/fn_requestFireSupport.sqf");
  const preInit = read("functions/bootstrap/fn_preInit.sqf");

  /* the three guards must all sit ABOVE the only doArtilleryFire call */
  const dangerAt = fire.indexOf("NeroAI_firePlayerSafetyRadius");
  const staleAt = fire.indexOf("NeroAI_fireTargetMaxDriftMeters");
  const gridAt = fire.indexOf("NeroAI_fireGridCooldownSeconds");
  const fireAt = fire.indexOf("doArtilleryFire");
  assert.ok(dangerAt > 0 && staleAt > 0 && gridAt > 0, "all three guards must be present");
  assert.ok(dangerAt < fireAt, "danger-close check must precede the salvo");
  assert.ok(staleAt < fireAt, "stale-target check must precede the salvo");
  assert.ok(gridAt < fireAt, "grid cooldown must precede the salvo");

  /* players get the wider bubble, and a refusal is a refusal */
  assert.match(fire, /isPlayer _x\) then \{_playerR\} else \{_safeR\}/);
  assert.match(fire, /DANGER_CLOSE/);
  assert.match(fire, /NO_TARGET/);
  assert.equal((fire.match(/doArtilleryFire/g) || []).length, 1, "exactly one salvo call");

  assert.match(preInit, /NeroAI_fireSafetyRadius\s*=\s*180/);
  assert.match(preInit, /NeroAI_firePlayerSafetyRadius\s*=\s*250/);

  /* every refusal path must be visible in the RPT, not just danger-close and
   * stale-target — a live session showed 17 of 51 REQUEST_FIRE calls vanish
   * with no trace because the grid-cooldown and no-asset-in-range exits never
   * logged anything. */
  assert.match(fire, /квадрат %5 уже обстрелян/);
  assert.match(fire, /GRID_COOLDOWN/);
  assert.match(fire, /нет своей артиллерии\/миномёта в досягаемости/);
});

test("asset roles resolve through a fallback chain instead of one hardcoded class", () => {
  const catalog = read("functions/core/fn_assetCatalog.sqf");
  const cfg = read("functions/CfgFunctions.hpp");
  assert.match(catalog, /isClass \(configFile >> "CfgVehicles" >> _x\)/);
  assert.match(catalog, /case "JET_CAS":/);
  assert.match(catalog, /case "HELI_ATTACK":/);
  assert.match(catalog, /case "TANK_LEGACY":/);
  assert.match(catalog, /case "APC_BRDM2":/);
  /* an unresolved role is logged, not silently skipped */
  assert.match(catalog, /unresolved; none of/);
  assert.match(cfg, /class assetCatalog \{\};/);
});

test("an armed role never resolves to an unarmed recon airframe", () => {
  const catalog = read("functions/core/fn_assetCatalog.sqf");

  /* RED's strike drone must be an armed type, and the unarmed Pchela must not
   * be able to win that slot by being first in the list. */
  const redArmed = /case "UAV_ARMED": \{\[([^\]]*)\]\};/.exec(
    catalog.slice(catalog.indexOf("private _red ="))
  )[1];
  assert.match(redArmed, /O_UAV_02_CAS_F/, "RED needs a genuinely armed UAV");
  assert.ok(
    redArmed.indexOf("O_UAV_02_CAS_F") < (redArmed.indexOf("Pchela") >= 0 ? redArmed.indexOf("Pchela") : Infinity),
    "an armed class must outrank any recon airframe in the armed slot"
  );

  /* Pchela stays where it belongs: the recon slot. */
  const redRecon = /case "UAV_RECON": \{\[([^\]]*)\]\};/.exec(
    catalog.slice(catalog.indexOf("private _red ="))
  )[1];
  assert.match(redRecon, /Pchela1T/);

  /* and the resolver enforces armament for every strike role rather than
   * trusting list order alone */
  assert.match(catalog, /_mustShoot = _role in \["UAV_ARMED", "JET_CAS", "JET_FIGHTER", "JET_MULTI_A", "JET_MULTI_B", "HELI_ATTACK", "HELI_ATTACK_2"\]/);
  assert.match(catalog, /_armedOnes = _existing select \{\[_x\] call _fnc_hasWeapon\}/);
  assert.match(catalog, /TransportPylonsComponent/);
  assert.match(catalog, /configClasses \(_cfg >> "Turrets"\)/);
  assert.match(catalog, /config says carries no weapon/);
});


test("4.5.0 base package is ONE armed drone per side, parked cold; no scripted jets, helicopters, mortars or trucks", () => {
  const spawn = read("functions/tactical/fn_spawnBaseAssets.sqf");
  const pkgStart = spawn.indexOf("private _package = [");
  const pkg = spawn.slice(pkgStart, spawn.indexOf("];", pkgStart));
  assert.match(pkg, /\["UAV_ARMED",\s*1,/);
  assert.doesNotMatch(pkg, /MORTAR|JET_|HELI_|TRUCK_/, "everything but the drone is vanilla requisition now");
  /* both sides get the identical package */
  assert.match(spawn, /\["BLUE", west,/);
  assert.match(spawn, /\["RED",\s+east,/);
  /* the drone is parked cold until dispatchAir releases it */
  assert.match(spawn, /_veh engineOn false/);
  assert.match(spawn, /disableAI "MOVE"/);
  assert.match(spawn, /NeroAI_airState", "PARKED"/);
  /* one-shot */
  assert.match(spawn, /NeroAI_baseAssetsSpawned", false\]\) exitWith/);
  /* tarmac resolved from config / bis_wl_airstrips, never a guessed helper */
  assert.match(spawn, /ilsPosition/);
  assert.match(spawn, /bis_wl_airstrips/);
  assert.match(spawn, /"NeroAI_homeBase", _origin/);
  /* CAS and RECON both fly the drone — there is nothing else to dispatch */
  const air = read("functions/tactical/fn_dispatchAir.sqf");
  assert.match(air, /_wantRoles = if \(_mission isEqualTo "RECON"\) then \{\["UAV_ARMED", "UAV_RECON"\]\} else \{\["UAV_ARMED"\]\}/);
});


test("base asset crews are restrained utility crews, never independent combatants", () => {
  const spawn = read("functions/tactical/fn_spawnBaseAssets.sqf");
  const enemyAI = read("functions/tactical/fn_manageEnemyAI.sqf");
  const friendlyAI = read("functions/tactical/fn_manageFriendlyAI.sqf");

  /* live incident: RED's own base UAV crew got swept into the generic enemy-AI
   * manager, handed an ASSAULT order like a rifle squad, and was dead within a
   * minute. A crew must be tagged and excluded from that sweep. */
  assert.match(spawn, /NeroAI_isBaseAssetCrew", true, true/);
  assert.match(spawn, /disableAI "TARGET"/);
  assert.match(spawn, /disableAI "AUTOTARGET"/);
  assert.match(enemyAI, /NeroAI_isBaseAssetCrew", false\]/);
  assert.match(friendlyAI, /NeroAI_isBaseAssetCrew/);
  assert.match(spawn, /_needsCrew.*then.*createVehicleCrew/s);
  /* vanilla skills: NeroAI never edits a crew's skill */
  assert.doesNotMatch(spawn, /setSkill/);
});

test("a runway or base marker far from a side's own base is rejected rather than shared between sides", () => {
  const spawn = read("functions/tactical/fn_spawnBaseAssets.sqf");
  const preInit = read("functions/bootstrap/fn_preInit.sqf");

  /* live incident: the map's one CfgWorlds ilsPosition was accepted with no
   * distance cap, so when neither base was actually near it, both sides'
   * aircraft (8 total) piled into one shared ~60 m ring far from either base
   * — RED's jets/UAVs turned up "at BLUE's base" and BLUE's own aircraft
   * looked like they had flown off toward it and were milling around. */
  assert.match(preInit, /NeroAI_airfieldMaxDistanceMeters\s*=\s*6000/);
  assert.match(spawn, /_maxUsableDist = missionNamespace getVariable \["NeroAI_airfieldMaxDistanceMeters"/);
  assert.match(spawn, /if \(_d <= _bestD\) then \{ _bestD = _d; _best = \[_ils # 0, _ils # 1, 0\]; \}/);

  /* the guessed base marker names are the same failure class as the Warlords
   * sector variable — must self-diagnose, and the cluster fallback must not
   * average two separated fronts into empty space near the other side. */
  assert.match(spawn, /none of the base markers %2 exist on this map/);
  assert.match(spawn, /largest local cluster/);

  /* bis_wl_airstrips — this Warlords build's own real airstrip list, found
   * via the same diagnostic — is tried before the guessed ilsPosition/Airport
   * fallback. */
  const runwayFn = spawn.slice(spawn.indexOf("_fnc_runwayPos = {"));
  const airstripsAt = runwayFn.indexOf("bis_wl_airstrips");
  const ilsAt = runwayFn.indexOf("ilsPosition");
  assert.ok(airstripsAt > 0 && ilsAt > 0 && airstripsAt < ilsAt, "bis_wl_airstrips must be tried before the config ILS fallback");
});


test("4.5.0 BLUE and RED have no scripted motor pool — armour is vanilla requisition bought with the group's own CP", () => {
  const fs = require("fs");
  const path = require("path");
  assert.ok(!fs.existsSync(path.join(addonRoot, "functions", "tactical", "fn_spawnBaseArmor.sqf")), "fn_spawnBaseArmor must be gone");
  assert.doesNotMatch(read("functions/CfgFunctions.hpp"), /spawnBaseArmor/);
  assert.doesNotMatch(read("functions/bootstrap/fn_initServer.sqf"), /spawnBaseArmor/);
  assert.doesNotMatch(read("functions/bootstrap/fn_preInit.sqf"), /NeroAI_baseArmor/);

  /* the BUY path is the vanilla Warlords one, verified against
   * functions_f_warlords (fn_WLAIPurchases.fsm / fn_WLAirdrop / fn_WLInit) */
  const buy = read("functions/tactical/fn_purchaseAsset.sqf");
  assert.match(read("functions/CfgFunctions.hpp"), /class purchaseAsset \{\};/);
  assert.match(buy, /BIS_WL_allWarlords/);
  assert.match(buy, /getVariable \["BIS_WL_funds", 0\]/);
  assert.match(buy, /BIS_WL_purchasable/);
  assert.match(buy, /\[_wl, _cart, true\] call BIS_fnc_WLAirdrop/, "delivery is the vanilla airdrop with the ordered-by-AI flag");
  assert.match(buy, /BIS_WL_groupVehs/);
  assert.match(buy, /BIS_WL_dropPos/);
  assert.match(buy, /BIS_WL_maxCP/);
  assert.match(buy, /BIS_WL_dropCost/);
  assert.match(buy, /\["INFANTRY", "CAR", "APC", "TANK", "TRUCK"\]/);
  /* it is a purchase, not a spawn: no createVehicle, no free money, no skills */
  assert.doesNotMatch(buy, /createVehicle\b|createUnit\b|setSkill|createVehicleCrew/);
  assert.match(buy, /NeroAI_purchaseCooldownSeconds/);
  assert.match(buy, /NeroAI_purchaseReserveCP/);
  assert.match(buy, /NeroAI_purchaseMaxVehicles/);
  /* 4.5.1 T20: best combat value per CP (_score > _bestScore), not just the most expensive or cheapest */
  assert.match(buy, /_fnc_assetScore/);
  assert.match(buy, /if \(_score > _bestScore\) then \{\s*_best = _x;\s*_bestScore = _score;\s*\}/);
  /* the executor wires the action and defaults to armour */
  assert.match(read("functions/core/fn_executeMacro.sqf"), /case "BUY": \{ _result = \[_group, if \(_argument isEqualTo ""\) then \{"TANK"\} else \{_argument\}, _source\] call NeroAI_fnc_purchaseAsset; \};/);
  const preInit = read("functions/bootstrap/fn_preInit.sqf");
  assert.match(preInit, /NeroAI_purchaseCooldownSeconds\s*=\s*90/);
  assert.match(preInit, /NeroAI_purchaseReserveCP\s*=\s*300/);
  assert.match(preInit, /NeroAI_purchaseMaxVehicles\s*=\s*2/);
});

test("RED and BLUE fighters resolve to the specifically requested airframes", () => {
  const catalog = read("functions/core/fn_assetCatalog.sqf");
  const redFighter = /case "JET_FIGHTER": \{\[([^\]]*)\]\};/.exec(
    catalog.slice(catalog.indexOf("private _red ="))
  )[1];
  assert.match(redFighter, /^"rhs_mig29s_vvsc"/, "RED's fighter must lead with a MiG-29");

  const blueFighter = /case "JET_FIGHTER": \{\[([^\]]*)\]\};/.exec(
    catalog.slice(catalog.indexOf("private _blue ="), catalog.indexOf("private _red ="))
  )[1];
  assert.match(blueFighter, /^"rhsusf_f22"/, "BLUE's fighter must lead with an F-22");
});

test("hot loops are latched or cached so they do not rescan every vehicle each tick", () => {
  const cb = read("functions/tactical/fn_counterBattery.sqf");
  const snap = read("functions/core/fn_buildSnapshot.sqf");
  /* the expensive getArtilleryAmmo probe runs once per vehicle, not per pass */
  assert.match(cb, /NeroAI_cbChecked", true, false/);
  assert.ok(
    cb.indexOf("NeroAI_cbChecked\", true, false") < cb.indexOf("!((getArtilleryAmmo"),
    "the checked latch must be set before the expensive probe"
  );
  /* the support summary is cached per side between snapshots */
  assert.match(snap, /NeroAI_supportCache/);
  assert.match(snap, /NeroAI_supportCacheSeconds/);
});

test("air sorties refuse enemy-base airspace and defended targets, and always come home", () => {
  const air = read("functions/tactical/fn_dispatchAir.sqf");
  assert.match(air, /NeroAI_airEnemyBaseNoFlyMeters/);
  assert.match(air, /NeroAI_airAaAvoidMeters/);
  assert.match(air, /NeroAI_airStandoffMeters/);
  /* run-in comes from our own side of the target */
  assert.match(air, /_bearingHome = _aim getDir _home/);
  assert.match(air, /_approach = _aim getPos \[_standoff, _bearingHome\]/);
  /* the watchdog aborts into the bubble and returns to base, then goes cold */
  assert.match(air, /_abort = true/);
  assert.match(air, /_air doMove _home/);
  assert.match(air, /NeroAI_airState", "PARKED", true\]/);
  /* mission waypoints are never touched */
  assert.doesNotMatch(air, /deleteWaypoint|clearWaypoints|addWaypoint|setDamage/);
});

test("CAS goes through the bounded sortie first and reports the refusal reason", () => {
  const fire = read("functions/tactical/fn_requestFireSupport.sqf");
  assert.match(fire, /call NeroAI_fnc_dispatchAir/);
  assert.match(fire, /Авиация недоступна/);
});


test("GREEN garrisons draw a random 1-2 mix per sector, rare drone and mortar, vanilla skills", () => {
  const garrison = read("functions/tactical/fn_spawnGreenGarrison.sqf");
  const preInit = read("functions/bootstrap/fn_preInit.sqf");

  /* the scavenged pool is exactly T-55 / T-34 / BTR-60 / BRDM-2 / BMP-1 */
  assert.match(garrison, /_pool = \["TANK_MAIN", "TANK_LEGACY", "APC_BTR60", "APC_BRDM2", "IFV_BMP1"\]/);
  // 4.7.0: the mission's own Independent faction comes first, the catalogue is the fallback
  assert.match(garrison, /\["GREEN", _x\] call NeroAI_fnc_factionAssets/);
  assert.match(garrison, /private _pick = \[\] call _fnc_pickVehicle;/);
  assert.doesNotMatch(garrison, /APC_BTR80|IFV_BMP2|AAA_SHILKA|TECHNICAL_AA|TANK_HEAVY/);
  /* 4.5.0: fewer vehicles, independent draw per slot */
  assert.match(garrison, /_count = 1 \+ \(floor random 2\)/);
  assert.match(garrison, /selectRandom _pool/);
  assert.match(preInit, /NeroAI_greenGarrisonMaxVehicles\s*=\s*24/);
  /* vanilla skills — no setSkill anywhere in the garrison */
  assert.doesNotMatch(garrison, /setSkill/);

  /* the drone and the standoff mortar are rare probabilities */
  assert.match(garrison, /NeroAI_greenDroneChance/);
  assert.match(garrison, /NeroAI_greenMortarChance/);
  assert.match(garrison, /NeroAI_greenMortarStandoffMeters/);
  assert.match(preInit, /NeroAI_greenDroneChance\s*=\s*0\.08/);
  assert.match(preInit, /NeroAI_greenMortarChance\s*=\s*0\.05/);
  assert.match(preInit, /NeroAI_greenMortarStandoffMeters\s*=\s*1000/);

  /* sectors come from NeroAI_fnc_warlordsSectors; only unowned / partisan,
   * non-base sectors get a park */
  assert.doesNotMatch(garrison, /forEach bis_wl_allWarlords/);
  assert.match(garrison, /call NeroAI_fnc_warlordsSectors/);
  assert.match(garrison, /_ownerKey in \["NONE", "GREEN"\]/);
  assert.match(garrison, /\{!_isBase\}/);

  /* performance guards: per-sector latch, player proximity, global cap */
  assert.match(garrison, /NeroAI_greenGarrisonMaxVehicles/);
  assert.match(garrison, /_done getOrDefault \[_sid, false\]/);
  assert.match(garrison, /_players findIf \{\(_x distance2D _pos\) <= _radius\}/);
});


test("a pile of GREEN armour and mortars at BLUE's base cannot happen again", () => {
  const garrison = read("functions/tactical/fn_spawnGreenGarrison.sqf");
  const preInit = read("functions/bootstrap/fn_preInit.sqf");

  /* live incident: the "sector" list resolved to the bases and the exclusion
   * check silently passed on an UNRESOLVED base position. A safety check with
   * no data must fail closed. */
  const baseCheckAt = garrison.indexOf("_baseBlue =");
  const forEachAt = garrison.indexOf("} forEach _sectors;");
  assert.ok(baseCheckAt > 0 && baseCheckAt < forEachAt, "the base-position guard must run before any sector is processed");
  assert.match(garrison, /NeroAI_basePos_BLUE/);
  assert.match(garrison, /NeroAI_basePos_RED/);
  assert.match(garrison, /count _baseBlue\) < 2.*count _baseRed\) < 2/s);
  assert.match(preInit, /NeroAI_greenBaseExclusionMeters\s*=\s*2000/);
  assert.match(garrison, /_fnc_nearBase = \{/);
  assert.match(garrison, /for "_try" from 1 to 8 do/);
  assert.match(garrison, /ни одно из 8 направлений не очистило базу/);
  assert.match(garrison, /_usedCentres findIf \{\(_x distance2D _pos\) < 300\}/);
  assert.match(garrison, /совпадает с уже использованной позицией/);

  /* 4.5.0: the sector reader uses the variable names verified in the vanilla
   * Warlords sources, and dumps what it found once */
  const sectors = read("functions/core/fn_warlordsSectors.sqf");
  assert.match(sectors, /NeroAI_sectorsProbed/);
  assert.match(sectors, /getVariable \["BIS_WL_sectors", \[\]\]/);
  assert.match(sectors, /\(entities "ModuleWLSector_F"\) \+ \(entities "ModuleWLBase_F"\)/);
  assert.match(sectors, /getVariable \["BIS_WL_sectorSide", nil\]/);
  assert.match(sectors, /\(typeOf _x\) isEqualTo "ModuleWLBase_F"/);
  assert.match(sectors, /getVariable \["Name", ""\]/);
  assert.doesNotMatch(sectors, /forEach bis_wl_allWarlords/i);
  assert.doesNotMatch(sectors, /BIS_WL_owner\b|BIS_WL_isBase|BIS_WL_sectorsArray\b/, "guessed names are gone");
});

test("counter-battery only tasks a hunt after a tube has actually fired", () => {
  const cb = read("functions/tactical/fn_counterBattery.sqf");
  const loop = read("functions/bootstrap/fn_serverLoop.sqf");
  assert.match(cb, /addEventHandler \["Fired"/);
  assert.match(cb, /NeroAI_hostileBatteries/);
  assert.match(cb, /ENEMY_MORTAR/);
  assert.match(cb, /NeroAI_forcePlan/);
  assert.match(cb, /NeroAI_counterBatteryTaskCooldown/);
  /* a battery that never fired is never in the log, so it can never be hunted */
  assert.doesNotMatch(cb, /_batteries set \[/);
  assert.match(loop, /NeroAI_fnc_counterBattery/);
  assert.match(loop, /NeroAI_fnc_spawnGreenGarrison/);
});

test("the snapshot tells the model what support is ready and what hunt it owns", () => {
  const snap = read("functions/core/fn_buildSnapshot.sqf");
  assert.match(snap, /"support", _support/);
  assert.match(snap, /"counterBattery", _cbTask/);
  /* readiness, not just existence */
  assert.match(snap, /NeroAI_airState", "PARKED"\]\) isEqualTo "PARKED"/);
});


test("the planner prompt teaches the single drone, refusal-aware fire support and CP requisition", () => {
  const { SYSTEM_PROMPT } = require("../bridge/lm-studio");
  assert.match(SYSTEM_PROMPT, /DRONE: each army has ONE armed drone/);
  assert.match(SYSTEM_PROMPT, /never near an enemy base/);
  assert.doesNotMatch(SYSTEM_PROMPT, /AVIATION — USE IT SPARINGLY|manned aircraft|F-16|Su-34|LAV-25|Abrams|BTR-80A|T-72/, "no scripted aircraft or vehicle rosters remain");
  assert.match(SYSTEM_PROMPT, /INDIRECT FIRE — THE ENGINE WILL REFUSE UNSAFE MISSIONS/);
  assert.match(SYSTEM_PROMPT, /Treat a refusal as information/);
  assert.match(SYSTEM_PROMPT, /counterBattery is a live hunt handed to you/);
  assert.match(SYSTEM_PROMPT, /If ready is 0 for a role/);
  assert.match(SYSTEM_PROMPT, /REQUISITION — SPEND YOUR CP/);
  assert.match(SYSTEM_PROMPT, /BUY TANK/);
  assert.match(SYSTEM_PROMPT, /INFANTRY\|CAR\|APC\|TANK\|TRUCK \(BUY\)/);
});


test("scenario tuning tops up every warlord's CP purse the vanilla way and hands out UAV terminals", () => {
  const tune = read("functions/bootstrap/fn_scenarioTuning.sqf");
  const preInit = read("functions/bootstrap/fn_preInit.sqf");
  assert.match(preInit, /NeroAI_warlordsStartFunds\s*=\s*15000/);
  /* verified names from functions_f_warlords: the purse is per warlord unit */
  assert.match(tune, /forEach _warlords/);
  assert.match(tune, /getVariable \["BIS_WL_allWarlords", \[\]\]/);
  assert.match(tune, /setVariable \["BIS_WL_funds", _amount, true\]/);
  assert.match(tune, /setVariable \["BIS_WL_startCP", _amount, true\]/);
  assert.match(tune, /BIS_WL_maxCP/);
  /* never below what a warlord already has */
  assert.match(tune, /if \(_have < _amount\) then/);
  /* the guessed shapes and the allVariables dump are gone */
  assert.doesNotMatch(tune, /BIS_WL_fundsWest|allVariables missionNamespace|NeroAI_wlVarsProbed/);
  assert.match(tune, /linkItem _term/);
  assert.match(tune, /NeroAI_terminalGiven/);
  assert.match(tune, /isClass \(configFile >> "CfgWeapons" >> _x\)/);
});
