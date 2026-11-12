# Implementation Plan: Architecture Alignment

**Branch**: `002-shared-db` (no branch of its own, spec Q1) | **Date**: 2026-11-06 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/008-architecture-alignment/spec.md`

## Summary

This plan aligns the rebased `002-shared-db` code with its layered architecture before release 1.2.0.

- **Game data**: the game data spread through the logic files becomes one model, `ns.GameData`, with one file per
  entity, data only, loaded first after the locales and enforced by `npm run check`.
- **Lures**: a known lure above the character's Fishing skill is no longer offered, using the requirements from the
  original game, marked V43 and V44.
- **Map pin**: the catalog's map pin goes through `ns.MapPin`. The parent-map fallback moves into `MapPin.Target`.
- **Code**: dead code goes, test-only names move into private tables, seven duplicates are merged, and `Comm.lua`
  and `Views.lua` are split along their seams.
- **Tests**: tests are renamed and moved to their areas.
- **Documents**: the living documents are corrected item by item. Spec 001 gets a `verification.md`. The facts the
  1.1.0 runs confirmed are recorded and their markers closed.
- **In game**: the checklists' affected steps are unticked to run again.

## Technical Context

**Language/Version**: Lua 5.1 (the WoW Forever client, Interface 16001), tests in fengari (Lua 5.3); Node.js 18+
for the tools

**Primary Dependencies**: the WoW Mainline API as shipped in Forever 1.60.1; no libraries

**Storage**: `OneKeyFishingDB` / `OneKeyFishingCharDB`. No saved field changes, so no `DB_SCHEMA` bump. The range
step and the number of ranges keep their values (research R14).

**Testing**: `npm test` (`tests/run.mjs`: every `*_test.lua` after `tests/wow.lua`, then `*_test.mjs`);
`npm run check` (`tools/check.mjs`)

**Target Platform**: WoW Forever client (Windows / macOS)

**Project Type**: game addon (single package `OneKeyFishing/`) with Node tooling

**Performance Goals**: unchanged; the moves add no runtime work (tables are read as before, one more field per
lure)

**Constraints**:
- Blizzard's Add-On Policy: no new automatic action. The lure choice only narrows what the key offers.
- Lua 5.1/5.3 neutral.
- ASCII outside the `GameData/` string literals.
- Lines of 120 characters or less.
- The TOC order is the load order.

**Scale/Scope**:
- about 45 addon files and 95 test files;
- 9 new GameData files and 2 new module files (`Exchange/CommReceive.lua`, `CatchDB/Index.lua`);
- about 30 test renames and moves;
- about 20 document fixes.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | How the plan meets it | Result |
|---|---|---|
| I. Blizzard Policy | No new action; `FindLure` only skips a lure, every use stays on a key press through the secure button | Pass |
| II. Language-Independent Game Data | All game data by ID in `GameData/`; the lure requirement by ID, not parsed from the tooltip; no new visible text, except the changelog and manual sentence (English docs); the debug report line is not localized | Pass |
| III. Safe, Restorable State | No saved field and no restore path changes; gear and CVar code only reads its tables from `GameData` | Pass |
| IV. Verified Forever API | The requirements are V43 and V44 with a `verification.md`; facts the game already showed go to `docs/forever-api.md`; V7 closed on the author's 1.1.0 reports; no new API global | Pass |
| V. Checked and Tested Changes | Each logic change gets a test that fails without it (lure skill, pin fallback, merged duplicates, the GameData check); the renamed tests keep their cases | Pass |
| VI. Simple Module Boundaries | `GameData/` becomes a full area (folder, document, tests); the splits stay inside their modules through private tables; no new message; the commands do not change | Pass |
| Technical Constraints | `GameData/` keeps the UTF-8 exception for strings only; the TOC lists the new files | Pass |
| Development Workflow | `CHANGELOG.md` and `OneKeyFishing/README.md` get the lure line in the same commit; CLAUDE.md and the architecture pages are updated; the constitution gets a PATCH (1.5.2) through `/speckit-constitution` | Pass |

Re-check after Phase 1: still passes.
- The new check rules (data-only `GameData/`, private tables per module, test names) strengthen Principle VI.
- `ns.earlyLookups` in the debug report touches only the unlocalized report.

## Project Structure

### Documentation (this feature)

```text
specs/008-architecture-alignment/
├── spec.md              # the specification and the quiz decisions
├── plan.md              # this file
├── research.md          # R1-R14: the decisions, with the audit's findings
├── data-model.md        # ns.GameData, the private tables, the functions that change
├── contracts/
│   └── interfaces.md    # GameData, MapPin, FindLure, private tables, test layout
├── verification.md      # V43, V44
├── quickstart.md        # what the tests prove and the in-game steps
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
OneKeyFishing/
├── OneKeyFishing.toc        # GameData\*.lua right after the locales; Exchange\CommReceive.lua; CatchDB\Index.lua
├── GameData/                # layer 0, data only (data-model.md)
│   ├── FishingSpells.lua    # new
│   ├── FishingRanks.lua     # ns.GameData.FishingRanks; NpcNames moves out
│   ├── NpcNames.lua         # new (from FishingRanks.lua)
│   ├── Bobber.lua           # new
│   ├── Lures.lua            # new, with skill (V43, V44)
│   ├── FishedContainers.lua # new
│   ├── FishingPoles.lua     # new
│   ├── EquipSlots.lua       # new
│   └── Icons.lua            # new
├── Core/Data.lua            # spell IDs and bobber ID removed; reads GameData; no FISHING_SKILL_LINE
├── Core/MapPin.lua          # Target gains the parent map fallback (V33)
├── Core/Debug.lua           # CVars from Mode.CVAR_NAMES; the early lookups
├── Fishing/Bags.lua         # lures and containers from GameData; the skill rule
├── Fishing/Gear.lua         # poles, slots, class from GameData
├── Fishing/Mode.lua         # Mode.CVAR_NAMES
├── Fishing/Skill.lua        # spells and ranks from GameData; fallback names by rank order
├── Catch/Catch.lua          # bobber from GameData
├── CatchDB/CatchDB.lua      # range step derived from GameData; OwnRecord(store); private OwnProofReady
├── CatchDB/Checks.lua       # private STEP_SECONDS
├── CatchDB/Index.lua        # new: the indexes from Views.lua
├── CatchDB/Views.lua        # views only; LITTLE_DATA exported
├── Exchange/Comm.lua        # Comm.private; send side
├── Exchange/CommReceive.lua # new: the receive side
├── Exchange/Share.lua       # CatchDB.OwnRecord, CatchDB.LITTLE_DATA
├── Catalog/Catalog.lua      # PinTarget removed; DefaultFilter()
├── UI/Widgets.lua           # ns.RangeLabel, ns.UpdateScanButton
├── UI/CatalogTab.lua        # Pin through MapPin.Set; shared label and filter
├── UI/CatchHere.lua         # shared label; icon from GameData
├── UI/StatsFrame.lua, UI/Settings.lua, UI/Indicator.lua, UI/Minimap.lua   # GameData reads; shared scan button; no ns.Minimap
tools/check.mjs, tools/addon.mjs   # GameData data-only rule; private tables; test names
tests/
├── gamedata/                # new: shape_test.lua, load_order_test.lua
├── fishing/lure_skill_test.lua   # new
├── core/pin_target_test.lua, core/pin_set_test.lua   # from mappin_test + catalog/pin_test
├── catalog/spot_pin_test.lua     # the catalog's own pin rules
├── tools/gamedata_check_test.mjs # new
└── (renames and moves, research R10)
```

**Structure Decision**: The structure stays as it is: one addon folder with one subfolder per area, and tests
grouped the same way. `GameData/` becomes a full area beside them. The two new module files sit in the folders of
the modules they belong to.

## Implementation order

Each step leaves `npm run check` and `npm test` green.

1. **GameData model** (US1): the nine files, the TOC move, the readers switched. The old names are removed in the
   same step, so no alias remains. Add `tests/gamedata/`.
2. **The `npm run check` rules**:
   - C1 (data-only `GameData/`, with `tests/tools/gamedata_check_test.mjs`) comes right after the model. Before the
     move, today's `FishingRanks.lua` would fail it.
   - C4 (private tables) comes with the private tables.
   - C5 (test names) comes after the renames, three of which the analysis added (research R10).
3. **Lure skill** (US2): `FindLure`, `DescribeLures`, `tests/fishing/lure_skill_test.lua` (it fails before the
   change). Then the CHANGELOG and manual line, and the tech-debt item removed.
4. **One map pin** (US3): `MapPin.Target` fallback; Catalog and CatalogTab switched; tests merged and moved; V32
   closed.
5. **Dead code and private tables** (US4, R7): the removals, `Comm.private`, the moved test seams, the early
   lookups in the debug report.
6. **Duplicates** (US4, R8), one at a time, each with its test. The own record lookup gets a damaged-record test.
7. **Splits** (US4, R9): `CatchDB/Index.lua`, then `Exchange/CommReceive.lua`, each a pure move with the TOC line.
8. **Test renames and moves** (R10), with `git mv` and the header lines.
9. **VERIFY bookkeeping** (R11): spec 001's `verification.md`, V7 closed, partial results recorded,
   `docs/forever-api.md`.
10. **Documents** (R12), item by item; the constitution PATCH through `/speckit-constitution`.
11. **Checklists** (R13): untick, the new expectation of "Lure too high", the catalog pin expectations.
12. **Final audit**: rerun the dead code and duplicate search and the stale-path search (quickstart steps 1 to 3).

## Complexity Tracking

No constitution violation to justify.
