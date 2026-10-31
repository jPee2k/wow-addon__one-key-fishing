# Contract: module functions added or changed in part 4

Module functions used by the UI, the debug report, the spike and the tests. Nothing here is called at file load
(Principle VI). Shapes are in [../data-model.md](../data-model.md).

## `Data.lua`

| Function | Returns |
| --- | --- |
| `ns.FoldCase(text)` | `text` with ASCII, Latin-1 Supplement (U+00C0-U+00DE except U+00D7) and Cyrillic (U+0400-U+042F) capitals lowered; other bytes unchanged; Lua 5.1 and 5.3 alike |
| `ns.SearchKey(text)` | `ns.FoldCase(CaseAccentInsensitiveParse(text))` when the game has it, else `ns.FoldCase(text)` |
| `ns.CompareText(a, b)` | `strcmputf8i(a, b) < 0` when the game has it, else `ns.SearchKey(a) < ns.SearchKey(b)` |

## `ns.CatchDB` additions and changes

| Function | Returns |
| --- | --- |
| `CatchDB.Query(mapID, cell, filter)` | unchanged, plus `filter.water` (default `"all"`) in the sums and the cache key; `missRate` nil under a water filter |
| `CatchDB.QueryMap(mapID, filter)` | the map's view without the spot fallback (`scope` `"map"` or `"none"`), cached until `MapStamp(mapID)` moves |
| `CatchDB.QueryCells(mapID, filter)` | list of spot views, one per cell of the map with catches under the filter (`cell`, `point`, `area`, items with `ranges`), cached until `MapStamp(mapID)` moves |
| `CatchDB.Maps(filter)` | list of map IDs with any cell under the filter's source (seed, own tables, other records with sharing on; `mine` for "Only mine") |
| `CatchDB.MapStamp(mapID)` | the change stamp of a map (data-model.md) |
| `CatchDB.HasPoolData()` | true once any held cell has a pool part |
| `CatchDB.GetArea(mapID, x, y)` | the area ID of the player's subzone at that position, the explored area whose `GetAreaInfo` name equals `GetSubZoneText()` once both are folded with `ns.FoldCase` (research R4), or nil |

Internal changes: `Settle` writes `a` and bumps the map's stamp; `CheckCell` checks `a`; the sums carry the water
filter, `px`/`py`/`n`, `a` and the per-item ranges; `FISHING_CAST_START` stores the cast's area; the own-cells index.

## `ns.Catalog` (`Catalog.lua`, new)

| Function | Returns |
| --- | --- |
| `Catalog.GetVersion()` | a number that grows whenever an index's items, a name or the pool state change; the tab redraws on it |
| `Catalog.Items(filter, search)` | `items, state`: the sorted list `{ itemID, name, zones }` for the filter and the search text (FR-002 to FR-005); `state` is `"building"` while no complete index exists, else `"ready"` (maybe stale) |
| `Catalog.Places(itemID, filter)` | the item's zones, sorted (FR-007): `{ mapID, name, chance, catches, players, littleData, ranges }` |
| `Catalog.Spots(itemID, mapID, filter)` | the item's spots of one map, sorted (FR-008): `{ cell, name, point, chance, catches, players, littleData, ranges, pin }` with `pin` from `PinTarget` |
| `Catalog.TooltipLines(itemID)` | up to three `{ zone, right }` pairs for the item tooltip (FR-017), or nil when the item is not in the default index or no index exists yet |
| `Catalog.MinimapLines()` | `{ items = { { name, right } }, footer }` for the current place, or nil outside fishing mode or with the setting off (FR-018) |
| `Catalog.ZoneName(mapID)` | the map's name in the client's language; "Zone - Inner map" for a Micro or Dungeon map whose parent is a zone; "Unknown zone (%d)" without map info |
| `Catalog.SpotName(spot)` | "Subzone (45, 72)", "45, 72" without an area, or "No exact spot" for cell `"x"` |
| `Catalog.PinTarget(mapID, spot)` | `{ mapID, x, y }` or nil (data-model.md "Pin target") |
| `Catalog.Find(text)` | the item IDs whose search key contains `ns.SearchKey(text)` (for `/okf catalog`) |
| `Catalog.Describe()` | lines for `/okf debug`: per index the state, maps, items, stale, last build ms, longest step ms; names known, asked, queued |

Every read (`Items`, `Places`, `Spots`, `TooltipLines`) first compares the map stamps: up to 4 changed maps are
recomputed at once, more start the step build unless one is running, and the read answers from the stale index
meanwhile (research R3).

Events it listens to:
- `PLAYER_ENTERING_WORLD`: the first one of the Lua session, a login or a `/reload`, starts the default index after
  10 s; later loading screens do not.
- `ITEM_DATA_LOAD_RESULT` and `GET_ITEM_INFO_RECEIVED`: names.
- `SHARED_DATA_CHANGED`: the pool state is read again.
- `SETTINGS_CHANGED`: `tooltipChances`.

It sends no message.

## `ns.CatalogTab` (`UI/CatalogTab.lua`, new)

| Function | Does |
| --- | --- |
| `CatalogTab.Create(parent)` | builds the page (hidden), like `CatchHere.Create` |
| `CatalogTab.Refresh()` / `CatalogTab.Tick()` | redraws when `Catalog.GetVersion()`, a filter, the search or the chosen item changed; the 1 s tick of the statistics window calls `Tick` |
| `CatalogTab.Show(arg)` | `arg` = item ID: choose it; text: fill the search (and choose the single match); nil: the list |
| `CatalogTab.Pin(target, placeName)` | the pin flow of research R6: the replace question, `SetUserWaypoint`, super tracking, `charDB.pin`, the toast, `OpenWorldMap` out of combat |

## Other modules

| Where | Change |
| --- | --- |
| `UI/StatsFrame.lua` | a third page `{ key = "catalog", label = L["Catch catalog"] }`; `StatsFrame.OpenCatalog(arg)` shows the window on that tab and calls `CatalogTab.Show(arg)` |
| `UI/CatchHere.lua` | the "Water" filter button (only with `CatchDB.HasPoolData()`), `filter.water` in its query, no miss line under a water filter; a click on a known item row calls `StatsFrame.OpenCatalog(itemID)` |
| `UI/ItemHooks.lua` | the catch lines of `Catalog.TooltipLines` for `GameTooltip` and `ItemRefTooltip`, before the gear check |
| `UI/Minimap.lua` | `Catalog.MinimapLines()` after the session line |
| `UI/Settings.lua` | the feature checkbox "Show catch chances in tooltips" (`tooltipChances`) |
| `Core.lua` | defaults `settings.tooltipChances = true`; `statsTab` comment gains `"catalog"` |
| `Commands.lua` | `{ name = "catalog", description = "open the catch catalog (optionally with an item name or link)", run = function(rest) ns.StatsFrame.OpenCatalog(ns.Catalog.CommandArg(rest)) end }`; `Catalog.CommandArg(rest)` turns an item link into its ID, empty text into nil |
| `Debug.lua` | a "Catch catalog" section from `Catalog.Describe()` |
| `Spike.lua` | the "Map pins and areas (V30-V36)" section (research R13) |
| `Share.lua` | `CleanCell` copies `a` |
| `OneKeyFishing.toc` | `Catalog.lua` after `Share.lua`; `UI\CatalogTab.lua` after `UI\CatchHere.lua` |

## `tools/harvest.mjs`

| Function | Change |
| --- | --- |
| `cleanCell` / `checkCell` | copy and check `a` (data-model.md rules) |
| the sums | add `a` per area; keep the 8 largest per cell |
| `scaledCell` | scale `a` by the cast factor, rounded, the sum capped at `c + m` |
| `seedText` | write `a = { [id] = n, ... }` sorted by ID |
| `seedProblems` | check a seed cell's `a` like `checkCell` |
