# Implementation Plan: Catch Place Fixes

**Branch**: `002-shared-db` (no branch of its own; the feature folder is `specs/011-catch-place-fixes`) |
**Date**: 2026-11-08 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/011-catch-place-fixes/spec.md`

## Summary

Tech-debt batch 2 (where a catch is recorded), batch 6 (the error in a fight) and the pole item of batch 5, built
on `002-shared-db` for release 1.2.0, before the first harvest:

- **A fight (R1)**: `NonEmpty` treats a secret value as missing; the skill check skips a fight and runs again on
  `PLAYER_REGEN_ENABLED`.
- **Caves (R2)**: `CatchDB.GetCurrentPlace` turns a continent map into the zone under the player's point
  (`C_Map.GetMapInfoAtPosition`, confirmed in game); no zone, no place.
- **Subzones (R3)**: the area is found by `GetSubZoneText()` among `C_Map.GetAreaInfo` names (confirmed in game),
  walked over frames once per subzone and cached; the explored-region search and the spike's Areas section go.
- **Pools (R4)**: the source of a catch is not known; no pool part is written; the record format, checks and filter
  stay.
- **The pole (R5)**: `Gear.FindBestPole` passes over a pole above the Fishing skill.
- **Documents and the 1.2.0 test page** follow (FR-018, FR-019).

## Technical Context

**Language/Version**: Lua 5.1 (the WoW Forever client, Interface 16001), tests in fengari (Lua 5.3); Node.js 18+
for the tools

**Primary Dependencies**: the WoW Mainline API as shipped in Forever 1.60.1; no libraries

**Storage**: no saved field changes shape: no `DB_SCHEMA` bump, no migration; old data stays (quiz)

**Testing**:
- `npm test` and `npm run check`.
- Stubs in `tests/wow.lua`: `in_combat`, `secret_values`, `map_types`, `player_map_position`, `sub_zone`,
  `area_names` exist. New: `map_at_position[mapID]` for `C_Map.GetMapInfoAtPosition` and a per-map
  `player_map_positions[mapID]` (the position on the zone differs from the one on the continent).
- The frame-step walk runs through the `C_Timer.After` stub's queue.

**Target Platform**: WoW Forever client (Windows / macOS)

**Project Type**: game addon (single package `OneKeyFishing/`) with Node tooling

**Performance Goals**: no frame step spends more than about 1 ms on the area walk (2000 IDs at about 0.25 us
each, measured 4.5 ms per 20000); at most a few walks per session

**Constraints**:
- Blizzard's Add-On Policy: no new automatic action (the skill check and the walk only read).
- Principle II: game data by ID; the subzone match uses the client's own text, folded.
- Layers: `CatchDB` (2) reads `ns.Skill` (1) as today; `Gear` (1) reads `ns.Skill` (1) at runtime.
- ASCII outside the locales, 120-character lines, Lua 5.1/5.3 neutral. No new visible text, so no new keys.

**Scale/Scope**:
- Addon files: `Fishing/Skill.lua`, `Fishing/Gear.lua`, `CatchDB/CatchDB.lua`, `CatchDB/Events.lua`,
  `CatchDB/Views.lua`, `Catch/Catch.lua`, `Core/Spike.lua`.
- Tests: three new files, `area_test.lua` rewritten, the catch, catalog and spike tests adjusted; `tests/wow.lua`.
- Documents: as in research R6.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
|---|---|---|
| I. Blizzard Policy | No cast, hook or item use is added; the area walk and the skill check only read the API | Pass |
| II. Language-Independent Game Data | The area is stored by ID; the needle is the client's own `GetSubZoneText()`, compared folded against the client's own `GetAreaInfo` names; maps by ID | Pass |
| III. Safe, Restorable State | Nothing fishing mode changes is touched; no saved field changes | Pass |
| IV. Verified Forever API | `GetMapInfoAtPosition` on the continent and the area names were checked by `/run` (2026-11-08, `docs/forever-api.md`); the position on the zone inside the cave too (x 0.461); V34's and V3's markers go with the code they guarded | Pass |
| V. Checked and Tested Changes | A test per fix that fails without it; `npm run check` and `npm test` | Pass |
| VI. Simple Module Boundaries | Changes stay inside `CatchDB`, `Fishing` and `Catch`; no new message; tests read `CatchDB.private` only from tests | Pass |

Re-check after Phase 1: the contracts add one function (`CatchDB.LookupArea`) and remove one (`CatchDB.GetArea`);
no layer rule changes. Pass.

## Project Structure

### Documentation (this feature)

```text
specs/011-catch-place-fixes/
├── plan.md              # This file
├── research.md          # Phase 0
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1
├── contracts/
│   └── module-api.md    # Phase 1
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
OneKeyFishing/
├── Fishing/Skill.lua        # R1: NonEmpty guard, fight skip, PLAYER_REGEN_ENABLED
├── Fishing/Gear.lua         # R5: FindBestPole by skill
├── CatchDB/CatchDB.lua      # R2: GetCurrentPlace on a continent; R3: LookupArea
├── CatchDB/Events.lua       # R3: the cast's area through LookupArea
├── CatchDB/Views.lua        # R4: the pool debug line goes
├── Catch/Catch.lua          # R4: no pool source
└── Core/Spike.lua           # R3: the Areas section goes
tests/
├── wow.lua                  # map_at_position, player_map_positions
├── fishing/                 # skill_secret_test.lua, gear_pole_test.lua
├── catchdb/                 # cave_test.lua, area_test.lua
└── ui/spike_test.lua
```

**Structure Decision**: the existing addon layout; each change lives in the module that owns the data (layers of
CLAUDE.md).

## Complexity Tracking

No violation to justify.
