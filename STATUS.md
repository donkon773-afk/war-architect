# Historical NeroAI Warlords notes

Current installed build and acceptance gates: [CURRENT_STATUS.md](CURRENT_STATUS.md).
The model assignments, hashes and pending-install statements below are historical.

Created 2026-10-05 as an isolated Warlords package. The live Antistasi game and
bridge were not switched. Source was copied from Warlords 4.7; the old tree was
left unchanged. Native game functions in `research/native` are read-only
evidence and excluded from the PBO.

## Launch

Desktop shortcut: `C:\Users\Admin\Desktop\Warlords - 2 LLM.lnk`.
It starts `tools/start-warlords.ps1` through an ASCII-only wrapper, because the
Windows shortcut COM mangled the Cyrillic project path. Start requires all Arma
processes to be closed. It checks both LM Studio completions, starts the bridge,
then runs Arma through Steam and BattlEye with profile `donko`, 77 base mods and
`@NeroAI_Warlords` as mod 78.

Select an actual **Warlords mission** on an installed map. A bare terrain or an
Antistasi mission has no Warlords sectors, CP or shop; the addon stays inactive
when the Warlords mission API is absent.

## Roles and economy

- MacBook `google/gemma-4-26b-a4b-qat`: short strategy, refreshed no more than
  once per enemy side per 120 seconds in a bridge session.
- RTX 3070 `nvidia/nemotron-3-nano-4b`: each admitted tactical plan with the Mac
  intent supplied as data. One pending bridge plan at a time. The player's own
  groups are not automatically enrolled.
- Opponent groups with a native warlord purse spend their own `BIS_WL_funds`
  through the mission `BIS_WL_purchasable` list and physical `BIS_fnc_WLAirdrop`.
  There is no scripted CP top-up or free starter vehicle.
- Supported purchases: infantry, ground cars, APCs, tanks and trucks. Groups
  without a warlord purse cannot buy. Aircraft, naval and static assets are not
  purchased by this dispatcher; their native paths use player UI or separate
  delivery handlers.
- Owned vehicles are prioritized for boarding, including partly occupied ones
  with free seats. The boarding routine reports physical seat occupancy. An
  autonomous march waits for an owned empty vehicle.
- Autonomous movement stays near the native Warlords current sector. The addon
  does not replace sector voting or the mission's waypoints.

## Isolation and checks

- PBO prefix `NeroWL`; queues `NeroWL_out.ini` and `NeroWL_in.ini`.
- Installed file: `H:\SteamLibrary\steamapps\common\Arma 3\@NeroAI_Warlords\addons\NeroWL.pbo`.
- SHA-256: `74A6D330BB9C69088EA2B5FBBAECC38F625D783D81A7A812880816B4CA5755EB`.
- PBO 64/64 source files verified, contents and manifest match. No Workshop
  package changed. Both real models returned completions; one live two-model
  chain returned a validated action object. Focused tests: 4/4. The launcher
  dry run passed and refused to start while Antistasi was running.

**Still unverified in the Arma engine:** Warlords initialization, a CP deduction
and physical delivery, seated crew, native objective continuity, FPS, and
acceptance of the local unsigned PBO on a particular multiplayer server. These
require a fresh Warlords game session. PBO/test/model success is not gameplay
proof.

## 2026-10-05 live Takistan check

The Steam client loaded `WARLORDS TAKISTAN` on Takistan with `@NeroAI_Warlords`.
The player reported that Warlords sectors, CP and the request menu appeared
after the first death/respawn, but no RED AI commanders were present. The RPT
recorded the old one-shot 90-second API timeout before that respawn. It also
recorded native Warlords `_base`/`_sector` errors while the mission was still
coming up. No Warlords AI purchase or physical boarding was observed. The player
did not confirm that AI was enabled in the host lobby; disabled AI removes
unoccupied playable RED slots from `playableUnits`.

Source fix: wait for the actual Warlords API for the lifetime of the mission and
log the missing readiness components every 90 seconds. Focused tests: 5/5.
Rebuilt and verified candidate SHA-256:
`2059178B99A8CCFF909116852D12B0D44C7EBA5554AC6BA9E4A7C81CDCA3FD53`.
The old PBO remains installed while Arma is running. Next: after the player
closes Arma, install the candidate, restart, enable AI in the lobby, and verify
RED enrollment, Mac/RTX dispatch, CP deduction, delivery and seating in RPT.

Copied 4.7 tests remain in `tests/` for reference but are not the active suite:
they assert the old package name, free CP/asset behaviour and single-model
routing. `npm run test:legacy` is expected to fail until rewritten.
