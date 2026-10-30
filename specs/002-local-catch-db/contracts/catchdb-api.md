# Contract: `ns.CatchDB` and price functions

Module functions used by the UI, the debug report, Share.lua and the tests. Nothing here is called at file load.

## `ns.CatchDB`

| Function | Returns |
| --- | --- |
| `CatchDB.GetVersion()` | number, bumped on every change of the data or the seed state |
| `CatchDB.HasSeed()` | false when the bundled seed is missing, malformed or has no cells |
| `CatchDB.RANGES`, `RANGE_STEP`, `MAX_RANGE` | the skill ranges `{ 0, ..., 4 }`, 75 points each, the last without a top |
| `CatchDB.GetCell(mapID)` | `cell, x, y` of the player on that map (`"x"` without a position) |
| `CatchDB.GetCurrentPlace()` | `mapID, range, cell, x, y` of the player now (cell `"x"` and no `x, y` without a position), or nil without Fishing or a map |
| `CatchDB.PlaceKey(mapID, range, cell)` | the key string |
| `CatchDB.Query(mapID, cell, filter)` | a view (below); `filter = { range = 0..4 or "all", source = "all" or "mine" }` |
| `CatchDB.Describe()` | lines for `/okf debug` (seed epoch and places, own places, current key, pool detection, game version key) |
| `CatchDB.SeedInfo()` | `epoch, places` of the bundled seed, for `/okf share` and `/okf debug` |
| `CatchDB.SeedEpoch()` | the seed's epoch (0 for a missing or malformed seed) |
| `CatchDB.SeedAbsorbed()` | the seed's `absorbed` table: ID -> `{ [epoch] = seq }` |
| `CatchDB.AbsorbedSeq(id, epoch, absorbed)` | the seq up to which the seed (or the given `absorbed` table) holds unit `<id>@<epoch>`, or nil |
| `CatchDB.IsAbsorbed(id, epoch, seq, absorbed)` | true when the seed holds this version of the unit whole (`seq` not above the held seq) |
| `CatchDB.UnitKey(id, epoch)` | the key `"<id>@<epoch>"` other players' records and rolled own records are stored under |
| `CatchDB.ParseUnit(unit)` | `id, epoch` of a `"<id>@<epoch>"` key (nil for anything else) |
| `CatchDB.IsOtherKey(key)` | true for a `"<id>@<epoch>"` key (the live own record is stored under its bare ID) |
| `CatchDB.IsBuild(build)` | true for a game version key such as `"1.60.1"` (not `"unknown"`) |
| `CatchDB.HasCells(record)` | true when the record has at least one cell (an empty one is neither kept on a roll nor offered) |
| `CatchDB.FlushSeq()` | bumps a waiting seq change of the own record (at logout and before the record goes to a peer) |
| `CatchDB.CountPlaces(record, limit)` | distinct places over all builds of a record; counting stops above `limit` |
| `CatchDB.CheckRecord(record)` | `true`, or `false, reason` for a record received from another player; a third value `true` when the only fault is an item unknown to this client |
| `CatchDB.IsCount(value)` | true for a whole number from 0 to 10^12 |
| `CatchDB.ID_LENGTH` | 8, the length of an account's base32 ID |

A view:

```lua
{
  scope = "spot",          -- "spot" | "map" (fallback, FR-012) | "none" (no catches)
  littleData = false,      -- true when the scope has fewer than 50 catches
  catches = 60, misses = 7,
  players = 3,             -- contributions behind the numbers (below)
  items = {                -- sorted by chance, highest first
    { itemID = 6291, chance = 0.55, pieces = 1.1, catches = 33 },
  },
}
```

Rules: `Query` sums the cells of the filter (data-model.md "Views"), caches the result per key and filter until
`GetVersion()` changes, and builds the per-map index of the seed once on first use.

`players` counts the records with a summed cell that has catches (a cell of misses only adds no player), each ID
once, plus the seed's largest `k` among the summed cells. An ID the seed absorbed may already be among that `k`, so
those IDs count only above it: `players = max(seed k, absorbed IDs) + IDs the seed never absorbed`. Where the seed
cannot tell, it is a lower bound, never an overcount. The tab shows "from K players" from 2 on.

## `ns.Prices`

| Function | Returns |
| --- | --- |
| `Prices.Get(itemID)` | copper for value sums: the higher of vendor and auction, vendor on few lots (fewer than 5 pieces or 3 auctions) |
| `Prices.GetAuction(itemID)` | `price, fewLots` or nil; `fewLots` when `quantity < 5` or `lots < 3` |
| `Prices.GetLastScanTime()` | unchanged |

## `ns.IsPoolLoot()`

True when the open fishing loot came from a pool, by the rule the spike finds; returns nil when the game gives no
way to tell (no pool counters are written then).
