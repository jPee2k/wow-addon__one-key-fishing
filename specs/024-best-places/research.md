# Research: The Best Places to Farm, and the Three-Level Place List

Decisions for the plan of spec 024. The game and data facts behind them are in
[docs/best-places-research.md](../../docs/best-places-research.md), section 1.

## R1. Gold per hour from the views

- **Decision**: gold per hour = (value of one catch) x (catches per hour), both read from the views `CatchDB`
  already builds:
  - value of one catch = the sum over the view's items of `chance x pieces x price`, with `price = Prices.Get` and
    the items of hidden kinds left out (spec FR-006: hidden kinds count nothing);
  - catches per hour = `3600 x c / t` of the place's raw cells, unfiltered by water or bonus (the cells' casting time
    `t` covers catches and misses, so misses lower the rate).
  The views get the raw number they do not have today: `seconds` (the summed `t`) of the same cells, never weighted;
  a view's `catchesPerHour = 3600 x raw catches / seconds` (nil without time).
- **Rationale**: every cell has `t` (the own catch, other players' records and the seed, which the harvest keeps,
  `tools/harvest.mjs`), but no view sums it today (`AddCounts` adds `c`, `m`, `i`). The water part `p` and the camp
  bonus parts `q` have no `t`, so a filtered view cannot have its own time; the value of a catch comes from the
  filtered items (weighted, as every chance), the pace from the whole place. Under "Pools" or "Bonus catches only"
  the gold is then "if every catch were like these", which is what the filter asks.
- **Alternatives**: a per-item rate from raw pieces over time: rejected, it skips the weighting that keeps one
  forged record from steering a chance; writing `t` into the water and bonus parts: a format change of the exchange
  for an approximation's sake.

**Revised in the reviews (2026-11-23)**: a weighted seed cell's `t` goes with its counted `c`, not its raw `r` (the
harvest scales them together); another player's time and catches are weighted like its catches before the filters
(from five contributions on), and another player's and a seed cell's time count at least 5 s a cast, so one record
cannot set a place's pace.

## R2. Groups sum, never average

- **Decision**: a zone's and a subzone's gold come from their summed cells: the zone from `QueryMap` (its own view),
  a subzone from its spots' sums (catch-weighted value of a catch, summed catches and seconds). A spot from its
  `QueryCells` view.
- **Rationale**: spec FR-001; a busy spot weighs more than a spot fished twice.

## R3. The top 10 and little data

- **Decision**: `BestPlaces.Zones(filter)` ranks every map of `CatchDB.Maps(filter)` that passes Safe for me and
  Continent, has a time (`seconds > 0`) and at least 50 catches (`not view.littleData`), by gold per hour, and keeps
  the first 10. Inside a zone, subzones and spots with little data go last (`PlaceBefore`'s rule, by gold).
- **Rationale**: the author's decisions; `LITTLE_DATA` (50) is the catalog's threshold.

## R4. Zone level: `C_Map.GetMapLevels` (VERIFY)

**Revised 2026-11-23**: the game gave `0 0 0 0` for every zone, and the client has no zone levels (`UiMap.ContentTuningID`,
`AreaTable.ExplorationLevel` are 0). `ZoneLevels` reads `GameData/ZoneLevels.lua` instead, ranges from
LibTouristClassicEra (Riverglades 35-45 matched the game's map); V75 now checks the table. The text below is the
first decision.

- **Decision**: `BestPlaces.ZoneLevels(mapID)` returns `min, max` from `C_Map.GetMapLevels(mapID)` (client export,
  `MapDocumentation.lua`, `MayReturnNothing`), cached per session; a map with no answer (or `0, 0`) has no level and
  is never hidden. Safe for me hides a zone when `min > UnitLevel("player") + 3`; the Level column is red when
  `min > UnitLevel("player")`. `-- VERIFY(V75)`: the call answers for Forever's zone maps with the zone's range.
- **Alternatives**: a table of zone levels in GameData: rejected while the game has the data; it becomes the
  fallback if V75 fails.

## R5. Continent: the map's parents (VERIFY)

- **Decision**: `BestPlaces.Continent(mapID)` walks `C_Map.GetMapInfo(mapID).parentMapID` up to the first map of
  type Continent (`Enum.UIMapType.Continent`, as `CatchDB.GetCurrentPlace` already reads map types) and returns its
  ID; the filter compares with `GameData` constants Kalimdor 1414 and Eastern Kingdoms 1415 (new
  `GameData/Continents.lua`, data only). Unknown: shown only under All. `-- VERIFY(V76)`: Forever's zone maps have
  these continents as parents.
- **Alternatives**: comparing names: forbidden (Principle II).

## R6. Subzone groups (both tabs)

- **Decision**: one function `Catalog.GroupSpots(rows, numbers)`: groups a zone's spot rows by `area` (the cell's
  subzone with the most casts), in the order of the rows' own sort; a group of one is the spot row itself; spots
  without an area form one group "No subzone" (`area = false`); a group row carries the summed `catches`, the
  numbers the caller's `numbers(rows)` sums (the catalog: the item's catch-weighted chance; Best places: R2), and
  `pin` = the pin of its spot with the best chance. Groups are ordered by the same rule as the rows.
- **Rationale**: the author's three levels, no duplicate subzone, the single-spot collapse (clarification 2); one
  function for both tabs, so no duplicate logic.

## R7. The list UI shared by both tabs

- **Decision**: a three-level list in `UI/PlaceList.lua` (new file, `ns.PlaceList`): rows of zone, group and spot
  with an expand mark, an indent per level, a pin button on group and spot rows (the existing pin button with its
  atlas check), the columns given by the tab. `UI/CatalogTab.lua`'s zone/spot drawing moves into it; the catalog
  passes its columns (skill, chance, catches), Best places its own (skill, level, gold per hour, catches).
- **Rationale**: the catalog already draws two levels with a pin button; a third level in two tabs would otherwise
  copy that code twice.

## R8. Filters and their state

- **Decision**: the existing menus (`CatchHere.OpenSkillMenu`, `OpenSourceMenu`, `OpenWaterMenu`, the kind menu, the
  camp bonus menu) are reused; two new radio menus, Safe for me (on/off) and Continent (All, Kalimdor, Eastern
  Kingdoms). Skill, Source, Water and Camp bonus live in the tab's filter table, reset at login (Skill to the own
  range through `CatchDB.SkillFilter`); Safe for me and Continent in `OneKeyFishingCharDB.bestPlaces = { safe = true,
  continent = "all" }` (per character, filled by `ApplyDefaults`, no `DB_SCHEMA` bump), written only by
  `BestPlaces.SetSafe` / `SetContinent`, which fire `SETTINGS_CHANGED("bestPlaces")`.
- **Rationale**: the author's decisions; the project's rule that a setting is written by its module's setter.

## R9. Refresh and cost

- **Decision**: `BestPlaces.Zones` builds its ranking from the `QueryMap` views (cached per map stamp by `CatchDB`)
  on demand, in frame steps like the catalog index when more than `SYNC_MAPS` maps changed, keyed by the filter and
  `CatchDB.GetStampVersion()`, `Prices` (`PRICES_CHANGED`) and the kind choice; the tab polls a version on the
  window's tick, as the catalog tab does. Spots (`QueryCells`) only for an opened zone.
- **Rationale**: about a hundred maps with data; the views are already cached; the frame budget of the catalog
  (3 ms) applies.

## R10. Ways in and texts

- **Decision**: a fourth `pages` row in `UI/StatsFrame.lua` ("Best places", key `best`); minimap menu entries
  "Catalog" (`StatsFrame.OpenCatalog()`) and "Best places" (`StatsFrame.OpenBest()`) after "Statistics";
  `/okf best` in `Core/Commands.lua`. New texts with nine translations: the tab, the menu entries, the filter
  buttons and values, the columns, "No subzone", "Gold per hour", the "*" tooltip line, the tooltip's item lines,
  "Nothing matches the filters."; the continents' names are the game's own (`Catalog.ZoneName` of their map IDs), not
  translations.
