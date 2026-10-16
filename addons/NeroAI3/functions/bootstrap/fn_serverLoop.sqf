if (!isServer) exitWith {};

// Transport polling, group housekeeping and autonomous tactics must not share one
// scheduled script.  If one subsystem encounters a mission-data error, pending
// player commands still reach fn_dispatchResponse instead of being stranded in
// the INIDBI queue.
[] spawn {
    while {true} do {
        if (NeroAI_transportReady && {!NeroAI_rulesMode}) then {
            [] call NeroAI_fnc_pollBridgeResponses;
        };
        sleep 0.25;
    };
};

[] spawn {
    while {true} do {
        if ((diag_tickTime - NeroAI_lastHousekeepingTick) >= 2) then {
            [] call NeroAI_fnc_groupHousekeeping;
            NeroAI_lastHousekeepingTick = diag_tickTime;
        };
        sleep 0.25;
    };
};

[] spawn {
    while {true} do {
        [] call NeroAI_fnc_mobilityWatchdog;
        sleep 8;
    };
};

[] spawn {
    while {true} do {
        if (missionNamespace getVariable ["NeroAI_ambushEnabled", true]) then {
            [] call NeroAI_fnc_ambushWatch;
        };
        sleep 4;
    };
};

[] spawn {
    while {true} do {
        if (NeroAI_transportReady && {missionNamespace getVariable ["NeroAI_enemyAIEnabled", true]}) then {
            [] call NeroAI_fnc_manageEnemyAI;
            [] call NeroAI_fnc_manageGarrisonLLM;
        };
        /* 4.4.0: the player's own side is enrolled automatically too. */
        if (NeroAI_transportReady && {missionNamespace getVariable ["NeroAI_friendlyAutoEnrollEnabled",false]}) then {[] call NeroAI_fnc_manageFriendlyAI;};
        /* Player-controlled groups stay under the player's command. */
        sleep 8;
    };
};

/* 4.3.0: hostile tube tracking runs on its own slow loop — a Fired handler is
 * cheap, but the scan over `vehicles` is not, so keep it well away from the
 * fast tactical tick. */
[] spawn {
    while {true} do {
        if (missionNamespace getVariable ["NeroAI_counterBatteryEnabled", true]) then {
            [] call NeroAI_fnc_counterBattery;
        };
        sleep 10;
    };
};

/* 4.3.0: GREEN garrisons are built lazily near players, and UAV terminals are
 * handed to units as they enrol, so both run on a slow housekeeping loop. */
[] spawn {
    while {true} do {
        if (missionNamespace getVariable ["NeroAI_greenGarrisonEnabled", true]) then {
            [] call NeroAI_fnc_spawnGreenGarrison;
        };
        /* Native Warlords CP income is authoritative. */
        sleep 30;
    };
};

/* 11.10: tactical AI without LLM — the side strategist and the AI commanders'
 * sector vote run on their own threads (a fault there never stops the squads). */
if (NeroAI_rulesMode) then {
    [] spawn NeroAI_fnc_rulesVoteWatch;
    [] spawn {
        while {true} do {
            if (NeroAI_transportReady) then {[] call NeroAI_fnc_rulesCommander;};
            sleep (missionNamespace getVariable ["NeroAI_rulesCommanderSeconds", 20]);
        };
    };
};

[] spawn {while {true} do {[] call NeroAI_fnc_vehicleBattleWatch;sleep 3;};};
[] spawn {while {true} do {[] call NeroAI_fnc_purchaseQueueTick;sleep 1;};};

/* Per-minute side telemetry (CP, fleet, strength, GREEN cap, FPS) for acceptance. */
[] spawn {
    while {true} do {
        sleep 60;
        if (NeroAI_transportReady) then {[] call NeroAI_fnc_sideTelemetry;};
    };
};

while {true} do {
    if ((diag_tickTime - NeroAI_lastAutonomyTick) >= NeroAI_autonomyIntervalSeconds) then {
        [] call NeroAI_fnc_tacticalAutonomy;
        NeroAI_lastAutonomyTick = diag_tickTime;
    };
    sleep 0.25;
};
