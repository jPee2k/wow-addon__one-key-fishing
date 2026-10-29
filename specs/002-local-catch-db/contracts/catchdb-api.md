# Contract: `ns.CatchDB` and price functions

Module functions used by the UI, the debug report and the tests. Nothing here is called at file load.

## `ns.CatchDB`

| Function | Returns |
| --- | --- |
| `CatchDB.GetVersion()` | number, bumped on every change of the data or the seed state |
| `CatchDB.HasSeed()` | false when the bundled seed is missing, malformed or has no cells |
| `CatchDB.RANGES`, `RANGE_STEP`, `MAX_RANGE` | the skill ranges `{ 0, ..., 4 }`, 75 points each, the last without a top |
| `CatchDB.GetCell(mapID)` | `cell, x, y` of the player on that map (`"x"` without a position) |
| `CatchDB.GetCurrentPlace()` | `mapID, range, cell` of the player now (cell `"x"` without a position), or nil without Fishing |
| `CatchDB.PlaceKey(mapID, range, cell)` | the key string |
| `CatchDB.Query(mapID, cell, filter)` | a view (below); `filter = { range = 0..4 or "all", source = "all" or "mine" }` |
| `CatchDB.Describe()` | lines for `/okf debug` (seed epoch and places, own places, current key, pool detection) |

A view:

```lua
{
  scope = "spot",          -- "spot" | "map" (fallback, FR-012) | "none" (no catches)
  littleData = false,      -- true when the scope has fewer than 50 catches
  catches = 60, misses = 7,
  items = {                -- sorted by chance, highest first
    { itemID = 6291, chance = 0.55, pieces = 1.1, catches = 33 },
  },
}
```

Rules: `Query` sums the cells of the filter (data-model.md "Views"), caches the result per key and filter until
`GetVersion()` changes, and builds the per-map index of the seed once on first use.

## `ns.Prices`

| Function | Returns |
| --- | --- |
| `Prices.Get(itemID)` | copper for value sums: the higher of vendor and auction, vendor on few lots (fewer than 5 pieces or 3 auctions) |
| `Prices.GetAuction(itemID)` | `price, fewLots` or nil; `fewLots` when `quantity < 5` or `lots < 3` |
| `Prices.GetLastScanTime()` | unchanged |

## `ns.IsPoolLoot()`

True when the open fishing loot came from a pool, by the rule the spike finds; returns nil when the game gives no
way to tell (no pool counters are written then).
