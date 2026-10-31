# Architecture: catch catalog

`Catalog/Catalog.lua`: the catch database across every map, for the "Catch catalog" tab and the tooltips. The spec, model
and contracts are in `specs/005-catch-catalog/` (`data-model.md` "Catalog", `contracts/api.md`); the tab itself is
in [ui.md](ui.md), the per-map views it is built from in [catch-db.md](catch-db.md); the in-game checklist is
[catch-catalog.md](../checklists/catch-catalog.md). It owns no frames, so the tooltips use it without the window,
and it sends no message: the tab polls `Catalog.GetVersion()` on the window's tick.

## The index

- One index per filter key (`range|source|water`); the default filter (`all|all|all`) serves the tooltips. An
  index maps item ID -> its places (one per map), made of `CatchDB.QueryMap` views.
- Every read first brings the index up to date (`Freshen`): nothing to do while no `CatchDB.MapStamp` moved
  (`GetStampVersion` short-cuts the comparison); up to `SYNC_MAPS` (4) changed maps are recomputed by the read that
  finds them; more go to frame steps (`C_Timer.After(0)`), each step bounded by `STEP_MS` (3 ms by
  `debugprofilestop`) or `MAPS_PER_STEP` (8) maps where there is no frame clock (the tests), while the stale index
  keeps answering. The state is `"building"` until a complete index exists, then `"ready"`.
- The session's first loading screen (login or `/reload`) builds the default index after `DEFAULT_INDEX_DELAY`
  (10 s), so the tooltips are ready at the first hover.
- Places are ordered by `PlaceBefore`: those with 50 catches or more first, by chance, highest first; then the
  little-data ones by the item's catches; ties by map ID or cell. The same order serves zones, spots and tooltips.
- `Catalog.GetVersion()` grows whenever an index's items or an item's name change.

## Item names

- An item is known once `C_Item.GetItemInfoInstant` and `GetItemNameByID` both answer. The others are asked for
  once per session (`C_Item.RequestLoadItemDataByID`, `NAME_REQUESTS_PER_STEP` = 20 per frame step) and stay out
  of the lists until `ITEM_DATA_LOAD_RESULT` or `GET_ITEM_INFO_RECEIVED` brings the name; items Forever hides
  until found stay unknown (FR-005, [catch-db.md](catch-db.md)).
- Each known item keeps its name in the client's language, its search key (`ns.SearchKey`) and whether it is grey
  (`IsPoor`: quality 0). The sorted list of an index is cached until the version moves.

## Reads

- `Catalog.Items(filter, search)`: `{ itemID, name, zones }` sorted by `ns.CompareText`; known items only, grey ones
  only with search text, and with search text only the names whose key contains it. Returns the state too.
- `Catalog.Places(itemID, filter)`: the zones of an item, `{ mapID, name, chance, catches, itemCatches, players,
  littleData, ranges }`.
- `Catalog.Spots(itemID, mapID, filter)`: the spots of an item on one map from `CatchDB.QueryCells`, `{ cell, name,
  point, area, chance, catches, itemCatches, players, littleData, ranges, pin }`; summed when a zone is expanded
  and kept until the map's stamp moves (`docs/tech-debt.md` items 1 and 2).
- `Catalog.PinTarget(mapID, spot)`: where the game's map pin goes, `{ mapID, x, y }` on the spot's own map, or for
  a Micro map (a cave, a building) on its zone's map through `C_Map.GetWorldPosFromMapPos` and
  `GetMapPosFromWorldPos`; nil without a point (cell `"x"`), without the waypoint API, under the game rule
  `WorldMapTrackingPinDisabled`, where `C_Map.CanSetUserWaypointOnMap` is false (instances) (V30, V33).
- `Catalog.SpotName(spot)`: "Subzone (45, 72)" in the client's language from the cell's area ID
  (`C_Map.GetAreaInfo`), the coordinates alone without a known subzone, "No exact spot" for the cell without a
  position. `Catalog.ZoneName(mapID)`: "Zone - Inner map" for a map inside a zone, "Unknown zone (%d)" without map
  info.
- `Catalog.TooltipLines(itemID)`: the "Caught in" lines, up to three `{ zone, right }` pairs from the default
  index, stale or not; reliable zones first, little-data ones only without any; nil for an item outside the
  database and before any index exists. `Catalog.MinimapLines()`: the likely catches of the current place in
  fishing mode, counted like the "What can be caught here" tab with its defaults; nil outside fishing mode or
  with `settings.tooltipChances` off.
- `Catalog.Find(text)`: the item IDs of the default index whose name contains the text, for `/okf catalog`;
  `Catalog.CommandArg(rest)` turns an item link into its ID.
- `Catalog.Describe()`: lines for `/okf debug`, counts and times only, never an item name.

## Tests

`tests/catalog/index_test.lua` (items, search, order, places, spots, names, tooltips, the name queue),
`tests/catalog/pin_test.lua` (`PinTarget` and the tab's pin flow), `tests/catalog/load_test.lua` (the largest
database: every build step within its bound), `tests/core/fold_test.lua` (the text helpers), `tests/ui/tooltips_test.lua`.
