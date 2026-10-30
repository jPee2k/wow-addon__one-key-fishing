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
- average point = `px / (c + m) / 1000`, `py / (c + m) / 1000` (for part 4)

Validation (addon on write, `harvest` on read): all counts are non-negative integers; `i[id][1] <= c`;
`i[id][1] <= i[id][2] <= 20 * i[id][1]`; `c + m <= t` (a cast lasts at least a second); `px`, `py` within
`0..1000 * (c + m)`; `p` counts not above the totals; item IDs positive integers.

## Saved data

```lua
OneKeyFishingDB.schema = 1            -- unchanged: only new fields, filled by ApplyDefaults
OneKeyFishingDB.statsTab = "stats"    -- "stats" | "here": the last open tab of the statistics window
OneKeyFishingDB.shared = {
  myID = "k7f2q6xa",                  -- 8 random base32 characters, created once per account
  mine = {                            -- lifetime counts of this account, never reset ("Only mine")
    ["1415:3:47"] = cell,
  },
  records = {                         -- contributions
    ["k7f2q6xa"] = {                  -- the live own record, under the bare ID
      id = "k7f2q6xa",
      epoch = 3,                      -- the next epoch when the record started (Rolling the own record)
      seq = 41,                       -- see "seq" below
      builds = {                      -- game version -> place key -> cell
        ["1.60.1"] = { ["1415:3:47"] = cell },
      },
    },
    ["k7f2q6xa@2"] = record,          -- an own record a roll kept (with seen), never changed again
    ["p7d2m4qa@5"] = record,          -- another player's record (Share.lua, specs/003-guild-group-sync), with seen
  },
}
OneKeyFishingDB.prices[itemID] = {
  price = 21500,                      -- copper: average of the cheapest 20% of listed pieces
  quantity = 140,                     -- pieces listed at scan time, at most those loaded; nil for 1.0.0 prices
  lots = 12,                          -- result rows (price points) on sale; nil for 1.0.0 prices
  time = 1761234567,
}
```

`seq` of the own record: a change bumps it when the last bump is a minute old or more, otherwise the change waits; a
waiting change is bumped at logout, on a roll and before the record goes to a peer (`CatchDB.FlushSeq`), so a record
always has a seq for all its cells. A cast under `"unknown"` does not bump it.

Filter state (skill range, source) is kept in memory only and resets on login (FR-015).

## Seed (`ns.SeedData`)

See [contracts/seed-data.md](contracts/seed-data.md). Absent or invalid seed = empty seed.

## Harvest store (`seed/contributions.json`, repository only)

```json
{
  "epoch": 3,
  "resets": { "1415": "1.60.2" },
  "contributions": {
    "k7f2q6xa@2": { "id": "k7f2q6xa", "epoch": 2, "seq": 41, "builds": { "1.60.1": { "1415:3:47": {} } } }
  }
}
```

`contributions` keeps the newest `seq` per `id@epoch`; `resets` maps a mapID to the first game version whose data
counts for it.

## State transitions

Own contribution record, checked once in `ADDON_LOADED` after the seed is known:

```text
no record or a damaged one         -> new record { epoch = next epoch, seq = 0, builds = {} }
seed.absorbed[myID][rec.epoch] = S -> the record rolls (below): kept when rec.seq > S, dropped otherwise
otherwise                          -> kept, counts in "All" next to the seed
```

### Rolling the own record

A roll starts a new own record `{ epoch = next epoch, seq = 0, builds = {} }`; the next epoch is the seed's epoch,
or one above the highest epoch of the own ID still held when that is higher, so every unit of the own ID is new. The
old record, its waiting seq bump done first, stays in `shared.records` under `"<myID>@<epoch>"` unless it is empty
or the seed holds it whole (`seq <= S`): it never changes again, goes to peers like another player's record (only
when a peer would take it), is never evicted, and reaches the seed through the author's harvest, which then names it
with its seq and every client deletes it. A kept record counts in "All" like the live one (also with sharing off),
unless the seed holds it in part: then only the seed counts (no catch twice; the part after S counts after the next
release). A roll happens:

- at login, when the seed names the own unit (the author's harvest read it, maybe at an older seq than the owner's:
  the catches after that seq are not lost, they go to the next harvest);
- before a catch at a place new to an own record that already has 500 places (`ROLL_PLACES`): a peer takes a
  record of up to 1,000 places and 32 KB encoded, and a record nobody takes would never reach the seed.

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

Both `mine` and the own record (under the current `GetBuildInfo()` version) receive every change; the `CatchDB`
version is bumped, and `seq` too unless the version is `"unknown"`: that build never goes to a peer
(`Share.Store.ForSending` leaves it out), and a peer refuses a `seq` above the casts it gets.

## Views

| Filter | Data summed for a place key |
| --- | --- |
| Source "All" | seed cell + cells of every build of the own record and of the own records a roll kept, unless the seed holds them in part + with `settings.shareDB` on, cells of other players' records (not those the seed holds in part); cells of maps in `seed.resets` from older builds, and from "unknown", left out |
| Source "Only mine" | `mine` cell |
| Skill: a range | keys with that range |
| Skill: "All" | keys of ranges 0 to 4 |
| Spot | the current cell key; whole map when it has fewer than 50 catches; "little data" when the map has fewer than 50 too |
