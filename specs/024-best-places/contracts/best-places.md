# Contract: Best places, subzone groups, ways in

## CatchDB (layer 2)

| Function | Change |
|---|---|
| `Query`, `QueryMap`, `QueryCells` | each view carries `seconds`, `catchesPerHour` (data-model.md) |

## Catalog (layer 2)

| Function | Contract |
|---|---|
| `Catalog.GroupSpots(rows, sum, before)` | groups spot rows by `area`; a group is `sum(spots)` with `area`, `order`, `spots` and its best spot's `pin`, a one-spot group is the spot row; sorted by `before`; `area = false` is "No subzone" (`Catalog.GroupName`) |

## BestPlaces (layer 2, `Catalog/BestPlaces.lua`, `ns.BestPlaces`)

| Function | Contract |
|---|---|
| `BestPlaces.Zones(filter)` | `zones, state`: up to 10 zone place numbers (data-model.md), ranked; `state` `"building"` / `"ready"` |
| `BestPlaces.Spots(mapID, filter)` | the zone's elements from `Catalog.GroupSpots` with Best places numbers |
| `BestPlaces.ZoneLevels(mapID)` | `min, max` or nil (`-- VERIFY(V75)`) |
| `BestPlaces.Continent(mapID)` | continent UiMap ID or nil (`-- VERIFY(V76)`) |
| `BestPlaces.GetSafe()`, `SetSafe(on)` | per character; the setter fires `SETTINGS_CHANGED("bestPlaces")` |
| `BestPlaces.GetContinent()`, `SetContinent(value)` | `"all"`, `"kalimdor"`, `"eastern"`; same message |
| `BestPlaces.GetVersion()` | grows when a ranking changes; the tab polls it |
| `BestPlaces.FormatGold(copper)` | "12g 30s" per hour text through `ns.FormatMoney` |
| `BestPlaces.Describe()` | lines for `/okf debug` (counts and times, never a name) |

## UI (layer 3)

| Module | Contract |
|---|---|
| `UI/PlaceList.lua` (`ns.PlaceList`) | a scroll list of zone, group and spot rows; `PlaceList.Create(parent, columns)`, `:SetZones(zones, open)`; expand marks, indent, pin buttons on group and spot rows |
| `UI/CatalogTab.lua` | its item's places through `PlaceList` with `Catalog.GroupSpots` |
| `UI/BestPlacesTab.lua` (`ns.BestPlacesTab`) | `Create(f)`, `Refresh`, `Tick`; filters Skill, Safe for me, Kinds, Source, Water, Camp bonus, Continent; tooltip of a row: top 5 items and players; the "*" line |
| `UI/StatsFrame.lua` | fourth page `best`; `StatsFrame.OpenBest()` |
| `UI/Minimap.lua` | entries "Catalog" and "Best places" after "Statistics" |
| `Core/Commands.lua` | `best`: "open the best places to fish" |

## Message

None new. `SETTINGS_CHANGED("bestPlaces")` is a new key of an existing message (listed in CLAUDE.md with the other
setters).
