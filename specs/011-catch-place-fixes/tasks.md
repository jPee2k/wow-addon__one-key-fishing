---

description: "Task list for spec 011, catch place fixes"
---

# Tasks: Catch Place Fixes

**Input**: Design documents from `specs/011-catch-place-fixes/`

**Prerequisites**:
- [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md)
- [contracts/module-api.md](contracts/module-api.md), [quickstart.md](quickstart.md)

**Tests**: required. Spec FR-017 and constitution Principle V ask for a test that fails without its fix. Each test
is written first, and its failure is seen before the fix.

**Organization**: grouped by the user stories of spec.md (US1 to US5). Work on `002-shared-db`; commit only when the
author asks.

**Rules for every task** (CLAUDE.md):
- `npm run check` and `npm test` pass after it; a test written before its fix is the only allowed red.
- Addon Lua: ASCII outside `Locales/`, 120-character lines, Lua 5.1/5.3 neutral.
- No Cyrillic in Markdown.
- Write files with LF line endings (`.gitattributes` `eol=lf`). In Python, open with `newline=''` or write bytes.
- No new file in the addon and no TOC change, so a `/reload` is enough in game. No new visible text, so no new
  locale keys.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: the user story of spec.md (US1 to US5)

---

## Phase 1: Setup

- [X] T001 Run `npm run check` and `npm test` from the repository root. Note the marker count and the test count for
  the hand-over.

---

## Phase 2: Foundational (test stubs)

**Purpose**: the stubs US2 and US3 need (plan "Testing").

- [X] T002 In `tests/wow.lua`:
  - **`map_at_position[mapID]`** = `{ mapID = <zone>, mapType = <n> }` or nil: `C_Map.GetMapInfoAtPosition(mapID, x,
    y)` returns `{ mapID = ..., name = map_names[...] or "Test Zone", mapType = ... }` from it (ignoring x, y), nil
    without an entry. Add it to the header list and to `NIL_GAME_DATA`; since it then reads nil when a test does not
    set it, the stub guards it (`map_at_position and map_at_position[mapID]`).
  - **`player_map_positions[mapID]`** = `{ x, y }`: `C_Map.GetPlayerMapPosition(mapID, "player")` returns this
    position when the map has an entry, else `player_map_position` as today. Add it to the header list and to
    `NIL_GAME_DATA`, guarded the same way (`player_map_positions and player_map_positions[mapID]`).
  - Run `npm test`: everything passes (nothing reads the new stubs yet).

---

## Phase 3: User Story 1 - No Lua error in a fight (Priority: P1) 🎯 MVP

**Goal**: secret names count as missing; the skill check skips a fight and runs after it (contracts K1-K4, research
R1).

**Independent Test**: `tests/fishing/skill_secret_test.lua` passes.

- [X] T003 [US1] Write `tests/fishing/skill_secret_test.lua` (pattern: `tests/fishing/next_rank_test.lua` and
  `cap_warning_test.lua` for loading the addon with a Fishing rank and a level). Cases:
  - **K1**: set `tooltip_names[npcID]` of the trainer NPC (the `C_TooltipInfo.GetHyperlink` stub) to a string of
    its own, for example `"Secret Heming"`, and list only that string in `secret_values` (`secret_values` marks a
    value, so marking the real name would also make the table's fallback name secret); `ns.Skill.GetNextRank()`
    raises no error, its `sources.npc` is `"table"` or `"english"`, and its `where` names the table's name, not
    `"Secret Heming"`.
  - **K4**: after K1, clear `secret_values`; `GetNextRank()` gives `sources.npc == "game"` (the secret name was not
    cached).
  - **K2**: with the skill past `learnAt` and the level too low (the "can learn" notice waits), `in_combat = true`,
    fire `CHAT_MSG_SKILL` and `SKILL_LINES_CHANGED`: no tooltip lookup is made (count `C_TooltipInfo.GetHyperlink`
    calls by wrapping it) and nothing is printed.
  - **K3**: with the level reached during the fight (`in_combat = true`, level raised, `CHAT_MSG_SKILL` fired: no
    notice), set `in_combat = false` and fire `PLAYER_REGEN_ENABLED`: the "You can learn %s Fishing now." line is
    printed once; a second `PLAYER_REGEN_ENABLED` prints nothing more.
  - Run it: K1 fails (error), K2 and K3 fail.
- [X] T004 [US1] In `OneKeyFishing/Fishing/Skill.lua`:
  - `NonEmpty(text)`: return nil when `issecretvalue and issecretvalue(text)`, before any comparison.
  - `Check(modeEntry)`: return at its start while `InCombatLockdown and InCombatLockdown()`.
  - Register `PLAYER_REGEN_ENABLED` with `function() Check(false) end`, next to the other skill events, with a
    comment: a notice owed during a fight comes after it.
  - Run T003: passes; `npm test` passes.

**Checkpoint**: the error of 2026-11-08 cannot happen; tests prove K1-K4.

---

## Phase 4: User Story 2 - Catches in a cave belong to the zone (Priority: P1)

**Goal**: a continent map becomes the zone under the point (contracts C1-C4, research R2).

**Independent Test**: `tests/catchdb/cave_test.lua` passes.

- [X] T005 [P] [US2] Write `tests/catchdb/cave_test.lua` (pattern: `tests/catchdb/area_test.lua`,
  `recording_test.lua`). With a Fishing rank:
  - **C2**: `player_map_id = 1414`, `map_types[1414] = 2`, `player_map_position = { 0.52, 0.55 }`,
    `map_at_position[1414] = { mapID = 1413, mapType = 3 }`, `player_map_positions[1413] = { 0.461, 0.30 }`:
    `CatchDB.GetCurrentPlace()` returns 1413, the range, the cell of (0.461, 0.30) and that x, y.
  - **C3**: no `map_at_position` entry: nil. An entry of type 2 (another continent): nil. A zone but no position on
    it (`player_map_positions[1413]` absent and `player_map_position` nil for the zone): nil. No position on the
    continent: nil.
  - **C1**: `map_types[1413] = 3`: unchanged result for the zone map itself (no `GetMapInfoAtPosition` call).
  - **P1 end to end**: a cast start (`FISHING_CAST_START`) and a catch on the continent record a key starting with
    `1413:`, never `1414:`; with no zone under the point no cast entry and nothing recorded.
  - Run it: fails.
- [X] T006 [US2] In `OneKeyFishing/CatchDB/CatchDB.lua` `CatchDB.GetCurrentPlace()`:
  - After reading `mapID`, read `C_Map.GetMapInfo(mapID)`. When its `mapType` is 2 (Continent) or lower (use
    `Enum.UIMapType.Continent` with the literal 2 as fallback), read the player's position on it
    (`C_Map.GetPlayerMapPosition(mapID, "player")`); without one return nil. Otherwise
    `C_Map.GetMapInfoAtPosition(mapID, x, y)`; keep it only if its `mapType` is 3 (Zone) or higher, else return nil;
    `mapID` becomes its `mapID`.
  - `CatchDB.GetCell(mapID)` then reads the cell on the zone; when it gives cell `"x"` (no position on the zone)
    for a converted map, return nil.
  - Replace the comment "a cave reports the continent (V2, docs/tech-debt.md)" with the rule and its source (the
    `/run` of 2026-11-08, `docs/forever-api.md`).
  - Run T005: passes; `npm test` passes (the catalog, CatchHere and debug tests read `GetCurrentPlace`).

**Checkpoint**: no continent place key can be written.

---

## Phase 5: User Story 3 - Spots are named after their subzone (Priority: P2)

**Goal**: the area by name, walked over frames once per subzone (contracts A1-A5, research R3).

**Independent Test**: `tests/catchdb/area_test.lua` passes.

- [X] T007 [US3] Rewrite `tests/catchdb/area_test.lua` for `CatchDB.LookupArea(done)`. Use `CatchDB.private`
  (`P.MAX_AREA_ID`, `P.AREA_CHUNK`, `P.ResetAreas()`); set `P.MAX_AREA_ID` small (for example 50) and
  `P.AREA_CHUNK` 10 in the tests and restore them. Cases:
  - **A3 found**: `sub_zone = "Crystal Lake"`, `area_names[20] = "Crystal Lake"`, `area_names[30] = "Other"`;
    `LookupArea(done)`: `done` not called yet; after `flush_timers()` called once with 20.
  - **Folding**: the Cyrillic and ASCII case cases of the old file (the needle and the name differ only in case):
    found.
  - **A3 lowest**: `area_names[12]` and `[40]` both "Crystal Lake": 12.
  - **A2 cache**: a second call after the walk calls `done(20)` at once (no timer queued); a text with no match
    caches false: the second call queues nothing and calls nothing.
  - **A5 steps**: wrap `C_Map.GetAreaInfo` to count calls per timer run: no run makes more than `AREA_CHUNK`
    calls; the walk ends after `ceil(MAX_AREA_ID / AREA_CHUNK)` runs.
  - **A1**: `sub_zone = ""`: `done` never called and no timer queued; a secret subzone text (`secret_values`):
    the same.
  - **A4**: a call for "Crystal Lake" starts a walk; before `flush_timers`, change `sub_zone` to "Other" and call
    again: the second `done` is never called; the first gets 20.
  - **Two waiters**: two calls for the same text before the walk ends: both get 20.
  - **Cast**: `FISHING_CAST_START` with a position, then `flush_timers()`, then a catch: the cell's `a` counts
    area 20.
  - Run it: fails (no `LookupArea`).
- [X] T008 [US3] In `OneKeyFishing/CatchDB/CatchDB.lua`: replace `CatchDB.GetArea(mapID, x, y)` with
  `CatchDB.LookupArea(done)` per data-model.md "Area lookup":
  - `local MAX_AREA_ID, AREA_CHUNK = 20000, 2000` exposed as `P.MAX_AREA_ID`, `P.AREA_CHUNK` (read through `P` at
    run time, so the tests can lower them); `areaByName = {}`, `walk = nil`; `P.ResetAreas()` clears both.
  - The needle: `GetSubZoneText()`; nil unless a non-secret, non-empty string; folded with `ns.FoldCase`.
  - Cached number: `done(id)`; cached false: return. A walk for the same needle: append `done`. A walk for another
    needle: return. Else start `walk = { needle, next = 1, waiting = { done } }` and run a step.
  - A step: for `next .. min(next + AREA_CHUNK - 1, MAX_AREA_ID)` read `C_Map.GetAreaInfo(id)`; the first id whose
    folded name equals the needle ends the walk early (IDs go up, so it is the lowest). At the end cache the
    result (id or false), clear `walk`, and call each waiting `done(id)` when an id was found. Else
    `C_Timer.After(0, step)`.
  - Comment: the source (`/run` of 2026-11-08: Ratchet 392, Stonebull Lake 223, highest ID 17853, 4.5 ms per full
    walk) and Principle II (the needle is the client's own text). Drop the `VERIFY(V34)` marker and the
    `C_MapExplorationInfo.GetExploredAreaIDsAtPosition` call.
- [X] T009 [US3] In `OneKeyFishing/CatchDB/Events.lua` `FISHING_CAST_START`: build the cast entry without `area`,
  then, when `x` is set, `CatchDB.LookupArea(function(areaID) entry.area = areaID end)`. Run T007: passes.
- [X] T010 [US3] In `OneKeyFishing/Core/Spike.lua`: remove the "Areas (V34)" section (`AreaLines` and its call, its
  header comment part); keep "Folding (V36)". In `tests/ui/spike_test.lua`: drop "Areas (V34)" from the section
  list and the Areas test cases (keep the Folding ones). If no addon file reads `C_MapExplorationInfo` or
  `CreateVector2D` any more (grep), remove them from `.luacheckrc` `read_globals`. `npm test` passes.

**Checkpoint**: spots at Stonebull Lake can get their name; no frame walks more than `AREA_CHUNK` IDs.

---

## Phase 6: User Story 4 - Pool catches are not counted as open water (Priority: P2)

**Goal**: the source is always unknown (contract L1, research R4).

**Independent Test**: the changed case in `tests/catchdb/recording_test.lua` passes.

- [X] T011 [P] [US4] In `tests/catchdb/recording_test.lua` replace "IsPoolLoot tells the pool, the bobber and no
  source apart" with: for a pool object, the bobber and no source, `ns.IsPoolLoot()` is nil each time; a catch from
  a pool object writes no `p` part in the cell; `CatchDB.HasPoolData()` stays false. Keep (or add, if missing) a
  case where a stored cell with a `p` part from an older build still shows through the water filter and makes
  `HasPoolData()` true. Run it: fails.
- [X] T012 [US4] In `OneKeyFishing/Catch/Catch.lua`: `ns.IsPoolLoot()` returns nil, with a comment: in Forever a pool
  catch's loot source is the bobber (V3, seen 2026-11-06), so the source is not known; the `VERIFY(V3)` marker and
  the loot-source walk go (keep `ns.GameObjectID` if another file uses it: grep). Update the header comment of
  `FISH_CAUGHT` (fromPool is nil). In `OneKeyFishing/CatchDB/Views.lua` the debug line reads
  `"last catch from a pool: unknown"` when `P.lastPool` is nil. Run T011: passes; `npm test` passes (fix tests that
  expected `false` from a bobber source, keeping their intent). (Code review round 1: `ns.IsPoolLoot`, the `fromPool` argument, `P.lastPool` and the debug line went as dead code; `FISH_CAUGHT` is `(items, castID)`.)

**Checkpoint**: no new pool part is written; old ones still read.

---

## Phase 7: User Story 5 - No pole the player cannot use (Priority: P3)

**Goal**: the pole choice by skill (contracts G1-G3, research R5).

**Independent Test**: `tests/fishing/gear_pole_test.lua` passes.

- [X] T013 [P] [US5] Write `tests/fishing/gear_pole_test.lua` (pattern: the gear tests in `tests/fishing/`, bags
  stubbed). Cases: skill 40, bags with Darkwood (6366, needs 50) and Strong (6365, needs 10): `Gear.FindBestPole()`
  is 6365 (**G1**); skill 50: 6366; skill unknown (no Fishing): 6366 (**G2**); a pole not in
  `GameData.FishingPoles` but of the pole item class: considered at any skill (**G2**); `Gear.GetPole()` with
  `charDB.gear.pole = 6366` held at skill 40: 6366 (the choice by hand). Run it: G1 fails.
- [X] T014 [US5] In `OneKeyFishing/Fishing/Gear.lua` `Gear.FindBestPole()`: read `local rank = ns.Skill.Get()` once;
  in `Consider`, skip a pole when `rank` and `ns.GameData.FishingPoles[itemID]` and its `skill > rank`. Comment: the
  base skill is compared, as for lures (V44). In `OneKeyFishing/GameData/FishingPoles.lua` change "recorded, not
  used yet: docs/tech-debt.md" to say `Gear.FindBestPole` uses it. Run T013: passes.

**Checkpoint**: all five stories pass their tests.

---

## Phase 8: Polish and documents

- [X] T015 [P] `docs/architecture/catch-db.md`: the place of a cast (a continent becomes the zone under the point;
  no zone, no place), the area lookup (`LookupArea`, by name, cached, walked over frames), the pool source unknown.
  `docs/architecture/fishing-mode.md`: the fight skip of the skill check and `PLAYER_REGEN_ENABLED`; the pole rule.
  `docs/architecture/ui.md` (or wherever the spike sections are listed): Areas gone.
- [X] T016 [P] Verification records: `specs/002-local-catch-db/verification.md` V2 (a cave reports the continent;
  since spec 011 the place is the zone under the point; the `/run` note of 2026-11-08 is there already) and V3
  (closed by spec 011: the source is unknown, the format keeps the optional pool part; marker removed); `specs/005-catch-catalog/verification.md` V33
  (a cave reports the continent; the place is the zone under the point) and V34 (the area by name, marker removed).
  Append `<br>**Spec 011:** ...` to the result cell, as spec 010 did.
- [X] T017 [P] `CHANGELOG.md` `[Unreleased]` "Fixed": the Lua error in instance fights from the next-rank advice
  (released in 1.1.0); fishing mode no longer picks a pole above the Fishing skill. The cave, subzone and pool
  changes belong to the unreleased shared database: no line. `OneKeyFishing/README.md`: only if it names pools or
  the "Water" filter as working, or the pole choice: adjust.
- [X] T018 [P] `docs/tech-debt.md`: remove batch 2, batch 6 and the pole item (and their open items); batch 5 keeps
  the lure item; add a History line for 2026-11-08, spec 011. `docs/release-plan.md`: batch 2 done by spec 011, the
  harvest can follow. `CLAUDE.md`: the "Places" line already says the rules; check the `Fishing/Skill.lua` and
  `CatchDB` rows need no change.
- [X] T019 [P] Checklists: `docs/checklists/catch-catalog.md` step 5 (the cave spot under The Barrens, its pin) and
  step 6 (spot names by subzone) say what to expect now; step 9 (pools) says the filter stays hidden.
  `docs/checklists/spike.md`: P2 (Areas) closed by spec 011 and removed from the spike.
- [X] T020 Run `npm run check` and `npm test`. Revert each fix once (T004, T006, T008/T009, T012, T014) and see its
  test fail; restore. Note the marker count (V3 and V34 gone) and the test count.
- [X] T021 Update the 1.2.0 test page artifact (`https://claude.ai/artifact/8bqDcm6BKLMFQgkMgySQpy`, phase "After
  spec 011"): steps b-pool, b-cave, b-subzone as in quickstart.md "In game (after the implementation)", plus a
  fight step (no error in a dungeon) and an optional pole step; the already confirmed `/run` facts in the intro.

---

## Dependencies and execution order

- Phase 1 -> Phase 2 -> the stories. US1 (Skill.lua) and US5 (Gear.lua) need no stub and do not depend on Phase 2.
- US2 and US3 both change `CatchDB/CatchDB.lua`: do T006 before T008 (same file). US3's T009 changes
  `CatchDB/Events.lua`, which US2 does not touch.
- US4 touches `Catch/Catch.lua`, `CatchDB/Views.lua` and `recording_test.lua`: independent of the others.
- Phase 8 after all stories; T020 after T015-T019; T021 last.

## Parallel examples

- After Phase 2: T003 (US1), T005 (US2), T011 (US4) and T013 (US5) are different test files: write them together.
- Within US3: T010 (spike) is independent of T008/T009.
- In Phase 8: T015 to T019 touch different documents.

## Implementation strategy

- **MVP**: US1 alone (the fight error that players of 1.1.0 meet). Then US2 and US3 (the data before the harvest),
  then US4 and US5.
- Each story ends at its checkpoint with `npm test` green; the in-game check (quickstart.md) comes after all of
  them, from the 1.2.0 test page.
