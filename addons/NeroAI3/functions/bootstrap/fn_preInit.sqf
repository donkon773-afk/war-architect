/* NeroAI 4.5.0 [Vanilla Command] has no dynamic code path. CfgFunctions owns function loading. */
NeroAI_pending = createHashMap;
NeroAI_activeGroups = createHashMap;
NeroAI_sharedIntel = createHashMap;
NeroAI_lastHousekeepingTick = 0;
NeroAI_lastAutonomyTick = 0;
/* Per-group tactical actions use these values rather than global timers. */
NeroAI_reconCooldownSeconds = 15;
NeroAI_fireSupportCooldownSeconds = 150;
NeroAI_radioCooldownSeconds = 20;
NeroAI_supportCooldownSeconds = 45;
NeroAI_autonomyIntervalSeconds = 8;
NeroAI_intelTtlSeconds = 180;
/* INIDBI2 refuses a value above 8 KB (live 23:20: an 8-group player order was
 * silently lost — "data too big > 8K"). Snapshot + envelope must stay under it. */
NeroAI_maxSnapshotChars = 7400;
NeroAI_maxSnapshotBytes = 7400;
NeroAI_maxWireBytes = 7900;
NeroAI_maxPlayerCommandChars = 400;
NeroAI_conversationTurns = 6;
NeroAI_maxActions = 5;
/* Scheduled plans every 30 s (live 23:00: 20 s × 15 groups = 46 requests/min hit the
 * org token limit); events (contact, ambush, losses, stall, player) still replan immediately. */
NeroAI_autonomyPlanIntervalSeconds = 75;
NeroAI_autonomyRadioCooldownSeconds = 20;
/* Minimum displacement (m) for an autonomous ADVANCE/ASSAULT/RETREAT. A shorter
 * autonomous march is a self-move that only makes the group jitter in place. */
NeroAI_autonomyMinAdvanceMeters = 35;
/* Plan several groups per cycle. 4.6.0 local LLM: a Qwen3.5-9B plan on the
 * RTX 3060 takes ~8-25 s (bench 16.09), the bridge sends at most 2 at once and
 * the rest queue against the 100 s request timeout — 2 in flight keeps every
 * plan inside that window; 4 was sized for a ~1.5 s cloud model. */
NeroAI_autonomyMaxParallelPlans = 1;
NeroAI_maxPendingAutonomy = 1;
/* 4.4.0: a group whose snapshot hash has not changed and that has no fresh
 * events skips its scheduled plan — the cheapest request is the one not sent. */
NeroAI_planSkipUnchanged = true;
/* 4.2.0: LLM radio dialogue between friendly groups (support / intel / coordination). */
NeroAI_intergroupEnabled = true;
NeroAI_intergroupMaxHops = 1;
NeroAI_intergroupMaxConcurrent = 2;
NeroAI_intergroupPairCooldown = 30;
NeroAI_intergroupActive = 0;
/* 4.2.0: detect and report a sudden close ambush. */
NeroAI_ambushEnabled = true;
/* 4.2.0 post-session: monotonic callsign counter so re-enrolled groups never
 * collide (a duplicate callsign made addressed player orders resolve 0 groups). */
NeroAI_callsignSeq = 0;
/* 4.2.0 post-session anti-loop: after this many autonomous plans with no manoeuvre
 * and no new contacts, a group stops asking for a fresh scheduled plan. */
NeroAI_idlePlanBackoffAfter = 3;
NeroAI_transportReady = false;
NeroAI_serverInitStarted = false;
NeroAI_visionCaptureEnabled = false;
NeroAI_visionCaptureInterval = 20;
NeroAI_visionLoopStarted = false;
NeroAI_enemyAIEnabled = true;
/* 9.10: set by the mission lobby (NeroWL_VanillaAI); true = standard Arma AI, NeroAI stays idle. */
NeroAI_vanillaMode = false;
/* 11.10: set by the mission lobby (NeroWL_VanillaAI = 2); true = NeroAI tactical AI
 * without LLM: side strategist + squad rules, no bridge, no INIDBI, no models. */
NeroAI_groundPurchaseCrew = true;
NeroAI_rulesMode = false;
NeroAI_rulesCommanderSeconds = 20;
NeroAI_rulesSectorIntelSeconds = 600;
NeroAI_rulesRadioEnabled = true;
NeroAI_rulesMinAssaultStrength = 6;
NeroAI_rulesMinAssaultRatio = 0.6;
NeroAI_rulesConsolidateSeconds = 120;
NeroAI_rulesPlanIntervalSeconds = 15;
NeroAI_rulesMaxParallelPlans = 4;
NeroAI_rulesAmmoTierOverrides = createHashMap;
NeroAI_maxEnemyGroups = 2;
/* 4.4.0: regular army opposing the player — no distance gate, own cap. */
NeroAI_maxEnemyArmyGroups = 6;
/* 4.4.0: the player's own AI squads are enrolled automatically (sticky opt-out via the menu). */
NeroAI_friendlyAutoEnrollEnabled = false;
NeroAI_maxFriendlyGroups = 16;
/* 4.5.0: partisans (GREEN) only — regular armies have no distance gate. */
NeroAI_enemyMaxDistanceMeters = 2500;
NeroAI_lastEnemyManageTick = 0;
/* 4.2.0 post-session: the adversary (RED regular army / GREEN partisans) must be
 * under NeroAI from the first seconds of a match, not only once the player drives
 * within 4 km. On the first manage pass after the bridge is up we seed the closest
 * hostile groups PER hostile side out to a wide radius, guarantee a per-side
 * minimum, and keep those seeded groups enrolled through a grace window so the
 * next prune pass does not immediately drop them for distance. */
NeroAI_enemyMinPerSide = 2;
NeroAI_enemySeedDistanceMeters = 9000;
NeroAI_enemySeedGraceSeconds = 600;
NeroAI_enemySeeded = false;
NeroAI_enemySeedGraceUntil = 0;
/* 4.4.0 [Command] — indirect-fire safety. A plan grid is model-supplied and can
 * be stale; rounds must never land on our own people, on a grid the enemy has
 * already left, or on the same square over and over. */
NeroAI_fireSafetyRadius = 180;
NeroAI_firePlayerSafetyRadius = 250;
NeroAI_fireTargetMaxDriftMeters = 150;
NeroAI_fireGridCooldownSeconds = 90;
NeroAI_fireRoundsPerMission = 3;
NeroAI_fireGridLog = createHashMap;

/* Base asset package — 4.5.0: one armed drone per side, nothing else. */
NeroAI_baseAssetsEnabled = false;
NeroAI_baseAssetsSpawned = false;
NeroAI_assetCache = createHashMap;
/* A runway candidate farther than this from a side's own base is not that
 * side's airfield — reject it rather than parking both sides' aircraft on the
 * map's one shared strip regardless of whose base it is actually near. */
NeroAI_airfieldMaxDistanceMeters = 6000;

/* 4.3.0 — cautious aviation doctrine. */
NeroAI_airEnabled = true;
NeroAI_airEnemyBaseNoFlyMeters = 1400;
NeroAI_airAaAvoidMeters = 800;
NeroAI_airStandoffMeters = 1100;
NeroAI_airSortieSeconds = 150;
NeroAI_airRtbSeconds = 240;
NeroAI_airSortieCooldownSeconds = 180;
/* 4.4.0: no group may re-request air within this window; per-side airborne cap. */
NeroAI_airGroupRequestCooldown = 240;
NeroAI_airMaxConcurrentPerSide = 2;

/* GREEN objective garrisons: a random 1-2 draw per sector from the scavenged
 * pool (T-55 / T-34 / BTR-60 / BRDM-2 / BMP-1), a rare spotter drone and a rare
 * standoff mortar. BLUE/RED have no scripted motor pool: they buy vanilla
 * Warlords requisition with their CP (fn_purchaseAsset). */
NeroAI_greenGarrisonEnabled = false;
NeroAI_greenGarrisonRadiusMeters = 5000;
NeroAI_greenGarrisonMaxVehicles = 24;
NeroAI_greenGarrisonDone = createHashMap;
NeroAI_greenGarrisonVehicles = 0;
NeroAI_greenGarrisonCentres = [];
NeroAI_greenDroneChance = 0.08;
NeroAI_greenMortarChance = 0.05;
NeroAI_greenMortarStandoffMeters = 1000;
/* LIVE INCIDENT: a full pile of GREEN armour + 3 mortars turned up at BLUE's
 * base because bis_wl_allWarlords' "sector" entries all resolved within
 * ~40 m of it, and the base-exclusion check silently passed when the base
 * position itself was still unknown. Widened well past the mortar's own
 * ~1.3 km max standoff so a "clear" garrison centre can't still place its
 * mortar back on a base; fn_spawnGreenGarrison also now fails closed (skips
 * everything) instead of open when a base position isn't resolved yet. */
NeroAI_greenBaseExclusionMeters = 2000;

/* 4.3.0 — counter-battery hunts. */
NeroAI_counterBatteryEnabled = true;
NeroAI_counterBatteryRangeMeters = 3000;
NeroAI_counterBatteryTtlSeconds = 300;
NeroAI_counterBatteryTaskCooldown = 120;
NeroAI_hostileBatteries = createHashMap;

NeroAI_supportCache = createHashMap;
NeroAI_supportCacheSeconds = 5;
/* 4.4.0: Warlords sectors (NeroAI_fnc_warlordsSectors) cached between snapshot builds. */
NeroAI_sectorCache = [-1e6, []];
NeroAI_sectorCacheSeconds = 5;
NeroAI_sectorsProbed = false;

/* Scenario tuning: every warlord's purse is topped up to this many CP once
 * (fn_scenarioTuning); NeroAI groups then SPEND it via BUY (fn_purchaseAsset). */
NeroAI_warlordsStartFunds = 0;
NeroAI_purchaseCooldownSeconds = 90;
NeroAI_purchaseSideCooldownSeconds = 75;
NeroAI_purchaseSideNextAllowed = createHashMap;
NeroAI_purchaseReserveCP = 1500;
/* 8.10: a second vehicle only as a carrier for a walking tail (fn_autoRequisition). */
NeroAI_purchaseMaxVehicles = 2;
/* Deterministic policy (fn_autoRequisition): board own empty vehicles first;
 * with no vehicle and this much CP, buy one without waiting for the model. */
NeroAI_purchaseAutoEnabled = true;
NeroAI_purchaseAutoMinCP = 2500;
NeroAI_fundsApplied = false;
NeroAI_uavTerminalsEnabled = true;

/* Server-owned respawn authority snapshots, keyed by immutable player UID. */
NeroAI_playerAuthority = createHashMap;

/* 4.7.0 [Any Warlords]: no map list. fn_scenarioProfile surveys the terrain and
 * reads the mission's factions and bases at server start; a mission may preset
 * NeroAI_terrainProfile in init.sqf and it is honoured ("" / "AUTO" = survey). */
if (isNil "NeroAI_terrainProfile") then { NeroAI_terrainProfile = "AUTO"; };
NeroAI_terrainLine = "";
