"use strict";
// 7.10 late session: columns stuck at the bridge by the RED base, BMDs in the
// trees, squads abandoning bought tanks, Mi-8 flying without unloading troops.
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const root = path.join(__dirname, "..");
const read = file => fs.readFileSync(path.join(root, file), "utf8");
const fn = name => read(`addons/NeroAI3/functions/${name}`);

test("marches follow the engine road route out of contact; cross-country only in contact or the last leg", () => {
  const route = fn("tactical/fn_vehicleRoute.sqf");
  assert.match(route, /calculatePath \[_type, "SAFE", _from, _end\]/);
  assert.match(route, /addEventHandler \["PathCalculated"/);
  assert.match(route, /_target nearRoads 350/);
  // 7.10 late: only a real firefight leaves the road (fresh contact <=400 m or a loss <30 s).
  assert.match(route, /targets \[true, 400, \[\], 20\]/);
  assert.match(route, /NeroAI_lastLossReport/);
  assert.doesNotMatch(route, /\(behaviour _l\) isEqualTo "COMBAT"/);
  assert.match(route, /if \(call _inContact \|\| \{_mover distance2D _target < 400\}\) then \{/);
  // A sample over water with a road under it is a bridge.
  assert.match(route, /_bridge = surfaceIsWater _p && \{\(_p nearRoads 12\) isNotEqualTo \[\]\}/);
  assert.match(route, /call NeroAI_fnc_motionRecover/, "bounded geometry-aware recovery replaces a fixed reverse");
  assert.match(route, /\(_oldTarget distance2D _target\) < 60/, "the 120 s native reissue keeps a live route");
  assert.match(route, /NeroWL_motionOwner/, "each vehicle has one controller");
  const tactics = fn("tactical/fn_vehicleTactics.sqf");
  assert.match(tactics, /\[_guide,_group,_position,_pedestrians\] call NeroAI_fnc_vehicleRoute/);
  const macro = fn("core/fn_executeMacro.sqf");
  assert.equal((macro.match(/_result = \[_group, "MOVE", _position,objNull,_source,_type\] call NeroAI_fnc_vehicleTactics;/g) || []).length, 3);
  assert.doesNotMatch(macro, /\{ _x doMove _position; \} forEach _members;/);
});

test("native airdrop watchers no longer make NeroAI squads abandon bought vehicles", () => {
  const { adapt } = require("../tools/adapt-airdrop");
  const native = fs.readFileSync(path.join(root, "research/native/Warlords/fn_WLAirdrop.sqf"), "latin1");
  const generated = fs.readFileSync(path.join(root, "addons/NeroAI3/functions/native/fn_WLAirdrop.sqf"), "latin1");
  assert.equal(adapt(native), generated);
  assert.match(generated, /vehicle leader _grp != _veh\)\) && !\(_grp getVariable \["NeroAI_active", FALSE\]\)/);
  assert.match(generated, /distance _pos < 0\.5 && !\(\(group effectiveCommander _this\) getVariable \["NeroAI_active", FALSE\]\)/);
  assert(fn("CfgFunctions.hpp").includes('class WLAirdrop {file="\\NeroWL\\functions\\native\\fn_WLAirdrop.sqf";};'));
  assert.match(read("tools/build-australia-mission.js"), /require\("\.\/adapt-airdrop"\)\.write\(root\);/);
});

test("a squad of five or more buys a carrier first, so nobody is left walking beside a 4-seat tank", () => {
  const auto = fn("tactical/fn_autoRequisition.sqf");
  assert.match(auto, /if \(\(count _living\) >= 5\) then \{\s*\["APC", "TANK", "CAR"\]/);
});

test("transport helicopters carry troops whoever bought them, and always put them out", () => {
  const buy = fn("tactical/fn_purchaseAirAsset.sqf");
  assert.match(buy, /_boughtRole == "AIR_TRANSPORT"/);
  assert.match(buy, /if \(_role == "AIR_TRANSPORT" \|\| \{_carrier\}\) then \{"TRANSPORT"\}/);
  const lift = fn("tactical/fn_airTransport.sqf");
  assert.match(lift, /createVehicle \["Land_HelipadEmpty_F"/);
  assert.match(lift, /\[_landing,"GET OUT"\] call _flyLand/);
  assert.match(lift, /if \(alive _air && \{isTouchingGround _air\}\) then \{\{if \(alive _x && \{local _x\} && \{!isPlayer _x\} && \{group _x isEqualTo _group\} && \{vehicle _x == _air\}\) then \{moveOut _x;\};\} forEach _troops;\};/);
  assert.match(lift, /aborted; emergency drop/);
  assert.match(lift, /\(_air distance2D \[_spot # 0,_spot # 1,0\]\)<700/);
  for (const phase of ["pickup landed", "boarded %1/%2", "drop landed", "unloaded, %1 still aboard", "finished aborted=%1"]) assert(lift.includes(phase), phase);
});

test("marches use an A* route over the live road network first, with the engine planner as fallback", () => {
  const astar = fn("tactical/fn_roadRoute.sqf");
  assert.match(astar, /if \(!canSuspend\) exitWith \{\[\]\};/);
  assert.match(astar, /roadsConnectedTo _road/);
  assert.match(astar, /nearRoads 25/);
  assert.match(astar, /NeroWL_roadRouteCache/);
  assert.match(astar, /private _push = \{[\s\S]*private _pop = \{/, "binary heap, not a linear scan");
  const route = fn("tactical/fn_vehicleRoute.sqf");
  const a = route.indexOf("call NeroAI_fnc_roadRoute"), e = route.indexOf("calculatePath [_type");
  assert(a > 0 && e > a, "A* before calculatePath");
  assert.match(route, /\[true\] call _corridorStep/, "road mode fallback keeps to road candidates");
  assert.match(route, /\[false\] call _corridorStep/);
  assert.doesNotMatch(route, /= call _corridorStep/, "no argument-less call that would leak _this");
  assert.match(route, /route plan mode=ROAD method=%5/);
  const cfg = fn("CfgFunctions.hpp");
  assert.match(cfg, /class roadRoute \{\};/);
  assert.match(cfg, /class roadSurvey \{\};/);
  assert.match(fn("bootstrap/fn_initServer.sqf"), /\[\] spawn \{sleep 20; \[\] call NeroAI_fnc_roadSurvey;\};/);
  assert.match(fn("tactical/fn_roadSurvey.sqf"), /BIS_WL_connectedSectors/);
  assert.match(fn("core/fn_buildSnapshot.sqf"), /"roadLinks", _roadLinks,/);
  assert.match(require("../bridge/lm-studio").SYSTEM_PROMPT, /roadLinks = \[sectorA,sectorB,roadKm,straightKm\]/);
});

test("transport squads fly their own helicopter and re-purchases find a pad at a busy airfield", () => {
  assert.match(fn("tactical/fn_vehicleTactics.sqf"), /\(_group getVariable \["NeroWL_role",""\]\) == "AIR_TRANSPORT"/);
  assert.match(fn("tactical/fn_autoAirTask.sqf"), /\[_group,"DISEMBARK"\] call NeroAI_fnc_vehicleTactics;/);
  assert.match(fn("tactical/fn_purchaseAirAsset.sqf"), /for "_ring" from 0 to 4 do \{/);
});

test("native sunk-vehicle cleanup uses its own vehicle variable", () => {
  const { adapt } = require("../tools/adapt-observer-init");
  const generated = fn("native/fn_WLInit.sqf");
  assert.equal(adapt(read("research/native/Warlords/fn_WLInit.sqf")), generated);
  assert.match(generated, /\} forEach crew _veh;\s*deleteVehicle _veh;/);
  assert.doesNotMatch(generated, /\} forEach crew _x;\s*deleteVehicle _veh;/);
});

test("8.10: a partly mounted squad buys a carrier for its walking tail, and every refusal change is logged", () => {
  const auto = fn("tactical/fn_autoRequisition.sqf");
  assert.match(auto, /_canBuyTail = \(_vState isEqualTo "PARTIAL_MOUNTED"\) && \{\(count _pedestrians\) >= 2\} && \{\(count _aliveOwn\) < _maxVehicles\} && \{_boardable isEqualTo \[\]\};/);
  assert.doesNotMatch(auto, /_canBuyTail = false;/);
  assert.match(auto, /NeroWL_lastGroundRefusal/);
  assert.doesNotMatch(auto, /NeroAI_autoBuyRefusedLogged", 0\]\) < 1/);
  assert.match(fn("bootstrap/fn_preInit.sqf"), /NeroAI_purchaseMaxVehicles = 2;/);
});
