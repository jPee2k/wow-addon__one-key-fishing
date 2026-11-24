---

description: "Task list for spec 026: Safe for me keeps the other faction's zones out of the best places"
---

# Tasks: "Safe for me" Keeps the Other Faction's Zones Out of the Best Places

**Input**: `specs/026-safe-faction/` (spec, plan, research R1-R8, data-model, contracts/safe-faction.md, quickstart)

**Tests**: included (CLAUDE.md, Principle V: a test with every logic change that runs without the game). Tests run
in fengari (Lua 5.3); the addon stays free of 5.1/5.3 differences.

**Paths**: addon files under `OneKeyFishing/`, tests under `tests/<area>/`, documents in the repository root.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: US1 the other faction's zones stay out, US2 seeing everything with a warning

## Architecture rules for this change (CLAUDE.md, constitution VI)

- **Layers**: `GameData/ZoneFactions.lua` is layer 0, data only (no function, call, `ns.L` or other module; ASCII;
  `npm run check` enforces it). The rule lives in `Catalog/BestPlaces.lua` (layer 2), which may read `ns.GameData`;
  `UI/BestPlacesTab.lua` (layer 3) stays as it is and only calls `BestPlaces` functions. No lower layer names a frame.
- **Load time**: `UnitFactionGroup` and `C_Map.GetMapInfo` are called only at runtime (in `Zones`, `Compute`,
  `Unsafe`), never while the files load; `GameData.ZoneFactions` is read through `ns.GameData` at runtime too.
- **No new message, setting or text**: `SetSafe` keeps firing `SETTINGS_CHANGED("bestPlaces")`, which only redraws
  (`Bump`); the faction is read when the list is read, so no ranking is recounted. No `L` key, no `charDB` field, no
  `DB_SCHEMA` bump.
- **By ID**: zones by UiMap ID, the faction by the game's untranslated tag (`"Alliance"`, `"Horde"`), never by a
  localized name.
- **VERIFY**: one marker `VERIFY(V77)` in `BestPlaces.ZoneFaction` only; `npm run build` refuses it until the author
  checks it in game.
- **Style**: the file headers and comments of the neighbouring code (what and why, spec number); Lua 5.1 without
  5.1/5.3 differences; lines of at most 120 characters; tests in the folder of their area (`tests/gamedata/`,
  `tests/catalog/`, `tests/ui/`), each test file in its own Lua state (`tests/run.mjs`).
- **Documents in the same change**: `CHANGELOG.md` and the manual (player-visible), `CLAUDE.md` and
  `docs/architecture/` (a new GameData entity), `verification.md` and the checklist (a new marker).

---

## Phase 1: Setup

- [X] T001 Read `OneKeyFishing/Catalog/BestPlaces.lua` (`ZoneLevels`, `Compute`, `Passes`, `Unsafe`, `Describe`),
  `tests/catalog/best_places_test.lua`, `tests/ui/best_tab_test.lua`, `tests/gamedata/shape_test.lua` and
  `docs/architecture/game-data.md` before editing; no file change
- [X] T002 [P] In `tests/wow.lua`: a global `player_faction` (default `"Horde"`) and a `UnitFactionGroup(unit)` stub
  that returns `player_faction, player_faction` for `"player"` (nil for nil); put both in the block "The Fishing
  skill and the character" next to `player_level`, with a comment line naming the knob
- [X] T003 [P] `.luacheckrc`: add `UnitFactionGroup` to `read_globals` next to `UnitLevel`

---

## Phase 2: Foundational (the data)

- [X] T004 [P] Test first in `tests/gamedata/shape_test.lua`: "zone factions: Alliance or Horde by UiMap ID (spec
  026)": every key `IsID`, every value exactly `"Alliance"` or `"Horde"`, 9 Alliance and 8 Horde entries, every key
  also a key of `GameData.ZoneLevels`, `GameData.ZoneFactions[1429] == "Alliance"`, `[1411] == "Horde"`, `[1440] ==
  nil` (Ashenvale contested)
- [X] T005 New `OneKeyFishing/GameData/ZoneFactions.lua` (data only, the header pattern of `ZoneLevels.lua`):
  `GameData.ZoneFactions = { [uiMapID] = "Alliance" | "Horde" }` with the 17 rows of data-model.md, grouped Alliance /
  Horde, each with its zone name in a comment; the header names the source (`AreaTable.FactionGroupMask` 2 Alliance,
  4 Horde, read through `UiMapAssignment`, wago.tools product `wowf`, build 1.60.1.71037), says that a map not listed
  is contested and that the values are `UnitFactionGroup`'s untranslated tags
- [X] T006 `OneKeyFishing/OneKeyFishing.toc`: `GameData\ZoneFactions.lua` after `GameData\ZoneLevels.lua`

**Checkpoint**: T004 passes; `npm run check` accepts the data file (no function, call, `L` or module there).

---

## Phase 3: User Story 1 - The other faction's zones stay out (Priority: P1) MVP

**Goal**: with Safe for me on, no zone or capital of the other faction is ranked; contested zones keep the level rule.

**Independent Test**: test maps in Elwynn's role (Alliance), Durotar's (Horde) and a contested one, all within the
level: a Horde character sees Horde and contested, an Alliance character Alliance and contested.

### Tests for User Story 1

- [X] T007 [US1] Tests first in `tests/catalog/best_places_test.lua` (list test maps in `ns.GameData.ZoneFactions`
  as the file does for `ZoneLevels`, e.g. one test zone `"Alliance"`, one `"Horde"`, one unlisted, all with levels
  within `player_level`; reset `player_faction` after each test):
  - `ZoneFaction`: a listed map gives its tag; a map whose parent is listed (a `C_Map.GetMapInfo` stub child) gives
    the parent's; an unlisted map nil; a real row (`1429` -> `"Alliance"`)
  - `PlayerFaction`: `"Horde"` / `"Alliance"` as the stub says; nil for `"Neutral"` and for nil
  - Safe for me on, `player_faction = "Horde"`: the Alliance test zone is not in `Zones`, the Horde and the contested
    ones are (SC-001, SC-002); mirrored for `"Alliance"`
  - a hostile zone with the best gold is still left out, and the next zone takes its place in the top 10
  - an own-faction zone above level + 3 stays hidden (the level rule unchanged)
  - `player_faction = "Neutral"` (and nil): only the level rule; both faction zones listed
  - `Describe()`'s last line ends with `faction Horde` (and `faction none` without one)
  - FR-007: for a zone of the own faction, `BestPlaces.Spots(mapID, filter)` returns all its spots, whatever their
    subzone (subzones and spots are never filtered by faction)

### Implementation for User Story 1

- [X] T008 [US1] `OneKeyFishing/Catalog/BestPlaces.lua`: a local `FirstListed(data, mapID)` holding the parent walk of
  `ZoneLevels` (the map's own entry, else up `C_Map.GetMapInfo(...).parentMapID`, at most 8 steps, nil when a map has
  no info); `ZoneLevels` uses it (behaviour unchanged, its V75 comment kept)
- [X] T009 [US1] Same file: `BestPlaces.ZoneFaction(mapID)` = `FirstListed(ns.GameData.ZoneFactions, mapID)` with
  `-- VERIFY(V77): the factions of GameData.ZoneFactions match the game's territory (friendly / hostile / contested)`;
  `BestPlaces.PlayerFaction()` = the first value of `UnitFactionGroup("player")` when it is `"Alliance"` or
  `"Horde"`, else nil (guard a missing function); `BestPlaces.Hostile(zone)` true when `zone.faction` and
  `PlayerFaction()` are both non-nil and differ
- [X] T010 [US1] Same file: `Compute` sets `zone.faction = BestPlaces.ZoneFaction(mapID)` next to `zone.levels`;
  `Zones` reads the character's faction once per call and `Passes(zone, safe, continent, level, faction)` returns
  false when `safe` and the zone is hostile to `faction`, before the level test; update the file's header and the
  comment above `INVALIDATING` (Safe for me, the continent, the level and the faction only filter the list when read)
- [X] T011 [US1] Same file: `Describe()` appends `, faction <tag>` (`none` when nil) to its last line
- [X] T012 [US1] Run `npm test`: T004 and T007 pass, and every existing test stays green with the stub's default
  `"Horde"` (their test maps 3001... have no faction; map 1452 Winterspring is contested)

**Checkpoint**: US1 complete; the list hides the other side's zones and capitals.

---

## Phase 4: User Story 2 - Seeing everything, with a warning (Priority: P2)

**Goal**: with Safe for me off, both sides are ranked and an enemy zone's Level is red.

**Independent Test**: Safe for me off, a Horde character: the Alliance test zone listed, its Level red; the Horde
zone within the level not red.

### Tests for User Story 2

- [X] T013 [P] [US2] In `tests/catalog/best_places_test.lua`: Safe for me off: both faction zones listed;
  `Unsafe({ faction = "Alliance", levels = { min = 1 } })` true for a Horde character, false for an Alliance one;
  `Unsafe({ levels = { min = 1 } })` (contested) false; no faction: only the level decides
- [X] T014 [P] [US2] In `tests/ui/best_tab_test.lua`: with Safe for me off and `player_faction = "Horde"`, the row of
  the Alliance test zone has its Level cell coloured red (the file's existing red check), a Horde zone within the
  level not; with Safe for me on and only Alliance test zones holding data, the status reads
  `L["Nothing matches the filters."]` (US1 scenario 5)

### Implementation for User Story 2

- [X] T015 [US2] `OneKeyFishing/Catalog/BestPlaces.lua`: `Unsafe(zone)` true when `BestPlaces.Hostile(zone)` or the
  zone's lowest level is above the character's; update its comment
- [X] T016 [US2] Run `npm test`: T013 and T014 pass; `UI/BestPlacesTab.lua` needs no change (it colours by `Unsafe`)

**Checkpoint**: US1 and US2 complete.

---

## Phase 5: Polish & Cross-Cutting Concerns

- [X] T017 New `specs/026-safe-faction/verification.md` (the header of `specs/024-best-places/verification.md`, IDs
  continue with V77): V77 assumed, where (`GameData/ZoneFactions.lua`, `BestPlaces.ZoneFaction`), if wrong (a zone
  hidden for the wrong side or not hidden; correct its row), the check (quickstart.md "In game"), status Open; the
  row says that closing it records the answer in `docs/forever-api.md` (zone territory) and removes the marker
- [X] T018 `docs/checklists/best-places.md`: steps for V77 (SC-003: each character in two zones of its own faction
  and one contested zone, no trip into enemy land: Horde in Durotar, The Barrens and Ashenvale, Alliance in Elwynn
  Forest, Westfall and Wetlands; `/run print(C_PvP.GetZonePVPInfo())`, counted at most 255 characters,
  gives `friendly` / `contested`, and the zone text agrees; the tab on a Horde and an Alliance character with Safe
  for me on and off); keep the file's status line and results section current; in
  `docs/checklists/README.md` its row names V77 and `specs/026-safe-faction` beside spec 024, and the needs (a Horde
  and an Alliance character)
- [X] T019 [P] `CHANGELOG.md` under `## [Unreleased]` (create that heading above `## [1.6.1]` when it is missing;
  `npm run check` skips it in its version check) (Safe for me also hides the other faction's zones and capitals;
  their Level is red when shown) and `OneKeyFishing/README.md` "Filters" line of Best places (Safe for me: zones more
  than 3 levels above you and the other faction's zones and capitals are hidden; contested zones are kept)
- [X] T020 [P] `CLAUDE.md`: `ZoneFactions` in the `GameData/*.lua` list of the module map; the `Catalog/BestPlaces.lua`
  row ("zone levels, factions and continents ..., the character's Safe for me (level and faction) and continent");
  the features with a `verification.md` (add 026)
- [X] T021 [P] `docs/architecture/game-data.md` (a `ZoneFactions.lua` row: shape, source, spec 026, V77, used by
  `Catalog/BestPlaces.lua`) and `docs/architecture/catalog.md` (`ZoneFaction`, `PlayerFaction`, `Hostile`; Safe for me
  hides hostile zones; `Unsafe` red for them; `Describe` names the faction)
- [X] T022 [P] `docs/ROADMAP.md`: a "Planned" or ideas entry for the known limit (hostile towns inside contested
  zones are not filtered: the game's data marks only Dalaran; would need a list of area IDs)
- [X] T023 [P] `docs/best-places-research.md` section 4: a line that spec 026 builds the decisions; its row in
  `docs/README.md` mentions the faction research (spec 026)
- [X] T024 Run `npm run check` and `npm test`; fix what they report; hand the in-game checklist (T018) to the author;
  commit only when the author asks

---

## Dependencies & Execution Order

- Phase 1 (T001-T003) -> Phase 2 (T004-T006) -> US1 (T007-T012) -> US2 (T013-T016) -> Polish (T017-T024).
- US2 needs US1's `zone.faction` and `Hostile` (T009, T010).
- Within a story: tests first (they fail), then the implementation.

### Parallel opportunities

- T002, T003; T004 (while T005 is written); T013, T014; T019-T023.

### Parallel example: User Story 2

```text
T013 tests/catalog/best_places_test.lua (Unsafe cases)
T014 tests/ui/best_tab_test.lua (red Level of an enemy zone)
```

## Implementation Strategy

- **MVP**: Phases 1-3 (the faction rule in Safe for me).
- Then US2 (the red Level with Safe for me off) and Polish.
- The build refuses `VERIFY(V77)` until the author checks it in game (or ships with `--force`, the author's choice).
- Commit only when the author asks.
