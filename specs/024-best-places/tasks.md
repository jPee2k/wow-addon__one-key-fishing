---

description: "Task list for spec 024: the best places to farm, and the three-level place list"
---

# Tasks: The Best Places to Farm, and the Three-Level Place List

**Input**: `specs/024-best-places/` (spec, plan, research R1-R10, data-model, contracts/best-places.md, quickstart)

**Tests**: included (CLAUDE.md, Principle V: a test with every logic change that runs without the game). Tests run
in fengari (Lua 5.3); the addon stays free of 5.1/5.3 differences.

**Paths**: addon files under `OneKeyFishing/`, tests under `tests/<area>/`, documents in the repository root.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: US1 ranking, US2 filters, US3 subzones and spots, US4 catalog levels, US5 tooltip, US6 ways in

---

## Phase 1: Setup

- [X] T001 Read `docs/architecture/catalog.md`, `docs/architecture/catch-db.md` ("Queries", "Views across maps"),
  `docs/architecture/ui.md` (the catalog tab, the window's pages), `UI/CatalogTab.lua` (its zone and spot rows) and
  `specs/024-best-places/research.md` before editing; no file change
- [X] T002 [P] In `tests/wow.lua`: `map_levels[mapID] = { min, max }` answered by a new `C_Map.GetMapLevels` stub
  (nothing for an unlisted map) and `player_level` for `UnitLevel("player")` (default 60); document both in the
  file's list of knobs
- [X] T003 [P] New `OneKeyFishing/GameData/Continents.lua` (data only: `GameData.Continents = { kalimdor = 1414,
  eastern = 1415 }`, UiMap IDs); add it to `OneKeyFishing/OneKeyFishing.toc` among the GameData files and to
  `docs/architecture/game-data.md`'s table

---

## Phase 2: Foundational (blocks every story)

- [X] T004 Test first, new `tests/catchdb/view_time_test.lua`: `QueryMap`, `QueryCells` and `Query` views carry
  `seconds` (summed `t`) and `catchesPerHour = 3600 x catches / seconds` from the seed,
  the own catch and other players' records alike (revised in review: another player's time weighted by its catches,
  at least 5 s a cast),
  the same under `water = "pool"` and `bonus = "bonusOnly"` as without (the parts have no time); `catchesPerHour` is
  nil when `seconds` is 0
- [X] T005 In `OneKeyFishing/CatchDB/Views.lua`: `NewSum` gains `t = 0, tc = 0` (raw seconds and catches; a seed
  cell's raw `r`); `AddCell` adds them before the water / bonus filter, also for other players' parts (never into
  the weighted parts); `BuildView` sets `view.seconds` and `view.catchesPerHour` (data-model.md "View additions")
- [X] T006 Add the new texts to `OneKeyFishing/Locales/enUS.lua` and their nine translations (`deDE`, `esES`,
  `esMX`, `frFR`, `koKR`, `ptBR`, `ukUA`, `zhCN`, `zhTW`): "Best places", "Catalog", "Level", "No subzone",
  "Safe for me: %s", "On", "Off", "Continent: %s", "Nothing matches the filters.",
  "%d%% of the catch here has no price: the gold may be higher.", "%s: %s chance, %s each, %d%% of the gold",
  "%d-%d". Reused, already in `enUS.lua` (checked 2026-11-23): "All", "Catches", "Skill", "Place", "Gold per hour".
  The continents' names come from the game (`Catalog.ZoneName(1414)`, `(1415)`), not from translations. Colour codes
  outside the strings

**Checkpoint**: `npm test` passes with T004.

---

## Phase 3: User Story 1 - Where to fish for gold (P1) MVP

**Goal**: the top 10 zones by gold per hour, unsafe zones hidden by default.

**Independent test**: twelve zones of data: ten listed, ordered, none above level + 3; Safe for me off: an unsafe
zone shows, its level red.

### Tests for User Story 1

- [X] T007 [P] [US1] New `tests/catalog/best_places_test.lua`: gold per hour of a zone = sum over items of
  `chance x pieces x Prices.Get` x `catchesPerHour` (SC-001, hand-computed); an item without a price counts 0;
  `unpriced` is the unpriced share of pieces and `"*"` shows at >= 0.25; at most 10 zones, ordered by gold, ties by
  catches then map ID; a zone with fewer than 50 catches or no time is left out (SC-002); `ZoneLevels` from
  `map_levels`, nil for an unlisted map; Safe for me hides `min > level + 3`, keeps `min == level + 3`, never hides a
  zone without levels; "Nothing matches" state when every zone is filtered out

### Implementation for User Story 1

- [X] T008 [US1] New `OneKeyFishing/Catalog/BestPlaces.lua` (`ns.BestPlaces`, layer 2; TOC after
  `Catalog/Catalog.lua`): `ZoneLevels(mapID)` (`C_Map.GetMapLevels`, cached per session, `0, 0` or nothing = nil,
  `-- VERIFY(V75): GetMapLevels answers Forever's zone maps with their level range`), `Numbers(view)` (catchValue,
  goldPerHour, unpriced, top 5 items with chance, price and share), `Zones(filter)` (every map of
  `CatchDB.Maps(filter)` through `CatchDB.QueryMap`, the rules of data-model.md "Rules", at most 10, `state`
  "building" / "ready", rebuilt in frame steps of 3 ms when more than 4 maps changed, keyed by
  `CatchDB.GetStampVersion()`, the filter, the kind choice and a prices version moved on `PRICES_CHANGED`),
  `GetVersion()`, `FormatGold(copper)` (`ns.FormatMoney` per hour), `Describe()`
- [X] T009 [US1] Per-character state: `OneKeyFishing/Core/Core.lua` `CHAR_DB_DEFAULTS.bestPlaces = { safe = true,
  continent = "all" }`; `BestPlaces.GetSafe()`, `SetSafe(on)` (fires `SETTINGS_CHANGED("bestPlaces")` when it
  changed); Safe for me applied in `Zones`: hide when `levels.min > UnitLevel("player") + 3`
- [X] T010 [US1] New `OneKeyFishing/UI/PlaceList.lua` (`ns.PlaceList`, TOC before `UI/CatalogTab.lua`): a scroll list
  of zone rows with columns given by the caller (`PlaceList.Create(parent, columns)`, `SetZones(zones, opened)`),
  an expand mark per zone, reusing the catalog's pin button (atlas check) and the window's row height; no data
  logic (it draws what it is given)
- [X] T011 [US1] New `OneKeyFishing/UI/BestPlacesTab.lua` (`ns.BestPlacesTab`: `Create(f)`, `Refresh`, `Tick`; TOC
  after `UI/CatalogTab.lua`): the columns Place, Skill, Level (zone: "min-max", red when `min > UnitLevel`), Gold
  per hour (with "*" when unpriced >= 0.25), Catches; the status line ("building", "Nothing matches the
  filters."); polls `BestPlaces.GetVersion()` on the window's tick
- [X] T012 [US1] In `OneKeyFishing/UI/StatsFrame.lua`: a fourth `pages` row `{ key = "best", label = L["Best
  places"], ... }` after the catalog, `StatsFrame.OpenBest()`; keep `ns.db.statsTab` valid for the new key
- [X] T013 [US1] New `tests/ui/best_tab_test.lua` (part 1): the tab opens, lists the zones of the test data in order
  with their columns, the level in red for an unsafe zone shown with Safe for me off, the empty text

**Checkpoint**: US1 works alone (zones only, not yet opening).

---

## Phase 4: User Story 2 - Narrow the list (P1)

**Goal**: Skill, Safe for me, Kinds, Source, Water, Camp bonus and Continent change the ranking at once.

### Tests for User Story 2

- [X] T014 [P] [US2] Extend `tests/catalog/best_places_test.lua`: a hidden kind's items count nothing; the Skill
  filter "up to N" (spec 021) changes the gold; Source "mine"; Water "pool" and Camp bonus "bonusOnly" use the
  filtered items with the place's whole pace (research R1); Continent from `map_parents`/`map_types` (Kalimdor,
  Eastern Kingdoms, unknown = only under All); `SetContinent` / `SetSafe` write `ns.charDB.bestPlaces` and fire
  `SETTINGS_CHANGED("bestPlaces")` once per change
- [X] T015 [P] [US2] Extend `tests/ui/best_tab_test.lua`: each filter button updates the list at once; after a
  simulated relog Skill (own range), Source, Water and Camp bonus are at their defaults, Safe for me and Continent
  as the character left them, the kinds as the account left them

### Implementation for User Story 2

- [X] T016 [US2] In `OneKeyFishing/Catalog/BestPlaces.lua`: `Continent(mapID)` (walk `C_Map.GetMapInfo` parents to
  `Enum.UIMapType.Continent`, cached; `-- VERIFY(V76): Forever's zone maps have Kalimdor 1414 or Eastern Kingdoms
  1415 as their continent`); `GetContinent()`, `SetContinent(value)` for `"all"`, `"kalimdor"`, `"eastern"` (same
  message); kinds through `Catalog.IsKindShown(Catalog.ItemKind(itemID))` in `Numbers`
- [X] T017 [US2] In `OneKeyFishing/UI/BestPlacesTab.lua`: the filter rows as on the catalog (reuse
  `CatchHere.OpenSkillMenu`, `OpenSourceMenu`, `OpenWaterMenu`, the kind menu and the camp bonus menu through
  `ns.OpenRadioMenu` / `ns.OpenCheckboxMenu`); two new radio menus Safe for me (On, Off) and Continent (All,
  Kalimdor, Eastern Kingdoms); the tab's own filter table reset at login (Skill = `CatchDB.SkillFilter` of the own
  range); redraw on `SETTINGS_CHANGED` of `hiddenKinds` and `bestPlaces`

---

## Phase 5: User Story 3 - Subzones and spots with pins (P1)

**Goal**: a zone opens into its subzones (summed, pin on the best spot), a subzone into its spots.

### Tests for User Story 3

- [X] T018 [P] [US3] New `tests/catalog/group_spots_test.lua`: `Catalog.GroupSpots` puts six spots of one area in one
  group (SC-003); a group of one spot is the spot row itself; spots without an area form one "No subzone" group;
  the group's `catches` is the sum, its other numbers come from the caller's `sum`, its `pin` is the pin of its spot
  with the best chance; groups and rows keep the order of the input's sort, little data last
- [X] T019 [P] [US3] Extend `tests/catalog/best_places_test.lua`: `BestPlaces.Spots(mapID, filter)`: a subzone's
  gold per hour is its spots' summed value over their summed seconds (FR-001, not an average); spots by gold, little
  data last
- [X] T020 [P] [US3] Extend `tests/ui/best_tab_test.lua`: opening a zone shows its subzones once each, opening a
  subzone its spots, each with a pin button; the subzone's pin sets the map pin on its best spot; the best spot's pin
  is reached in three clicks from the minimap menu (the menu entry, the zone, the subzone's pin: SC-004)

### Implementation for User Story 3

- [X] T021 [US3] In `OneKeyFishing/Catalog/Catalog.lua`: `Catalog.GroupSpots(rows, sum)` (contracts/best-places.md;
  the group's `name` from `Catalog.AreaName` or `L["No subzone"]`, looked up when drawn)
- [X] T022 [US3] In `OneKeyFishing/Catalog/BestPlaces.lua`: `Spots(mapID, filter)` from `CatchDB.QueryCells` with
  `Numbers` per spot, grouped by `Catalog.GroupSpots` with a sum by summed value and seconds; cached per map stamp
  and filter
- [X] T023 [US3] In `OneKeyFishing/UI/PlaceList.lua`: group and spot rows (indent per level, expand mark on groups,
  the pin button on groups and spots); in `OneKeyFishing/UI/BestPlacesTab.lua` open zones and groups on a click

---

## Phase 6: User Story 4 - The three levels in the catalog (P2)

**Goal**: an item's zones open into subzones and spots, with the catalog's columns; no duplicate subzone.

- [X] T024 [P] [US4] Covered by `tests/catalog/group_spots_test.lua` ("the catalog groups an item's spots the same
  way") and the catalog UI tests `tests/ui/catalog_skill_test.lua`, `tests/catalog/spot_pin_test.lua` (updated for
  the "No subzone" group): an item with six spots in one subzone and three in another of one zone
  shows two group rows, each opening into its spots with pins; a one-spot subzone is a spot row; chance and catches
  of a group are the item's numbers summed over its spots (catch-weighted chance)
- [X] T025 [US4] In `OneKeyFishing/UI/CatalogTab.lua`: draw the item's places through `ns.PlaceList` with the
  catalog's columns (Place, Skill, Chance, Catches) and `Catalog.GroupSpots(Catalog.Spots(...), sum)`; remove the
  zone/spot row code that `PlaceList` now holds; keep every existing catalog test green

---

## Phase 7: User Story 5 - What earns the gold (P3)

- [X] T026 [P] [US5] Extend `tests/ui/best_tab_test.lua`: hovering a zone, a group and a spot shows up to five items
  by the gold they bring, each "name: chance, price each, share of the gold", the players line, and the
  "%d%% of the catch here has no price" line when the `*` shows
- [X] T027 [US5] In `OneKeyFishing/UI/BestPlacesTab.lua`: the row tooltip from `top`, `players` and `unpriced`

---

## Phase 8: User Story 6 - Ways in (P2)

- [X] T028 [P] [US6] Extend `tests/ui/minimap_menu_test.lua` (entries "Catalog" and "Best places" after "Statistics",
  each opening its tab) and the commands test in `tests/core/` (`/okf best` opens the tab; listed in order with its
  English description)
- [X] T029 [US6] In `OneKeyFishing/UI/Minimap.lua`: `root:CreateButton(L["Catalog"], ...)` and `root:CreateButton(
  L["Best places"], ns.StatsFrame.OpenBest)` after "Statistics"; in `OneKeyFishing/Core/Commands.lua`: `best`,
  "open the best places to fish", sorted

---

## Phase 9: Polish & Cross-Cutting

- [X] T030 New `specs/024-best-places/verification.md` (V75, V76: what is assumed, how to check, what happens if wrong)
  and `docs/checklists/best-places.md` with its row in `docs/checklists/README.md` (V75 and V76 by `/run` lines of at
  most 255 characters, counted; the tab; the catalog's Wetlands for Oily Blackmouth without duplicate subzones)
- [X] T031 [P] `OneKeyFishing/Core/Debug.lua`: a "best places" section from `BestPlaces.Describe()`
- [X] T032 [P] `CLAUDE.md`: module map (`Catalog/BestPlaces.lua`, `UI/PlaceList.lua`, `UI/BestPlacesTab.lua`,
  `GameData/Continents.lua`), the saved field `bestPlaces` (per character), the setter rule (`BestPlaces.SetSafe`,
  `SetContinent`), features with a `verification.md` (add 024)
- [X] T033 [P] `docs/architecture/catalog.md` (BestPlaces, GroupSpots), `catch-db.md` (view time), `ui.md`
  (PlaceList, the tab, the menu entries), `core.md` (the char field, the command), `game-data.md` (Continents)
- [X] T034 [P] `CHANGELOG.md` under `[Unreleased]` and `OneKeyFishing/README.md` (the tab, its filters, the three
  levels in both tabs, the menu entries, `/okf best`)
- [X] T035 [P] `docs/ROADMAP.md`: remove the "best places" entry from "Planned" once done
- [X] T036 `.luacheckrc` (`UnitLevel` if missing), `tools/addon.mjs` (only if a new file needs listing); run
  `npm run check` and `npm test`; fix what they report

---

## Dependencies & Execution Order

- Phase 1 -> Phase 2 (T004-T006) -> US1 (T007-T013) -> US2 (T014-T017).
- US3 (T018-T023) needs US1 (the tab, `PlaceList`); US4 (T024-T025) needs T021 and T023; US5 needs US3 (`top` per
  row); US6 needs T012 (`OpenBest`).
- Within a story: tests first (they fail), then the implementation.

### Parallel opportunities

- T002, T003; T007; T014, T015; T018, T019, T020; T024; T026; T028; T031-T035.

## Implementation Strategy

- **MVP**: Phases 1-4 (ranking and filters, zones only).
- Then US3 (subzones and spots), US4 (the catalog), US6 (ways in), US5 (tooltip), Polish.
- Commit only when the author asks.

## Revisions after the reviews and the in-game check (2026-11-23)

- Zone levels: `C_Map.GetMapLevels` gives 0 in Forever, the client has no zone levels; `GameData/ZoneLevels.lua`
  (ranges from LibTouristClassicEra, the capitals and Moonglade 1-60) replaced it; a cave or building map takes its
  zone's range; a continent map is never ranked. V75 and V76 confirmed in game, their markers removed; the test stub
  `map_levels` / `GetMapLevels` was removed again.
- The pace: a weighted seed cell's time goes with its counted `c` (not `r`); another player's time is weighted by its
  catches before the filters and, like a seed cell's, counts at least 5 s a cast; the harvest scales `t` with the
  catch factor.
- Rankings: a copy of the filter per ranking, a build fills a table swapped in at its end, a dropped ranking stops its
  steps, only the latest two rankings are kept; recounts on the price switches and on an unpriced item's info, not on
  Safe for me, the continent or a level-up (they only redraw, the level a second later).
- Groups: one group in a zone opens straight into its spots; a group carries its spots' shared camp bonus tag with
  its own numbers, mixed tags sum the plain numbers; the unpriced share counts pieces; spots under a subzone show only
  their coordinates; a group's pin label names its spot.
- Bonus catches only: an item's chance under the bonus (`Catalog.ItemNumbers`), and little data from those numbers.
