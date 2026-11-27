# Implementation Plan: Fishing Gear Waits for the Game's Swap

**Branch**: `030-gear-in-flight` | **Date**: 2026-11-27 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/030-gear-in-flight/spec.md`

## Summary

Fishing mode's gear swap judges a slot by what the game shows in it at once, but the server answers a swap 150 to
250 ms later ([research.md](research.md) R3, R4). A restore taken in that window forgets the records and leaves the
pole in hand and the weapons in the bags for good (B1); an equip taken in it leaves fishing mode on without the pole
(B2). The fix: `Fishing/Gear.lua` marks every slot it asks the game to swap as waiting until that slot's
`PLAYER_EQUIPMENT_CHANGED` (5 s at most), queues an equip or a restore asked for while a slot waits, and runs the
last one asked for on the frame after the last answer. `Fishing/Mode.lua` does not enter fishing mode when a
two-handed pole would push an off-hand item into full bags (B3). Nothing saved changes shape.

## Technical Context

**Language/Version**: Lua 5.1 (WoW Forever client 1.60.1, Interface 16001); tests in fengari (Lua 5.3)

**Primary Dependencies**: the WoW API (`C_Item.EquipItemByName`, `GetInventoryItemID` / `Link`,
`C_Container.GetContainerNumFreeSlots`, `C_Timer.After`, `PLAYER_EQUIPMENT_CHANGED`); no library

**Storage**: `OneKeyFishingCharDB.gearSwap` unchanged; the waiting slots and the queued action live in memory only

**Testing**: `npm test` (fengari, `tests/wow.lua` stubs), `npm run check` (luacheck, layers, locales, docs)

**Target Platform**: WoW Forever (Mainline API), Windows and macOS clients

**Project Type**: game add-on (single folder `OneKeyFishing/`)

**Performance Goals**: none new: one table write per swap, one timer per swap, one per answer

**Constraints**: no new saved field (FR-006); equipping only out of combat lockdown (constitution III); every game
action on a key press (constitution I: equipping is not one); paths that work today unchanged (FR-007)

**Scale/Scope**: at most 19 equipment slots; one module changed (`Fishing/Gear.lua`), one call added in
`Fishing/Mode.lua`, one debug line, one translated text

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
|---|---|---|
| I. Policy | Principle I (1.5.5): fishing mode's gear swap starts and ends on a key press or by Principle III and may finish after the game's answer to an earlier swap (or the wait for that answer ran out). The fix starts no swap of its own: a queued equip or restore finishes the one the player's toggle press (or a fight's exit) started. Nothing reacts to the bobber or a catch. `EquipItemByName` is not protected out of combat | Pass |
| II. Language-independent data | Slots and items by ID; the equip location by `GetItemInfoInstant`; the one new text through `ns.L` with its nine translations, the item link outside the string | Pass |
| III. Safe, restorable state | The records are still written before the swap; a waiting restore never drops them (the fix of B1); combat and cast waits unchanged; no `DB_SCHEMA` change as no saved field changes | Pass |
| IV. Verified Forever API | Every fact the code relies on was seen in game on 2026-11-27 (research R3) and is in `docs/forever-api.md`; no new API global (all already in `.luacheckrc`); in-game checklist after the build | Pass |
| V. Checked and tested | New `tests/fishing/gear_in_flight_test.lua`: B1, B2, B3 fail on 1.7.1; `gear_combat_test.lua` and `gear_pole_test.lua` unchanged | Pass |
| VI. Simple boundaries | All in `Fishing/Gear.lua` (layer 1); Mode (same folder) asks `Gear.HasRoomForPole()`; `Core/Debug.lua` reads one Gear function; no message, no frame, no setting | Pass |

**Post-design re-check (after Phase 1)**: unchanged, all pass. No complexity to justify.

## Project Structure

### Documentation (this feature)

```text
specs/030-gear-in-flight/
├── spec.md              # the fix spec
├── plan.md              # this file
├── research.md          # Phase 0: the report, the client export, the spike, the decisions D1-D8
├── data-model.md        # Phase 1: the waiting slots, the queued action, their transitions
├── contracts/gear.md    # Phase 1: what Gear and Mode promise after the fix
├── quickstart.md        # Phase 1: what the tests prove, the in-game steps
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
OneKeyFishing/
├── Fishing/Gear.lua     # waiting slots, queued action, Ask(), HasRoomForPole(), DebugState()
├── Fishing/Mode.lua     # Enter: the room check before anything is enabled
├── Core/Debug.lua       # Gear section: the waiting slots and the queued action
└── Locales/*.lua        # one new text, ten files
tests/
├── wow.lua              # header lines for the new helpers only if shared (else in the test file)
└── fishing/gear_in_flight_test.lua   # new
docs/
├── architecture/fishing-mode.md      # Fishing/Gear.lua: the wait for the game's answer
├── checklists/gear-swap.md           # new in-game checklist (spike steps 2-9 with the logger)
└── checklists/README.md              # its row
CHANGELOG.md, OneKeyFishing/README.md # the fix and the full-bags rule
```

**Structure Decision**: the existing layout; the change stays inside the Fishing area (layer 1) plus its debug line
and texts. No new module, folder, message or setting.

## Complexity Tracking

No violation.
