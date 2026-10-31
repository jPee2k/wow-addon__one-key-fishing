# Data Model: Catch Catalog, Map Pins and Catch Chances in Tooltips

Changes to the data of parts 1 to 3 (`specs/002-local-catch-db/data-model.md`,
`specs/003-guild-group-sync/data-model.md`, `specs/004-public-channel-sync/data-model.md`) and the session state of
the catalog. Nothing is renamed or reshaped, so `DB_SCHEMA` stays 1 and `ApplyDefaults` fills the new fields.

## Cell (changed): the subzone counts `a`

```lua
["1415:3:47"] = {
  c = 60, m = 7, t = 1340, px = 30150, py = 47290, i = { ... }, p = { ... },
  a = { [1519] = 52, [1617] = 15 }, -- NEW: area ID -> settled casts made in that area (research R4)
}
```

| Rule | Where it is checked |
| --- | --- |
| `a` is absent or a table of at most 8 entries | `CatchDB.CheckRecord` (`CheckCell`), harvest `checkCell`, `seedProblems` |
| every key is a whole number from 1 to 2,147,483,647 (a game area ID) | the same |
| every count is a count (`IsCount`), and their sum is at most `c + m` | the same |
| written only for casts with a position (never for cell `"x"`) and only when the area was found (V34) | `CatchDB.Settle` |
| a ninth area of a cell is not added (the counts of the eight stay) | `CatchDB.Settle`; the harvest keeps the 8 largest when sums would exceed 8 |

Where it lives: `shared.mine`, the own record's builds, other players' records (`Share` copies it field by field in
`CleanCell`), `seed/contributions.json` (unchanged contributions) and `SeedData.lua` cells (the summed counts, scaled
by the cast factor where the harvest weights a cell, research R7 of part 3).

## Saved data (new fields)

| Field | Table | Default | Meaning |
| --- | --- | --- | --- |
| `settings.tooltipChances` | `OneKeyFishingDB` | `true` | "Show catch chances in tooltips": the item tooltip lines and the minimap lines (FR-019) |
| `statsTab` | `OneKeyFishingDB` | `"stats"` | gains the value `"catalog"` |
| `pin` | `OneKeyFishingCharDB` | nil | `{ mapID, x, y }`: the map pin as the addon last set it (FR-012), x and y in 0..1; nil once the addon never set one |

Filters, the search text, the chosen item and the expanded zones are never saved (FR-006, FR-023).

## Views (changes to `CatchDB`)

`filter = { range = 0..4 | "all", source = "all" | "mine", water = "all" | "open" | "pool" }`; a missing `water` is
`"all"`, so every caller of part 1 keeps working.

A sum reads each cell through the water filter (research R5):

| Water | Catches | Items | Misses | Players |
| --- | --- | --- | --- | --- |
| `"all"` | `c` | `i` | `m` | contributions with `c > 0` |
| `"pool"` | `p.c` (0 without `p`) | `p.i` | 0 | contributions with `p.c > 0` |
| `"open"` | `c - p.c` | `i - p.i` (per item: catches and pieces) | 0 | contributions with open catches |

The pool part is counted in `c` and `i` too, so `CatchDB.CheckRecord` and the harvest refuse a cell whose `p.i` has an
item missing from `i` or with more catches or pieces than `i` gives it: open water never goes below 0.

A view (part 1 shape) gains:

| Field | In | Meaning |
| --- | --- | --- |
| `missRate` | all | nil under `"open"` and `"pool"` (a miss has no loot source) |
| `point` | spot views | `{ x, y }` in 0..1: `px / n / 1000`, `py / n / 1000` over the summed cells with positions (`n` = their casts); nil for cell `"x"` |
| `area` | spot views | the area ID with the most casts in the summed `a` (others' parts scaled by the cast factor), ties to the lower ID; nil without areas |
| `items[].ranges` | all | `{ min, max }`: the lowest and highest skill range in which the item was caught in the scope (the "skill span" of FR-007 and FR-008) |
| `cell` | spot views | the grid cell (`"00"`..`"99"` or `"x"`) |

New view functions (contracts/api.md): `CatchDB.QueryMap(mapID, filter)` (scope `"map"` or `"none"`, no fallback),
`CatchDB.QueryCells(mapID, filter)` (one spot view per cell of the map that has catches under the filter, keys of the
filter's ranges summed per cell), `CatchDB.Maps(filter)` (map IDs with data under the source), `CatchDB.HasPoolData()`.

## Change stamps (session memory, `CatchDB`)

| Value | Bumped by |
| --- | --- |
| `stamps[mapID]` | a settled cast on that map; `SHARED_DATA_CHANGED` with keys, for every map of the named records' entries before and after the change |
| `globalStamp` | login (`ADDON_LOADED`), `SHARED_DATA_CHANGED` without keys (sharing switched, a store rebuilt) |

`CatchDB.MapStamp(mapID)` returns `globalStamp .. ":" .. (stamps[mapID] or 0)`. The own-cells index (own table keys by
`<mapID>:<range>`) is built with the first map sum and grown by `Settle`.

## Catalog (session memory, `Catalog.lua`)

```lua
indexes = {                    -- at most two: the default filter and the latest other one
  ["all|all|all"] = {
    filter = { range = "all", source = "all", water = "all" },
    maps = { [1415] = { stamp = "3:17", view = <QueryMap view> } },
    items = { [6291] = { { mapID = 1415, item = <view item>, view = <the map's view> }, ... } }, -- by chance
    state = "ready",           -- "empty" | "building" | "ready"; stale = some map's stamp moved since
    version = 12,              -- grows with every change of `items`; the tab redraws when it moves
    builtMs = 41, longestStepMs = 2.8,
  },
}
spots = { ["1415|all|all|all"] = { stamp = "3:17", views = { <QueryCells views> } } } -- the expanded zone's map
names = { [6291] = { name = "Deviate Fish", key = "deviate fish", quality = 1, known = true } }
asked = { [6291] = true }      -- name requests sent this session
queue = { 6293, 6294 }         -- name requests waiting, 20 per frame step
```

Rules:
- An item is in a filter's list when some map view of the index lists it (part 3's rules for new items apply there),
  the item is known, and (no search text) its quality is not Poor, or (search text) its search key contains the
  folded text.
- The list is sorted by name (`strcmputf8i`, else the search keys). An item's maps and spots: the reliable ones
  (scope catches 50 or more) first, by chance, highest first; then the little-data ones by the item's catches (their
  chance is not shown); ties by map ID or cell. The tooltip's fallback zones follow the same order.
- The default index answers the tooltips; any index is used stale while its rebuild runs.
- Every read (`Items`, `Places`, `Spots`, `TooltipLines`) first compares the map stamps: up to `SYNC_MAPS` (4)
  changed maps are recomputed at once, more start the step build unless one is running.

## Pin target (computed, never saved)

`Catalog.PinTarget(mapID, spotView)` -> `{ mapID, x, y }` or nil:

```text
no spot point, or no waypoint API, or game rule WorldMapTrackingPinDisabled active  -> nil
  (a missing Enum.GameRule value skips the rule check)
CanSetUserWaypointOnMap(mapID)                                                      -> { mapID, point }
map type Micro, parent allows pins, world position converts into the parent's 0..1  -> { parent, converted point }
otherwise (instances, dungeons, orphan maps)                                        -> nil
```

## State transitions

```text
Catalog index:   empty --first PLAYER_ENTERING_WORLD of the session + 10 s, or a read--> building --last map--> ready
                 ready --a map's stamp moved--> ready (stale) --a read: 1-4 maps at once / more: steps--> ready

Pin button:      pressed --no waypoint, or the addon's own--> set
                 pressed --another waypoint--> question --Replace--> set ; --Cancel--> nothing
                 set: SetUserWaypoint true --> super track on, charDB.pin, toast, map (not in combat)
                      SetUserWaypoint false --> toast "The game did not accept the map pin."

Item name:       unknown --first need--> queued --step--> asked --ITEM_DATA_LOAD_RESULT success--> known
                 asked --never answered--> stays unknown for the session (hidden, FR-005)
```
