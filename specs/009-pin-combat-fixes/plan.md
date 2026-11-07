# Implementation Plan: Pin and Combat Fixes

**Branch**: `002-shared-db` (no branch of its own; the setup script names `009-pin-combat-fixes` from the feature
folder) | **Date**: 2026-11-07 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/009-pin-combat-fixes/spec.md`

## Summary

Batches 3 and 4 of `docs/tech-debt.md`, built on `002-shared-db` for release 1.2.0.

- **Map pin**: `MapPin.Set` no longer opens the world map (the fallback of R14 / V32). The pin and the tracking stay.
  The toast gets a new text that names the place and says to open the map (nine translations). The manual stops
  promising an arrow on screen (V31).
- **Gear in a fight**: `Fishing/Gear.lua` never calls `C_Item.EquipItemByName` (or unequips) while
  `InCombatLockdown()` is true. A restore asked for in the lockdown is remembered and done when the fight ends. Only
  the `PLAYER_REGEN_DISABLED` handler, which runs before the lockdown, still swaps the weapons (research R2).
  `Mode.Exit` in the lockdown sets the pending exit without touching the gear. Mode's own `restoreAfterCombat` flag
  goes, because Gear now keeps that state (R3).
- **Attack line**: the `PLAYER_REGEN_DISABLED` handler prints "Leaving fishing mode after combat." once. It shares
  the key hint's 5-second pause (R4).
- **Fishing key in a fight**: the cause is found in the client's own code (R1). The state driver turns the state
  `"1"` into the number `1`, so the handler's `newstate == "1"` is never true and the overrides are never cleared.
  The fix compares the number. The author's `/run` check stays as the first step of the in-game checklist, and the
  marker V45 stays until then.
- **Documents**: changelog, manual, specs 001 and 005, the verification rows, `forever-api.md`, `CLAUDE.md`, the
  architecture pages, `tech-debt.md`, `release-plan.md`, the checklists and the author's 1.2.0 test page (FR-013,
  FR-014). Batches 1 and 2, planned as "spec 009", move to spec 010.

## Technical Context

**Language/Version**: Lua 5.1 (the WoW Forever client, Interface 16001), tests in fengari (Lua 5.3); Node.js 18+
for the tools

**Primary Dependencies**: the WoW Mainline API as shipped in Forever 1.60.1; the client's secure handler code
(`Blizzard_RestrictedAddOnEnvironment`, read in the local export, build 70685); no libraries

**Storage**: `OneKeyFishingCharDB.gearSwap` keeps its shape. No saved field is added, renamed or reshaped, so no
`DB_SCHEMA` bump. The after-combat restore flag is session state (R3).

**Testing**: `npm test` (`tests/run.mjs`); `npm run check` (`tools/check.mjs`). The new tests need these stubs in
`tests/wow.lua` (data-model.md "Test stubs"):
- `C_Item.EquipItemByName` and `GetInventoryItemID` recorders;
- frame attributes;
- override binding recorders.

**Target Platform**: WoW Forever client (Windows / macOS)

**Project Type**: game addon (single package `OneKeyFishing/`) with Node tooling

**Performance Goals**: unchanged (one less map open, one chat line per fight)

**Constraints**:
- Blizzard's Add-On Policy: nothing new acts by itself. The attack line is a chat print. The gear restore after a
  fight already exists and only changes its trigger.
- Lua 5.1/5.3 neutral. The secure snippet runs in the game's restricted environment, which has `tonumber`.
- ASCII; lines of 120 characters or less; nine translations for the new toast text in the same change.

**Scale/Scope**:
- 5 module files: `Core/MapPin.lua`, `UI/Toast.lua`, `Fishing/Gear.lua`, `Fishing/Mode.lua`, `Fishing/Action.lua`;
  plus the 10 `Locales/*.lua` files (one key replaced) and `.luacheckrc`.
- 3 new test files, 2 changed test files, stub additions in `tests/wow.lua`.
- About 15 documents, and the author's 1.2.0 test page (claude.ai artifact).

**Order of work** (the author): implement and fix first, then the in-game check. The in-game steps cover only what
this fix changes; what the author already confirmed is cited (spec FR-014).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | How the plan meets it | Result |
|---|---|---|
| I. Blizzard Policy | No new action and nothing new acts by itself. The fight now clears the overrides as designed, so the key does less, not more. The attack line is a print. The map is no longer opened for the player | Pass |
| II. Language-Independent Game Data | The new toast text goes through `ns.L` with a literal key and nine translations. The replaced key goes from all locales. No game data by name | Pass |
| III. Safe, Restorable State | This is the fix the 1.5.3 text asks for: no protected change in the lockdown, the weapons only before it, everything after the fight. `gearSwap` is still written before a change and kept until the swap lands. Only what the addon changed is restored | Pass |
| IV. Verified Forever API | Uses only facts from `docs/forever-api.md` "Verified in game" and the client's own secure code. R14 stays until section 10 is re-checked. V45 (the key) gets a `verification.md` row and a marker until the author confirms. No new API global: `GetInventoryItemID` and the others are already in `.luacheckrc` | Pass |
| V. Checked and Tested Changes | One test per fix. Each test fails without its fix (quickstart.md lists them). The stubs grow in `tests/wow.lua` | Pass |
| VI. Simple Module Boundaries | No new module, message, setting or command. The after-combat restore moves into Gear, the module that owns the gear (one owner instead of two). Toast stays in `UI/`, MapPin stays in Core | Pass |
| Technical Constraints | Locales keep their UTF-8 exception; nothing else changes | Pass |
| Development Workflow | `CHANGELOG.md` `[Unreleased]` "Fixed" and the manual in the same commit; `CLAUDE.md` (Forever API part, the MapPin row) and `docs/architecture/` are updated; nothing leaves `docs/ROADMAP.md` | Pass |

Re-check after Phase 1: still passes. The gear contract (contracts/combat.md) makes Principle III's lockdown rule a
tested invariant ("no equip call while the lockdown is on").

## Project Structure

### Documentation (this feature)

```text
specs/009-pin-combat-fixes/
├── plan.md              # This file
├── research.md          # Phase 0: R1-R6
├── data-model.md        # Phase 1: the session state, the texts, the test stubs
├── quickstart.md        # Phase 1: what the tests prove, the in-game steps
├── verification.md      # V45 (the fishing key's cause, confirmed in game later)
├── contracts/
│   ├── map-pin.md       # MapPin.Set and the toast
│   └── combat.md        # Gear, Mode and Action in a fight
├── checklists/
│   └── requirements.md  # spec quality (from /speckit-specify)
└── tasks.md             # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

```text
OneKeyFishing/
├── Core/MapPin.lua          # Set: no OpenWorldMap; R14 marker moved to the new assumption
├── UI/Toast.lua             # MAP_PIN_SET: the new text
├── Locales/*.lua            # "Map pin: %s" replaced by the new key, in enUS and nine translations
├── Fishing/Gear.lua         # RestoreSlots: nothing in the lockdown, remembered for PLAYER_REGEN_ENABLED
├── Fishing/Mode.lua         # Exit in the lockdown: pending only; the attack line; restoreAfterCombat removed
├── Fishing/Action.lua       # _onstate-combat: tonumber(newstate) == 1 (VERIFY(V45))
└── README.md                # the pin (map, minimap arrow, on-screen arrow), "Safe in combat"

tests/
├── wow.lua                  # stubs: equips, inventory, frame attributes, override bindings
├── core/pin_set_test.lua    # extended: no map opened, in or out of a fight; the new toast text
└── fishing/
    ├── gear_combat_test.lua # no equip in the lockdown on every path; restored after the fight
    ├── mode_combat_test.lua # Exit in the lockdown; the attack line once; the hint pause
    └── key_combat_test.lua  # the combat snippet clears the overrides for the state the driver sends (number 1)
```

**Structure Decision**: the fix stays in the modules that own each behaviour. These are `Core/MapPin.lua` and
`UI/Toast.lua` for the pin; `Fishing/Gear.lua`, `Fishing/Mode.lua` and `Fishing/Action.lua` for the fight. The new
tests go into `tests/fishing/`, the area of `docs/architecture/fishing-mode.md`, and `tests/core/` for the pin.
That follows the naming of `docs/development.md`.

## Complexity Tracking

No violations.
