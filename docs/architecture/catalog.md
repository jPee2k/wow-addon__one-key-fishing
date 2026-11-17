# Architecture: catch catalog

`Catalog/Catalog.lua`: the catch database across every map, for the "Catch catalog" tab and the tooltips. The spec,
model and contracts are in `specs/005-catch-catalog/` (`data-model.md` "Catalog", `contracts/api.md`); the tab itself is
in [ui.md](ui.md), the per-map views it is built from in [catch-db.md](catch-db.md); the in-game checklist is
[catch-catalog.md](../checklists/catch-catalog.md). It owns no frames, so the tooltips use it without the window,
and it sends no message about its data: the tab polls `Catalog.GetVersion()` on the window's tick. Its two messages
are settings': `SETTINGS_CHANGED("hiddenKinds")` from `Catalog.SetKindShown` (spec 014, "Item kinds" below) and
`SETTINGS_CHANGED("catalogSort")` from `Catalog.SetSort` (spec 017, "List order" below).

## The index

- One index per filter key (`range|source|water`); the default filter (`all|all|all`; `Catalog.DefaultFilter()` gives
  the tab a copy) serves the tooltips. An
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

- `Catalog.Items(filter, search)`: `{ itemID, name, zones, chance, littleData }` (`chance` and `littleData` of the
  item's best place, the first of `Places`) in the saved order ("List order" below; by `ns.CompareText` by default);
  known items only, grey ones only with search text, and with search text only the names whose key contains it.
  Returns the state too.
- `Catalog.Places(itemID, filter)`: the zones of an item, `{ mapID, name, chance, catches, itemCatches, players,
  littleData, ranges }`.
- `Catalog.Spots(itemID, mapID, filter)`: the spots of an item on one map from `CatchDB.QueryCells`, `{ cell, name,
  point, area, chance, catches, itemCatches, players, littleData, ranges, pin }`; summed when a zone is expanded
  and kept for the session, until the map's stamp moves.
- A spot's `pin` is `ns.MapPin.Target({ mapID }, x, y)` (`Core/MapPin.lua`, [core.md](core.md)): `{ mapID, x, y }`
  on the spot's own map, or for a Micro map (a cave, a building) on its zone's map through the world position; nil
  without a point (cell `"x"`), without the waypoint API, under the game rule, and in instances (V30, V33).
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

## Item kinds

`specs/014-catch-filters`: both lists ("What can be caught here" and the catalog's) are grouped by kind, and the
player may hide kinds.

- `Catalog.KINDS` = `fish`, `containers`, `potions`, `reagents`, `other`, in display order; `Catalog.KindText(kind)`
  is the translated name, looked up when drawn.
- `Catalog.ItemKind(itemID)`: `GameData.ItemKinds.byItem` by ID, else `byClass` by the class numbers of
  `C_Item.GetItemInfoInstant` (`"<class>:<subclass>"`, then `"<class>"`), else `"other"` (also for an item the
  client does not know yet). Never by name or quality; not cached, so an item learned in the session moves at the
  next draw ([game-data.md](game-data.md)).
- `Catalog.Group(items)`: `list, hiddenCount`; `list` is what both tabs draw: `{ header = kind }` before each shown
  kind's rows, in `KINDS` order, no header for an empty or hidden kind, the rows in their input order (not copied);
  `hiddenCount` counts the rows of hidden kinds.
- The choice: `settings.hiddenKinds` (hidden kind -> true, account-wide), read by `IsKindShown` and `ShownKinds`,
  written only by `SetKindShown`, which fires `SETTINGS_CHANGED("hiddenKinds")` when it changed; a saved name that
  is no kind is ignored, a kind the set does not name is shown.
- The filter applies to finished lists only: the views, their sums, their cache keys (`CatchDB.FilterKey`) and the
  indexes never see it, so a shown item's chance, pieces, price and players are the same whatever is hidden, and a
  click costs no index rebuild (research R2 of spec 014). `Places`, `Spots`, `TooltipLines` and `MinimapLines`
  ignore it; `Describe` ends with `kinds hidden: ...`.

## List order

`specs/017-catalog-sort`: the catalog's item list in one of three orders, chosen with the tab's Sort button.

- `Catalog.SORTS` = `name`, `price`, `chance` (the menu's order); `Catalog.SortText(sort)` is the translated name,
  looked up when drawn.
- The choice: `settings.catalogSort` (account-wide, `"name"` by default), read by `Catalog.GetSort()` (a value that is
  no order, a later version's, reads `"name"` and is not rewritten), written only by `Catalog.SetSort(sort)`, which
  fires `SETTINGS_CHANGED("catalogSort")` when it changed.
- `Catalog.Items` sorts the list it returns (`SortRows`), after the search and the grey rule: by name as before; by
  price `ns.Prices.Get` (the statistics' value: vendor or a trusted auction price, the higher), highest first, no
  price (0) last; by chance the best place's `chance`, highest first, the rows whose best place has little data
  after the others. Ties keep the order by name; the rows are the index's tables, not copied.
- Prices are read on every call, once per row (not in the comparator), never cached: a scan moves them without moving
  `Catalog.GetVersion()`, and the tab redraws on `PRICES_CHANGED` and `SETTINGS_CHANGED` through its tick (by price
  also on `GET_ITEM_INFO_RECEIVED` of a listed item: a vendor price may arrive after the draw, as on the other tabs).
  `Group` keeps the order inside each kind; `Find`, `Places`, `Spots` and the tooltips ignore the choice.

## Tests

`tests/catalog/sort_test.lua` (the saved order, by price, by chance, ties, a search, a skill filter),
`tests/catalog/kinds_test.lua` (the kinds, the seed coverage, `Group`, the choice),
`tests/catalog/index_test.lua` (items, search, order, places, spots, names, tooltips, the name queue),
`tests/catalog/spot_pin_test.lua` (a spot's pin target and the pin button; the pin itself is tested in
`tests/core/pin_target_test.lua` and `pin_set_test.lua`), `tests/catalog/load_test.lua` (the largest
database: every build step within its bound), `tests/core/fold_test.lua` (the text helpers),
`tests/ui/tooltips_test.lua`.
