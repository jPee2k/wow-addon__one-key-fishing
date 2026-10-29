# Data Model: Local Catch Database

All new data is account-wide (`OneKeyFishingDB`). The existing per-character statistics
(`OneKeyFishingCharDB.stats`, `session`) are not changed.

## Place key

`"<mapID>:<range>:<cell>"` (research R2).

| Part | Values | Source |
| --- | --- | --- |
| `mapID` | positive integer | `C_Map.GetBestMapForUnit("player")` at cast start |
| `range` | `0`..`4` | `min(4, floor(rank / 75))`, base fishing rank |
| `cell` | `"00"`..`"99"` (x digit, then y digit) or `"x"` | `C_Map.GetPlayerMapPosition`, 10 by 10 grid; `"x"` without a position |

Validation: matches `^%d+:[0-4]:(%d%d|x)$`. The whole-map view of a map is the sum of every key with that `mapID`
and the chosen range(s), including `"x"`.

## Cell

The same shape in `mine`, in a contribution and (with `k`) in the seed.

```lua
{
  c = 120,                  -- catches
  m = 9,                    -- misses
  t = 2280,                 -- seconds casting (cast start to stop)
  px = 54210, py = 81930,   -- sums of the cast positions in 1/1000 of the map (absent for cell "x")
  i = {                     -- itemID -> { catches containing the item, pieces }
    [6291] = { 64, 71 },
    [6303] = { 41, 41 },
  },
  p = { c = 30, i = { [6291] = { 20, 22 } } }, -- pool catches, already included above; only when pools can
                                                -- be told apart (spike); no misses (a miss has no loot source)
  k = 14,                   -- seed only: number of contributions summed into the cell
}
```

Derived values (not stored):

- chance of an item = `i[id][1] / c` (misses not included, FR-011)
- average pieces = `i[id][2] / i[id][1]`
- miss rate = `m / (c + m)`
- average point = `px / (c + m) / 1000`, `py / (c + m) / 1000` (for 1.4.0)

Validation (addon on write, `harvest` on read): all counts are non-negative integers; `i[id][1] <= c`;
`i[id][1] <= i[id][2] <= 20 * i[id][1]`; `c + m <= t` (a cast lasts at least a second); `px`, `py` within
`0..1000 * (c + m)`; `p` counts not above the totals; item IDs positive integers.

## Saved data

```lua
OneKeyFishingDB.schema = 1            -- unchanged: only new fields, filled by ApplyDefaults
OneKeyFishingDB.statsTab = "stats"    -- "stats" | "here": the last open tab of the statistics window
OneKeyFishingDB.shared = {
  myID = "k7f2q9xa",                  -- 8 random base32 characters, created once per account
  mine = {                            -- lifetime counts of this account, never reset ("Only mine")
    ["1415:3:47"] = cell,
  },
  records = {                         -- contributions; in 1.1.0 only this account's own
    ["k7f2q9xa"] = {
      id = "k7f2q9xa",
      epoch = 3,                      -- seed epoch the record started against
      seq = 41,                       -- grows at most once a minute and on logout
      builds = {                      -- game version -> place key -> cell
        ["1.60.1"] = { ["1415:3:47"] = cell },
      },
    },
  },
}
OneKeyFishingDB.prices[itemID] = {
  price = 21500,                      -- copper: average of the cheapest 20% of listed pieces
  quantity = 140,                     -- pieces listed at scan time, at most those loaded; nil for 1.0.0 prices
  lots = 12,                          -- result rows (price points) on sale; nil for 1.0.0 prices
  time = 1761234567,
}
```

Filter state (skill range, source) is kept in memory only and resets on login (FR-015).

## Seed (`ns.SeedData`)

See [contracts/seed-data.md](contracts/seed-data.md). Absent or invalid seed = empty seed.

## Harvest store (`seed/contributions.json`, repository only)

```json
{
  "epoch": 3,
  "resets": { "1415": "1.60.2" },
  "contributions": {
    "k7f2q9xa@2": { "id": "k7f2q9xa", "epoch": 2, "seq": 41, "builds": { "1.60.1": { "1415:3:47": {} } } }
  }
}
```

`contributions` keeps the newest `seq` per `id@epoch`; `resets` maps a mapID to the first game version whose data
counts for it.

## State transitions

Own contribution record, checked once in `ADDON_LOADED` after the seed is known:

```text
no record                         -> new record { epoch = seed.epoch, seq = 0, builds = {} }
seed.absorbed[myID] >= rec.epoch  -> absorbed: replaced by a new empty record with epoch = seed.epoch
otherwise                         -> kept, counts in "All" next to the seed
```

A cast:

```text
FISHING_CAST_START  -> place key and position read and kept for this cast; always, also for a cast picked up after
                       a /reload (nothing is counted here, so nothing can count twice; t runs from the pickup)
FISHING_CAST_STOP   -> the cast's stop time is kept
FISH_CAUGHT         -> the named cast is settled: c + 1, items added, pool part if the loot came from a pool
FISH_MISSED         -> the named cast is settled: m + 1
(on settling)       -> t + seconds from start to stop (at least 1); px/py + position. A cast never settled (a
                       logout within the second Catch.lua waits for a miss) adds nothing.
```

Both `mine` and the own record (under the current `GetBuildInfo()` version) receive every change; `seq` and the
`CatchDB` version are bumped.

## Views

| Filter | Data summed for a place key |
| --- | --- |
| Source "All" | seed cell + own record cells of every build (cells of maps in `seed.resets` from older builds, and from "unknown", left out) |
| Source "Only mine" | `mine` cell |
| Skill: a range | keys with that range |
| Skill: "All" | keys of ranges 0 to 4 |
| Spot | the current cell key; whole map when it has fewer than 50 catches; "little data" when the map has fewer than 50 too |
