# Data Model: The Best Places to Farm

## View additions (`CatchDB`, layer 2)

Every view of `Query`, `QueryMap` and `QueryCells` gains, from the same cells before the water and bonus filters
(another player's time weighted by its catches before the filters from five contributions on; another player's and
a seed cell's time at least 5 s a cast):

| Field | Meaning |
|---|---|
| `seconds` | summed casting time `t` of the cells |
| `catchesPerHour` | `3600 x catches / seconds` (a weighted seed cell's `c`, scaled with its `t` by the harvest), nil when `seconds` is 0 |

No saved data changes: cells already carry `t`.

## Place numbers (`BestPlaces`, layer 2)

For a zone (`QueryMap` view), a subzone group and a spot (`QueryCells` view):

| Field | Meaning |
|---|---|
| `mapID`, `cell` / `area` | identity (map ID; cell for a spot; area ID or `false` "No subzone" for a group) |
| `catchValue` | sum over shown-kind items of `chance x pieces x Prices.Get(itemID)` (copper) |
| `goldPerHour` | `catchValue x catchesPerHour` (copper per hour); nil without time |
| `unpriced` | share of the catch's pieces whose item has no price (0..1); `*` when >= 0.25 |
| `catches`, `players`, `littleData`, `ranges` | from the view |
| `levels` | zone only: `{ min, max }` or nil (`GameData.ZoneLevels`, V75) |
| `continent` | zone only: continent map ID or nil (V76) |
| `top` | up to 5 `{ itemID, chance, price, share }` by the gold they bring |
| `pin` | spot: `MapPin.Target`; group: the pin of its spot with the best chance |

A group sums its spots: `catches`, `seconds`; `catchValue` weighted by each spot's catches.

## Filter

`{ range, source, water, bonus }` as the other tabs (reset at login; range = own range), plus the per-character
state below. Kinds: the shared `settings.hiddenKinds`.

## Saved (per character)

`OneKeyFishingCharDB.bestPlaces = { safe = true, continent = "all" }`; `continent` is `"all"`, `"kalimdor"` or
`"eastern"`. Written only by `BestPlaces.SetSafe(on)` and `BestPlaces.SetContinent(value)`, which fire
`SETTINGS_CHANGED("bestPlaces")`. Filled by `ApplyDefaults`; no `DB_SCHEMA` bump.

## Game data (layer 0)

`GameData/Continents.lua`: `{ kalimdor = 1414, eastern = 1415 }` (UiMap IDs), data only.

## Rules

- Top list: maps with `seconds > 0`, not `littleData`, passing Safe for me (`levels.min <= level + 3` or no levels)
  and Continent; by `goldPerHour` descending; ties by catches, then map ID; at most 10.
- Inside a zone: groups and spots by `goldPerHour` (catalog: by chance), little data last.
- A group of one spot is that spot's row.
