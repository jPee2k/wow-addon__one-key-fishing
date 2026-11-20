# Research: Cumulative Skill Filter

**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md) | **Date**: 2026-11-20

The author's decisions 1 to 9 are in the spec's clarifications; this file settles how the code meets them. Read from
the code of `develop` at `95420ec` (spec 020 merged).

## R1. The filter's values

- **Decision**: the filter's `range` keeps its present type: `0`, `1`, `2`, `3` or `"all"`. `"all"` is the menu's
  "all (300+)": every range for the lists, 300+ (`MAX_RANGE`) for the misses. A number `MAX_RANGE` (4) is never a filter
  value: the own range 4 becomes `"all"` (`CatchDB.SkillFilter(ownRange)`, R5). `Ranges(filter)` in
  `CatchDB/Views.lua` returns `{ 0 .. r }` for a number and `CatchDB.RANGES` for `"all"`; a stray `4` reads like
  `"all"` there, so the minimap's old call cannot break.
- **Rationale**: the catalog's `DEFAULT_FILTER`, its preloaded index, the item tooltips (`IndexFor(DEFAULT_FILTER)`) and
  some forty tests use `"all"`; keeping it means one cache key for "everything" and no second catalog index.
- **Alternatives**: values `0` to `4` with `4` meaning everything (a second key for the same sums next to the default
  index, and every `"all"` in code and tests rewritten).

## R2. The sums of a cumulative range

- **Decision**: only `Ranges(filter)` changes. `SumSpot`, `SumMap` and `MapCells` already loop over a list of ranges,
  so items, catches, players, reporters, the weights (part 3, R7), the camp bonus parts and tags (spec 020) and each
  item's `ranges` (the catalog's Skill column) follow by themselves. `FilterKey` is unchanged (`range|source|water|
  bonus`): `"2"` now names the sums of 0-2.
- **Spot or map**: `Query` keeps its rule (the spot when its summed raw catches reach `LITTLE_DATA`, else the map), now
  on the cumulative sums.
- **Rationale**: one place for one rule (decision 1); nothing in storage, records, the seed or the exchange moves.
- **Alternatives**: a cumulative option per caller (two meanings of the same value in two windows).

## R3. The miss rate of the chosen range

- **Decision**: `CatchDB.Query` sums the chosen range alone at the scope it chose (`SumSpot` or `SumMap` over
  `{ MissRange(filter) }`, where `MissRange` is the range itself, or `MAX_RANGE` for `"all"`), and `BuildView` takes
  that sum as an optional second argument for the miss rate. The miss rate is computed as today (misses and casts
  weighted by casts, part 3 R7) but over that sum; `view.missLittleData` is true when its raw casts (raw catches plus
  misses) are below `LITTLE_DATA`. Under a water filter `missRate` stays nil (FR-022 of the water feature). Under a
  bonus filter the second sum passes `ThroughBonus` like the first (the same `sources`), so the misses are that
  bonus's part in the chosen range.
- **Reuse**: with range `0` the second sum is the first (the same ranges): no second pass.
- **`QueryMap` and `QueryCells`** (the catalog's zone and spot rows, the item tooltips) show no miss rate; their views
  carry `missRate = nil`, so no caller can show a summed miss rate by mistake. Checked: the only reader of `missRate`
  is `UI/CatchHere.lua` through `Query`.
- **The cost**: one more sum of one range per `Query` (cached with the view under the same key); the catalog's index
  is not touched.
- **Rationale**: decision 3; in the collected data lower skill misses more in the same zone (map 1413: 35 / 24 / 15 %
  for ranges 0 / 1 / 2).
- **Alternatives**: misses from the map always (another area than the list); misses summed like the items (a skilled
  player sees beginners' misses).

## R4. Texts

- **Decision**: new keys, each a whole sentence with its number (decision 4, Principle II):
  - button: `"Skill: Up to %d"`, `"Skill: All"`;
  - menu: `"Up to %d"`, `"Up to %d (yours)"`, `"All (%d+)"`, `"All (%d+) (yours)"`;
  - button tooltip: title `L["Skill"]` (exists), then `"Catches with skill up to %d."` or `"Catches with any skill."`,
    and `"Misses only with skill %s."` (`%s` from `ns.RangeLabel`, "150-224" or "300+");
  - the counts line when the chosen range has fewer than 50 casts: `"Nothing caught: little data"`.
  The numbers are the range's top (`(r + 1) * RANGE_STEP - 1`: 74, 149, 224, 299) and `MAX_RANGE * RANGE_STEP`
  (300).
- **Removed**: `"All skill levels"`, `"Skill: %s"` and `"Try \"All skill levels\": little data for your skill."` from
  `enUS.lua` and the nine translations (the check rejects a key a translation has and `enUS.lua` lacks).
- **Kept**: `ns.RangeLabel(min, max)` for the catalog's Skill column and the tooltip's miss range; its `"all"` branch
  goes.
- **Width**: the button stays 150 px; "Skill: Up to 224" is shorter than "Skill: All skill levels" in English, and the
  longest translations are checked in game (checklist).
- **Alternatives**: one `"%s (yours)"` wrapper (word order differs between languages: Principle II wants whole strings).

## R5. Defaults and the own range

- **Decision**: `CatchDB.SkillFilter(range)` (layer 2, next to `RANGES`) turns a skill range (0..4 or nil) into a filter
  value: `nil` and `MAX_RANGE` give `"all"`, the others themselves. `UI/CatchHere.lua` `EffectiveRange` uses it for
  the own range (the hand pick wins, as today, until `/reload`); `Catalog.MinimapLines` uses it for the minimap
  lines. The catalog opens on `"all"` (`DEFAULT_FILTER`, unchanged).
- **The own range from the rank**: `CatchDB.RangeOf(rank)` returns `min(MAX_RANGE, floor(rank / RANGE_STEP))`, or
  nil for a nil rank; `CatchDB.GetCurrentPlace` uses it instead of its inline formula, so a place key and the mark
  can never disagree.
- **"(yours)"**: both menus mark the value `SkillFilter(RangeOf(ns.Skill.Get()))`, read from the rank alone: with
  Fishing learned the mark is there anywhere, also where the game gives no map (an instance, a cave reporting the
  continent; FR-010); without Fishing there is none. `CatchHere.OpenSkillMenu(owner, current, choose)` reads it
  itself, so the two callers stay as they are.
- **Alternatives**: the catalog follows the own range too (rejected by decision 6); the own range from
  `CatchDB.GetCurrentPlace()` (nil without a map: the mark would vanish in an instance although Fishing is learned).

## R6. The hint and the little-data state

- **Decision**: the hint "Try "All skill levels"..." goes (decision 7). The list's `littleData` stays on the summed
  catches; the miss rate has its own `missLittleData` (R3). Nothing replaces the hint.

## R7. Tests that change

- Tests that read a miss rate under `range = "all"` with data outside 300+ (`tests/catchdb/bonus_views_test.lua`,
  `water_test.lua`, `weights_test.lua`) would now get "little data": they choose the data's own range or put the data
  at 300+, so each keeps proving what it proved.
- Tests that read the old labels (`tests/ui/catalog_list_test.lua`, `here_page_test.lua`, `here_login_test.lua`)
  move to the new texts; the hint's assertion in `here_page_test.lua` turns into "no hint".
