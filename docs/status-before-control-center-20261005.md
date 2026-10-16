# NeroAI Warlords — Mac, RHS 10v10, lobby controls

Updated 2026-10-05, 18:23 Europe/Kiev. Separate from Antistasi. Single Mac
`openai/gpt-oss-20b`, temperature 0.9, output 900 tokens, timeout 60 seconds,
one pending request; optional dual routing is disabled.

## Installed and launched

- Client profile `donko`, shortcut `C:\Users\Admin\Desktop\Warlords - Mac RHS.lnk`.
  No separate server or HC. The player client hosts the multiplayer mission.
- Next/current launch preset: 15 Workshop mods plus NeroAI, 16 total. CBA,
  INIDBI2, RHSUSAF/AFRF/GREF/SAF, CUP Core/Maps/Weapons/Units/Vehicles,
  Australia FIXED, FA18, SU35, Zeus Enhanced. The previous 78-mod preset remains
  in `backups/warlords-launch-full-78.json`. Workshop files were not changed.
- Bridge restarted at 15:22:52 UTC; real Mac completion succeeded before launch.
- Installed addon: `H:\SteamLibrary\steamapps\common\Arma 3\@NeroAI_Warlords\addons\NeroWL.pbo`.
  SHA256 `3DDDE214B9EC5DF5C2942C111EA6FE803B1A0EC3720D8BD80543AB25067DF5AD`;
  69 files, 328853 bytes. Source, dist and installed content matched.
- Main title: **NeroAI Warlords - Australia (Mac RHS 10v10)**.
  Installed at `H:\SteamLibrary\steamapps\common\Arma 3\MPMissions\NeroAI_Warlords_Australia_RHS20.australia.pbo`.
  SHA256 `397DE757E6C8E58E361E9C290FE1999FA747DED51EEB2E8A6D1422C697C8E2F7`;
  nine files, 73745 bytes.
- Four adapted user archive missions are installed under distinct names
  `NeroAI_WL_RHS_Zeus_<Map>.<world>.pbo`. ZIPs/PBOs/source/instructions are in
  `dist/criteria-release`; originals in Downloads were not changed.
- Deployment backups: `backups/rhs20-install-20261005-182249`. Old main and
  HOSTFIX files were moved there to avoid confusing entries.

## Observed incident and runtime evidence

The old JEZ mission required missing `JEZ_Warlords`. Our native mission did not,
but its first PBO was wrongly packed with addon Vers/prefix properties. The
packer now has `-Mission` mode, and description.ext has a full multiplayer Header.
The user confirmed the separate HOSTFIX opened the lobby. Multiple metadata
changes were made together, so the contribution of each was not isolated.

HOSTFIX entered multiplayer at 17:58:28. The user's read-only diagnostic at
18:01:55 found real modules but no sector/base globals yet. At 18:02:08 the shop
validated 21 public classes; four EAST commanders enrolled at 18:02:09. At
18:02:21 the mod logged EAST=4/WEST=3 bots plus player. Mac request
`n3_1433441_502466` was accepted/dispatched as HOLD in the engine at 18:02:25.
Thus initialization eventually completed after approximately 220 seconds.
Native initialization scans loaded mod catalogs; the exact slow stage was not
timed. The early respawn/base errors preceded completion. Reduced-preset load
time and FPS have not been measured.

This proves previous HOSTFIX initialization and correlated dispatch, not physical
movement/purchase/boarding/flight, nor readiness of the new 10v10 mission.

## Current behaviour and pre-game settings

Twenty RHS commander slots, ten per side. Classes `rhsusf_army_ocp_squadleader`
and `rhs_msv_emr_sergeant` were verified in installed troop configs for public
scope, side/faction and RHS uniforms. RHS faction pools and a verified RHS
starter infantry catalog replace vanilla leaders/recruits. Neutral garrisons use
installed RHSGREF `rhsgref_faction_cdf_ng`. Bots default enabled; if all lobby
AI is disabled, the opt-in setup creates ten RHS fallback commanders per side
once, without unlimited spawning. Default subordinates reduced to three.

Native lobby **Parameters** has nine controls: starting CP, sector income,
subordinates, daytime, fast travel, enemy LLM control, air, AI difficulty,
planning aggression. Defaults: 3000 CP, income x2, three subordinates,
LLM/air on, normal skills and balanced plans. Native AI enable remains a lobby
toggle. Native `BIS_WL...` values are read by WLInit; Nero values are validated,
server-applied/published and logged as `[NeroWL Settings] applied`. Difficulty
applies bounded subskills to AI only, including purchases. Aggression is snapshot
data and shared doctrine, not a guarantee of model behaviour. Air off is guarded
in shop, purchase and dispatch. The new readiness worker reports progress every
30 seconds, waits for both bases/sectors and never starts a duplicate native init.

Australia: two bases, eleven capture sectors, seventeen links. New coordinates
come from Names in the installed Australia FIXED config:

| Town | XY |
| --- | --- |
| Perth | 5445, 18695 |
| Willcania | 31302, 16764 |
| Toowoomba | 30955, 19997 |
| Coober Pedy | 22300, 19289 |
| Pine Gap | 19764, 24355 |

Every new town has at least two linked approaches. City capture/ground placement
still needs engine QA. Both bases have air services; actual runway/safe pad is
required for an aircraft purchase.

Shared compact doctrine: native objectives, recon/preparation/attack/consolidation,
urban infantry and armour support, deliberate real CP purchases and asset use,
aviation, known AA avoidance and level terrain. No scripted room clearing is
claimed. Ground route sampling/retries are bounded, no teleporting. AI aircraft
are paid, one living purchased aircraft per side, actual crews and finite fuel/
ammo with sortie/return states. Physical flights and purchases remain unverified.
Host Zeus defaults to Y; Esc provides the hosted debug console; authority survives
respawn. Model output remains allowlisted data, never executed as SQF.

## User archives and validation

The four originals had slots plus an Eden-only builder, no placed native WL
modules, and disabledAI=1. Rebuilt missions include modules, connected graph,
20 RHS slots, controls and a runtime-filtered archive catalog. Missing/wrong-side
classes and unsupported services are skipped. Native initial RHS classes were
verified separately. Australia uses the layout above; Takistan/Altis/Chernarus
use installed map Names/ILS coordinates, two airfield bases and eight sectors.

Passed: seven bridge/protocol tests, five mission/settings tests, three addon
syntax/dynamic-execution smoke checks. All PBO checksums/manifests/content matched;
all four ZIP PBOs matched release hashes. Static checks do not execute SQF.

Primary references: [PBO format](https://community.bistudio.com/wiki/PBO),
[native Warlords parameters and catalog](https://community.bistudio.com/wiki/Arma_3_MP_Warlords).

## Next acceptance gate / continuation

Read the fresh `Arma3_x64_2026-10-05_18-23-06.rpt` and the user's observation.
User was asked to load the exact Mac RHS 10v10 title. Confirm Parameters/20 slots,
settings acknowledgement, readiness duration, 13 hubs/two bases, RHS models,
ten RED commanders and a correlated Mac reply. Then measure actual CP debit,
delivery/seating, an affordable air sortie/return, city capture, blocked vehicle
recovery and FPS. Do not infer movement/capture from dispatch logs. Other map
gameplay remains pending. Preserve source/dist/install/runtime boundaries and
back up before further replacement. No memory files were modified.
