---

description: "Task list for the cumulative skill filter (spec 021)"
---

# Tasks: Cumulative Skill Filter

**Input**: Design documents from `specs/021-cumulative-skill-filter/`

- [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md)
- [contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md)

**Prerequisites**: plan.md, spec.md (user stories), research.md, data-model.md, contracts/

**Tests**: requested by the spec (decision 9) and required by constitution Principle V: every logic change gets a test
that fails on `develop` before the change. Write each test first and see it fail.

**Organization**: by user story; US1 and US2 are P1, US3 and US4 P2.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: the user story of spec.md (US1 to US4)
- Paths are from the repository root; addon files are under `OneKeyFishing/`, tests under `tests/`.

## Conventions for every task

- English for code, comments and documents; 120-character lines; ASCII outside `OneKeyFishing/Locales/`.
- Lua 5.1 / 5.3 neutral (tests run in fengari 5.3, the game is 5.1).
- Model new test files on the existing ones named in each task: the globals `player_map_id`, `player_map_position`,
  `fishing_rank`, `load_addon(fn)`, `catch_cell(c, m, items)`, `fish_cast`, `test`, `eq`, `near`, `click`,
  `find_frame` come from `tests/wow.lua`; one file is one login, the tests in it run in order.
- After each task: `npm run check` and `npm test` from the repository root.

---

## Phase 1: Setup (baseline)

- [X] T001 Run `npm run check` and `npm test` on `021-cumulative-skill-filter` before any change; note the counts of
  passing tests and the eight open `VERIFY` markers of spec 020 (they stay; this feature adds none).

---

## Phase 2: Foundational (blocking prerequisites)

**Purpose**: the filter value helper and the new texts every story uses.

- [X] T002 [P] Write `tests/catchdb/skill_filter_test.lua` first (model: `tests/catchdb/water_test.lua`, a plain
  `load_addon()`): `ns.CatchDB.SkillFilter(nil)` is `"all"`; `SkillFilter(4)` (`MAX_RANGE`) is `"all"`;
  `SkillFilter(0)`..`SkillFilter(3)` return `0`..`3` (research R5, data-model "4 is not a value");
  `ns.CatchDB.RangeOf(nil)` is nil, `RangeOf(0)` 0, `RangeOf(74)` 0, `RangeOf(75)` 1, `RangeOf(224)` 2, `RangeOf(299)`
  3, `RangeOf(300)` 4, `RangeOf(375)` 4; and `CatchDB.GetCurrentPlace()` with `fishing_rank = 230` returns range 3.
- [X] T003 In `OneKeyFishing/CatchDB/CatchDB.lua`, after `CatchDB.RANGES` is built (near line 34): add
  `function CatchDB.SkillFilter(range)` returning `"all"` when `range == nil or range >= MAX_RANGE`, else `range`;
  add `function CatchDB.RangeOf(rank)` returning nil for a nil rank, else `math.min(MAX_RANGE, math.floor(rank /
  RANGE_STEP))`, and use it in `CatchDB.GetCurrentPlace` (line ~168) instead of the inline formula. Comments cite
  spec 021 research R5. T002 passes.
- [X] T004 [P] Texts: add to `OneKeyFishing/Locales/enUS.lua` (next to `L["Skill: %s"]`) the ten keys of
  contracts/api.md "Texts": `"Skill: Up to %d"`, `"Skill: All"`, `"Up to %d"`, `"Up to %d (yours)"`, `"All (%d+)"`,
  `"All (%d+) (yours)"`, `"Catches with skill up to %d."`, `"Catches with any skill."`, `"Misses only with skill
  %s."`, `"Nothing caught: little data"`; and their translations in `deDE.lua`, `esES.lua`, `esMX.lua`, `frFR.lua`,
  `koKR.lua`, `ptBR.lua`, `ukUA.lua`, `zhCN.lua`, `zhTW.lua` (same order, each a whole sentence, the `%d` / `%s` kept;
  reuse each language's existing word for "Skill" and "Little data"; keep "(yours)" short so "Up to 224 (yours)" fits
  a 150 px menu). Width rule (FR-017): in each language `"Skill: Up to %d"` with 224 and `"Skill: All"` must be no
  longer, in characters, than that language's present `L["Skill: %s"]` with `L["All skill levels"]`, which fits the
  button today (for koKR, zhCN, zhTW a guide only: their glyphs are wider; the checklist step T021 (4) decides); a
  translation that would be longer gets a shorter wording. Do not remove any old key yet (T019).

**Checkpoint**: `SkillFilter` exists and is tested; the texts are in all ten files.

---

## Phase 3: User Story 1 - A place is never empty for lack of my exact skill (Priority: P1) MVP

**Goal**: a range "Up to N" sums every range from 0-74 up to N (FR-001, FR-002, FR-004).

**Independent Test**: data only in 75-149 at a place, own rank 180: `Query` under range `2` lists those items.

- [X] T005 [P] [US1] Write `tests/catchdb/skill_ranges_test.lua` first (model: `tests/catchdb/water_test.lua`, the
  seed set in `load_addon` and replaced by `ns.SeedData = ...; ns.Fire("SHARED_DATA_CHANGED")`). Seed cells at map
  1415, cell 47, keys `1415:0:47`, `1415:1:47`, `1415:2:47`, `1415:3:47`, each with a different item. Assert:
  `Query(1415, "47", { range = 2, source = "all" })` lists the items of ranges 0, 1 and 2 and not of 3, its `catches`
  is their sum; range `1` with data only in `1415:1:47` lists it (US1 scenario 1 at range 2 too); data only in
  `1415:3:47` gives scope `"none"` under range `1` (US1 scenario 3); `range = "all"` lists all four, as the sum of the
  four single cells (SC-002); `range = 4` gives the same view numbers as `"all"`; with 30 catches in `1415:0:47` and
  30 in `1415:1:47` the scope under range `1` is `"spot"` (60 >= 50) while under range `0` it is `"map"`; `QueryMap`
  and `QueryCells` under range `2` sum ranges 0-2 too; each item keeps its own `ranges` (`{ min, max }` of where it was
  caught).
- [X] T006 [US1] In `OneKeyFishing/CatchDB/Views.lua` `Ranges(filter)` (line ~652): return `CatchDB.RANGES` when
  `filter.range == "all"` or `filter.range >= MAX_RANGE`; else a new list `{ 0, 1, ..., filter.range }` (cache the five
  lists in a local table built once, so a call allocates nothing). Update the comment of `CatchDB.Query` (line ~677:
  `filter = { range = 0..3 or "all" ... }`: a range sums every range up to it, spec 021). T005 passes; fix any other
  test that asserted single-range sums under a number range by giving it the cumulative expectation, not by weakening
  it.

**Checkpoint**: every list sums cumulatively; nothing visible changed in the labels yet.

---

## Phase 4: User Story 2 - An honest miss rate for my skill (Priority: P1)

**Goal**: the miss rate from the chosen range alone at the list's scope, with its own little-data state (FR-005 to
FR-008).

**Independent Test**: 35 % misses in 0-74, 15 % in 150-224 (each >= 50 casts): range `2` reads 15 %.

- [X] T007 [P] [US2] Write `tests/catchdb/skill_misses_test.lua` first (model: `tests/catchdb/weights_test.lua` for
  the seed cells with misses). Assert on `CatchDB.Query`: cells `1415:0:47` (65 catches, 35 misses) and `1415:2:47`
  (85 catches, 15 misses): range `2` gives `missRate` 0.15 and `missLittleData` false, `catches` 150 (US2 scenario
  1); add `1415:1:47` with 20 catches, 10 misses: range `1` gives `missLittleData` true (30 casts < 50) while
  `littleData` is false and the items are listed (scenario 2); a spot with too few summed catches falls back to the
  map and the miss rate is range `r`'s on the whole map (scenario 3: put the range-2 casts in another cell of 1415);
  `range = "all"` reads range 4 only: no cell at range 4 gives `missLittleData` true, a cell `1415:4:47` with 60
  catches and 6 misses gives 0.1 (scenario 4); under `water = "pool"` `missRate` is nil (FR-008); under a camp bonus
  filter (`bonus = "rack"`, cells with `q = { ["1"] = { c, m, i } }` as in `tests/catchdb/bonus_views_test.lua`) the
  miss rate is the rack part of range `r` only; `QueryMap(1415, f).missRate` and every `QueryCells(1415, f)[i].missRate`
  are nil.
- [X] T008 [US2] In `OneKeyFishing/CatchDB/Views.lua`:
  - add `local function MissRange(filter)` returning `MAX_RANGE` for `"all"` (or a number >= `MAX_RANGE`), else
    `filter.range`;
  - split the miss rate out of `BuildView` into `local function MissNumbers(sum)` returning the cast-weighted misses
    and casts (the present lines 590-600: `castFactors` from `WeightFactors(sum, Players(sum), Casts)`) and the raw
    casts (`RawCatches(sum)` plus `sum.m` plus each part's `m`);
  - `BuildView(scope, sum, rules, missSum)`: when `missSum` is given, `missRate` and `missLittleData` come from
    `MissNumbers(missSum)` (`missLittleData = rawCasts < LITTLE_DATA`); `missRate` stays nil under a water filter
    (`(sum.water or "all") ~= "all"`); without `missSum` both are nil;
  - `CatchDB.Query`: after choosing the scope, build the miss sum over `{ MissRange(filter) }` with the same `sources`
    at the same scope (`SumSpot(sources, mapID, { r }, cell)` or `SumMap(sources, mapID, { r })`); when
    `filter.range == 0` pass the list's sum itself (no second pass);
  - `QueryMap` and `QueryCells` call `BuildView` without `missSum`;
  - update the view comment above `CatchDB.Query` (`missRate`, `missLittleData`; none in `QueryMap` / `QueryCells`).
  T007 passes.
- [X] T009 [US2] Adjust the miss-rate assertions that now read range 4 under `"all"` (research R7), keeping what each
  proves: `tests/catchdb/bonus_views_test.lua` (lines ~135, ~196, ~215), `tests/catchdb/water_test.lua` (lines
  ~51-53, use `QueryMap` -> `Query` where a miss rate is asserted, or the data's range), `tests/catchdb/weights_test.lua`
  (lines ~54, ~66, ~74): query the range the test's cells are in, or move the cells to range 4; `npm test` green.

**Checkpoint**: lists cumulative, miss rate per range; both P1 stories done in the data layer.

---

## Phase 5: User Story 3 - Clear labels and a menu that marks my range (Priority: P2)

**Goal**: the new labels, the "(yours)" mark, the button tooltip, the counts line, no hint (FR-009 to FR-014).

**Independent Test**: rank 180: the menu lists five values with "Up to 224 (yours)"; the button reads "Skill: Up to
224"; its tooltip two lines.

- [X] T010 [P] [US3] Write `tests/ui/here_skill_test.lua` first (model: `tests/ui/here_page_test.lua` for opening the
  tab, `tests/ui/minimap_tooltip_test.lua` for a recording `GameTooltip` stub; find how `ns.OpenRadioMenu` is observed
  in `tests/ui/catalog_sort_test.lua` and reuse it). `fishing_rank = 180`. Assert: the button reads
  `L["Skill: Up to %d"]:format(224)`; the menu's texts in order are `L["Up to %d"]:format(74)`, `(149)`,
  `L["Up to %d (yours)"]:format(224)`, `L["Up to %d"]:format(299)`, `L["All (%d+)"]:format(300)`, the checked one the
  third; choosing the last makes the button `L["Skill: All"]` and it stays after a skill event (hand pick lasts);
  hovering the button records `L["Skill"]`, `L["Catches with skill up to %d."]:format(224)`,
  `L["Misses only with skill %s."]:format("150-224")`, and for "all" `L["Catches with any skill."]` and
  `...:format("300+")`; with a seed cell of 60 catches in range 1 and none in range 2 at the place, the counts line
  ends with `L["Nothing caught: little data"]`; with 100 casts in range 2 it shows `L["Nothing caught: %s"]` and the
  percent; the hint never holds the old "Try ..." text (use `here.hint.text`); a rank-up from 180 to 230 moves an
  untouched default to "Skill: Up to 299"; rank 300 gives "Skill: All" and the "(yours)" on `L["All (%d+) (yours)"]`;
  with no map (`player_map_id = nil`) and rank 180 the menu still marks `L["Up to %d (yours)"]:format(224)` (FR-010);
  with Fishing not learned (no rank) no menu text carries "(yours)".
- [X] T011 [P] [US3] In `OneKeyFishing/UI/Widgets.lua` next to `ns.RangeLabel` (line ~283):
  - `function ns.SkillFilterLabel(value)`: `"all"` -> `L["Skill: All"]`; a number `r` ->
    `L["Skill: Up to %d"]:format((r + 1) * CatchDB.RANGE_STEP - 1)`;
  - `function ns.SkillMenuText(value, own)`: the menu text, `L["Up to %d"]` / `L["All (%d+)"]` (with
    `CatchDB.MAX_RANGE * CatchDB.RANGE_STEP`), or the `"(yours)"` key when `value == own`;
  - `function ns.ShowSkillTooltip(button, value)`: `GameTooltip:SetOwner(button, "ANCHOR_RIGHT")`, `AddLine(L["Skill"])`,
    a white wrapped line `L["Catches with skill up to %d."]` (top as above) or `L["Catches with any skill."]`, a white
    wrapped line `L["Misses only with skill %s."]:format(ns.RangeLabel(miss))` with `miss` = `MAX_RANGE` for `"all"`,
    else `value`; `GameTooltip:Show()` (model: `CatchHere.ShowBonusButtonTooltip`, `UI/CatchHere.lua` ~112);
  - remove the `"all"` branch of `ns.RangeLabel` and update its comment (real ranges only).
  All texts are looked up at call time (no `L[...]` at file load).
- [X] T012 [US3] In `OneKeyFishing/UI/CatchHere.lua`:
  - `EffectiveRange(ownRange)` (~198): `return pickedRange or ns.CatchDB.SkillFilter(ownRange)`;
  - `CatchHere.OpenSkillMenu(owner, current, choose)` (~233): values `0, 1, 2, 3` then `"all"` (`MAX_RANGE` itself
    is not a value), texts `ns.SkillMenuText(value, own)` with `own` from the rank, not the map (research R5):
    `local rank = ns.Skill.Get(); local own = rank and ns.CatchDB.SkillFilter(ns.CatchDB.RangeOf(rank))` (nil
    without Fishing: no mark);
  - the Skill button (~377): `SetScript("OnEnter", function(self) ns.ShowSkillTooltip(self, shown and shown.range
    or "all") end)` and `OnLeave` hiding `GameTooltip`;
  - `Refresh` (~431): `page.skillButton:SetText(ns.SkillFilterLabel(filter.range))`;
  - the counts line (~465): when `view.missRate` is nil show `catches` only; when `view.missLittleData` show
    `catches .. "    " .. L["Nothing caught: little data"]`; else as now;
  - remove the hint `L["Try \"All skill levels\": little data for your skill."]` (~480-482) and the stale comment at
    the `RangeLabel` local (~57; drop the local if unused).
  T010 passes.
- [X] T013 [US3] Adjust `tests/ui/here_page_test.lua` (line ~39 and ~93 `L["Skill: Up to %d"]:format(299)` for rank
  230; line ~96, the rank-up to 300+, now `L["Skill: All"]` instead of "300+"; lines ~99 and ~104, the hand pick of
  the last value, `L["Skill: All"]` too; ~114: assert the hint does not contain "All skill levels" instead) and
  `tests/ui/here_login_test.lua` (~22: `L["Skill: Up to %d"]:format(299)` for rank 230). `npm test` green.

**Checkpoint**: "What can be caught here" complete.

---

## Phase 6: User Story 4 - The catalog and the minimap follow the same rule (Priority: P2)

**Goal**: the catalog's button, menu and tooltip; the minimap lines through the own range (FR-002, FR-003, FR-013,
FR-015).

**Independent Test**: the catalog opens on "Skill: All"; "Up to 149" sums zones and spots; the minimap lines sum up
to the own range.

- [X] T014 [P] [US4] Write `tests/ui/catalog_skill_test.lua` first (model: `tests/ui/catalog_list_test.lua`).
  `fishing_rank = 180`; seed cells in ranges 0, 1 and 3 of one map with three items. Assert: the catalog's Skill
  button reads `L["Skill: All"]` on open; its menu marks `L["Up to %d (yours)"]:format(224)`; choosing "Up to 149"
  lists the items of ranges 0 and 1 only, and an item's page (zones, spots) sums 0 and 1; the item's Skill column
  text is `ns.RangeLabel(min, max)` of where it was caught (unchanged, FR-015); the button tooltip for "all" holds
  `L["Catches with any skill."]`.
- [X] T015 [P] [US4] Done in `tests/catalog/index_test.lua`, next to the other `MinimapLines` tests (the minimap
  tooltip test stubs the tooltip's colours and languages, not the data); the cumulative sum came with T006, so this
  test passed before T017, which only makes 300+ share the `"all"` cache key. Extend the `MinimapLines` tests: in fishing mode at a place with data only in range 1
  and `fishing_rank = 180`, `ns.Catalog.MinimapLines()` lists that item (cumulative up to the own range 2); with rank
  300 it uses `"all"`.
- [X] T016 [US4] In `OneKeyFishing/UI/CatalogTab.lua`: `Refresh` (~404) `page.skillButton:SetText(
  ns.SkillFilterLabel(filter.range))`; the Skill button (~295) gets `OnEnter` -> `ns.ShowSkillTooltip(self,
  filter.range)` and `OnLeave` hiding `GameTooltip`. The menu comes from `CatchHere.OpenSkillMenu` (T012), already
  with "(yours)". `filter` stays `ns.Catalog.DefaultFilter()` (`range = "all"`).
- [X] T017 [US4] In `OneKeyFishing/Catalog/Catalog.lua` `Catalog.MinimapLines` (~729): query with
  `{ range = ns.CatchDB.SkillFilter(range), source = "all", water = "all" }` (the own range through `SkillFilter`, so
  300+ shares the `"all"` cache key). `Catalog.TooltipLines` and `DEFAULT_FILTER` unchanged (FR-003). T014, T015 pass.
- [X] T018 [US4] Adjust `tests/ui/catalog_list_test.lua` (~69: `L["Skill: All"]`; ~200: drop the
  `RangeLabel("all")` assertion or replace it by `ns.SkillFilterLabel("all") == L["Skill: All"]`). Confirm
  `tests/ui/tooltips_test.lua` passes unchanged (SC-006).

**Checkpoint**: both tabs and the minimap follow one rule.

---

## Phase 7: Polish and cross-cutting

- [X] T019 Remove the keys `"All skill levels"`, `"Skill: %s"` and `"Try \"All skill levels\": little data for your
  skill."` from `OneKeyFishing/Locales/enUS.lua` and the nine translations; `grep -rn` the addon and `tests/` for them
  (none left). `npm run check` (it flags a key a translation has and `enUS.lua` lacks) and `npm test` green.
- [X] T020 [P] Documentation, in English (no Cyrillic in Markdown):
  - `CHANGELOG.md` under `## [Unreleased]`: the Skill filter shows the catches of your skill and every lower one;
    the miss rate is that of the chosen range ("little data" below 50 casts); "Up to N" labels with "(yours)";
    "All skill levels" is now "All (300+)";
  - `OneKeyFishing/README.md` (the **Skill** item near line 127, and the catalog's filter text): the new meaning,
    the labels, the miss rate's source, the defaults (own range here, all in the catalog);
  - `docs/architecture/catch-db.md` (views: `Ranges` 0..r, `MissRange`, `missRate` / `missLittleData` only in
    `Query`, `SkillFilter`, `RangeOf`), `docs/architecture/catalog.md` (`MinimapLines` through `SkillFilter`),
    `docs/architecture/ui.md` (the Skill button: label, menu with "(yours)", tooltip; `ns.SkillFilterLabel`,
    `ns.SkillMenuText`, `ns.ShowSkillTooltip` in `UI/Widgets.lua`).
- [X] T021 [P] Write `docs/checklists/skill-filter.md` from the template in `docs/checklists/README.md` and add its row
  there: (1) a character whose range has no data at a place that has lower data: the list is not empty, the button
  "Skill: Up to N"; (2) the menu in both tabs with "(yours)", also inside an instance, none on a character without
  Fishing; (3) the button and its tooltip in German and French (`/okf language` or the setting) fit 150 px, also the
  menu's "(yours)" lines; (4) the other seven languages one after another: "Skill: Up to 224" on the button and "Up
  to 224 (yours)" in the menu fit without being cut (FR-017, SC-005); (5) the counts line with a percent and with
  "little data"; (6) the minimap button's tooltip in fishing mode. Each
  step names what to see; no step repeats an earlier checked one.
- [X] T022 Run `npm run check` and `npm test`; review `git diff` for leftover `"all"` branches of `RangeLabel`, old
  keys, and comments that still say a range is read alone. Hand the in-game checklist to the author (Claude cannot run
  the game).

---

## Dependencies and execution order

- **Phase 1** -> **Phase 2** (T003 needs T002; T004 independent) -> stories.
- **US1 (T005-T006)** depends on no other task (Phase 2 first only for the order). **US2 (T007-T009)** needs US1
  (the cumulative list scope decides where the misses come from). **US3 (T010-T013)** needs T003, T004 and US2
  (`missLittleData`). **US4 (T014-T018)** needs T011 and T012 (the shared menu and helpers).
- **T019** after T012, T013, T016, T018 (no reader of the old keys left). **T020-T022** last.

### Parallel opportunities

- T002 and T004 (different files).
- Within a story, the test-first task [P] can be written while the previous story's last task finishes: T007 beside
  T006, T010 and T011 together, T014 and T015 together.
- T020 and T021 together.

### Parallel example: User Story 3

```text
T010 tests/ui/here_skill_test.lua      (write, see it fail)
T011 OneKeyFishing/UI/Widgets.lua      (helpers)
then T012 OneKeyFishing/UI/CatchHere.lua, then T013 adjust the old UI tests
```

## Implementation strategy

- **MVP**: Phases 1-4 (US1 + US2): the data layer sums cumulatively with an honest miss rate. Not shippable alone,
  because the old labels would then lie ("Skill: 150-224" summing 0-224); US3 must follow before any build.
- **Then** US3 (the labels in "What can be caught here"), US4 (catalog, minimap), Polish.
- One commit per phase or at the end, as the author chooses; no commit or push without the author's word.
