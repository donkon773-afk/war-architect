/* NeroAI 4.4.0 [Command] — client-side commander's-eye frame grabber.
 *
 * OFF BY DEFAULT. Earlier builds hit DirectX 11 DXGI_ERROR_DEVICE_REMOVED GPU
 * stalls from an always-on screenshot loop, so this only runs when the mission or
 * the player explicitly sets NeroAI_visionCaptureEnabled = true. It runs no
 * dynamic code and no network call, and sends no tactical directive: it just
 * writes one image. bridge/vision.js can analyse an explicitly supplied frame,
 * but this build has no automatic monitor/publisher with camera-side provenance.
 *
 * External capture tools or manual screenshots into vision.capturePath work
 * without ever enabling this loop. */
if (!hasInterface) exitWith {};
if (NeroAI_visionLoopStarted) exitWith {};
NeroAI_visionLoopStarted = true;

[] spawn {
    while {true} do {
        private _interval = (missionNamespace getVariable ["NeroAI_visionCaptureInterval", 15]) max 10;
        if (missionNamespace getVariable ["NeroAI_visionCaptureEnabled", false]) then {
            if (alive player && {!isNull player}) then {
                screenshot "NeroAI_vision.png";
            };
        };
        sleep _interval;
    };
};
