# BECTI Australia: native crash at 04:45:19, 17 October 2026

## Observed

User reported a crash about a minute after arriving at the base, while standing or moving, without intentionally opening a menu. The crashed client was PID 8032, Arma 2.22.154089, mission `WarArchitect_BECTI_Australia_8869c97b3467.australia`. Its RPT recorded successful WEST placement on land, client ready, and adapter start before the engine crashed. Native save loading and missing EAST T80 catalog classes also occurred; these are separate observations, not demonstrated causes of this crash.

WinDbg read the corresponding `Arma3_x64_2026-10-17_04-01-42.mdmp`: access violation C0000005, reading address zero at `Arma3_x64.exe + 0x14319BA`. Its stack and context were retained in `dist/candidate/becti-crash-20261017/debugger-{stack,context}.log`. The original dump/RPT were no longer present at their original location after the user's next game launch; the retained analysis is not a replacement for the original dump.

The faulting instruction reads an event-list element through a null array pointer. The current event string is `KeyDown` (r13 = 0x1D368830), and rdi's vtable is 0x7FF698C45D10 with module base 0x7FF6970B0000. Reading the executable's MSVC RTTI at vtable RVA 0x1B95D10, complete-object locator RVA 0x1E0E178, type descriptor RVA 0x2141070 yields `.?AVDisplayInsertMarker@@`. Export-based function names in WinDbg are not reliable function identification and are not used as proof.

This identifies marker-dialog keyboard dispatch as the crash location. It does not establish which user input or mod opened that dialog. The user's report that no menu was intentionally opened remains an unresolved part of the trigger.

## Bounded correction

The upstream `Addons/MapMarkersTitling.sqf` clears every KeyDown and KeyUp handler on the marker display from inside its own KeyDown (Escape) / KeyUp (Enter) callback. That is a concrete event lifecycle defect consistent with the crash context. It also locks all user input while a scheduled busy loop searches for the dialog.

The adapter now supplies `tools/becti-assets/map-marker-titling.sqf` in that file's place. It waits with uiSleep for the native marker display, attaches its own handler once per display, prefixes the marker text once on Enter, and returns false so native input continues. It neither clears event lists nor closes the display nor locks user input. Display destruction owns handler cleanup. Other add-ons' keyboard handlers remain registered. The original upstream checkout is unchanged.

The helper is included in the mission content digest. Validation rejects the legacy clear-all/input-lock implementation, and the modified file is included in SQF parsing.

## Checks and installed candidate

- All 4 tests in `tests/shop-becti.test.js` pass, including rejecting the exact upstream marker script.
- Candidate validation passes; SQF-VM parses 45 affected SQF files. These are source checks, not native UI execution.
- Five spawn/client-init/AI runtime files compare byte-for-byte equal to the previous candidate.
- Packed mission: 558 files; source content and installed SHA256 verified.
- Installed separately: `H:\SteamLibrary\steamapps\common\Arma 3\MPMissions\WarArchitect_BECTI_Australia_08accab11dbc.australia.pbo`.
- Display name: **War Architect — BECTI Australia · исправление вылета**.
- SHA256: `E8DC089BF5EB90412A41E5C9C103249005BB498C4A74131008AD0CE8AADD1574`.
- Saved scenario ID: `01cb84d7-3378-4eaf-bf97-bae6805c285a`. Army selections and mission settings come from the previous spawn-fix scenario.

The running user game was not stopped or modified; existing mission packages were preserved. No native client stability claim is made yet. Acceptance: load this named candidate, remain/move at the base for at least 3–5 minutes, then test creating/cancelling map markers with Enter/Escape. A surviving session and fresh RPT are needed to confirm the crash fix; if it recurs, correlate the new native dump before changing unrelated AI/mod settings.
