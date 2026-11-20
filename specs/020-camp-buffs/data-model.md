# Data Model: Fishing Camp Buffs

**Feature**: [spec.md](spec.md) | **Research**: [research.md](research.md)

The spec's "condition" is a **bonus** here and in the code; a combination of active bonuses is a **mask**.

## Game data (`GameData/CampBonuses.lua`, layer 0, data only)

```lua
GameData.CampBonuses = {
    { key = "rack", bit = 1, aura = 1280341, item = 279965, items = { [6643] = true, ... } }, -- Fishing Rack
    { key = "hut", bit = 2, aura = 1280342, item = 279966, items = {} },                      -- Fishing Hut
}
```

| Field | Meaning |
|---|---|
| `key` | the bonus's name in filters and code: `"rack"`, `"hut"` |
| `bit` | its bit in a mask: 1, 2; the next bonus takes 4 |
| `aura` | the player aura's spell ID ("Uncommon Fishing", "Rare Fishing") |
| `item` | the camp feature's item ID, for the tag's icon |
| `items` | the known bonus items (item ID -> true): the twelve Bloated fish for the Rack, none yet for the Hut |

The list's order is the rank: a later entry is the higher bonus (the Hut over the Rack, FR-018).

`GameData.Lures[291005] = { bonus = 60, order = 4, skill = 50 }` (Camper's Lure); the three weaker lures move to
orders 5, 6, 7.

## Saved data

| Field | Scope | Change | Notes |
|---|---|---|---|
| a cell's `q` | account: `shared.mine[key]`, `shared.records[id].builds[build][key]`; the seed's `cells[key]` | new, optional | the bonus parts, below |
| `OneKeyFishingDB.settings.campBonusWarning` | account | new, `true` by default (`ApplyDefaults`) | the notices of R10 |
| a statistics bucket's `bonusCasts`, `bonusCatches` | character: `charDB.session`, `charDB.stats.total`, `charDB.stats.zones[key]` | new, read as 0 when missing | R12 |

No `DB_SCHEMA` bump and no migration: only added fields. A cell without `q` is "bonus not known" (FR-013).

### The bonus parts of a cell

```
cell = { c, m, t, px, py, i, a, p,
         q = { ["<mask>"] = { c = <catches>, m = <misses>, i = { [itemID] = { <catches>, <pieces> } } } } }
```

- The key is the mask as a **string**, `tostring(mask)`: `"1"` the Rack, `"2"` the Hut, `"3"` both (research R4).
- In the seed only, a part may also carry `k`, `r` and `x`, written by the harvest with the cell's rules over the
  part's own contributions (research R15); records never carry them.
- **Disjoint**: a cast is in at most one part.
- **Inclusive**: a part's catches, misses and items are also in the cell's `c`, `m` and `i`.
- A part exists only once a cast was written to it.

Validation (a received record, `CatchDB/Checks.lua`; the harvest, `tools/harvest.mjs`):

| Rule | Reason on failure |
|---|---|
| `q` is a table with at most 8 parts | "the bonus parts are not a table" / "too many bonus parts" |
| a key is a string, the decimal text of a whole number from 1 to 255 with no leading zero | "bonus part <key>: not a mask" |
| a part is a table; its `c` and `m` are counts; its items pass the item rules against its `c` | "bonus part <key>: " and the rule's reason |
| the parts' `c` sum to at most `cell.c`, their `m` to at most `cell.m` | "the bonus parts do not fit the totals" |
| every item of a part is in `cell.i`, and the cell minus the parts passes the item rules | "no bonus: " and the rule's reason |

A mask with bits this version does not know (4 and above) is valid and kept.

## Session state (`Fishing/Camp.lua`, not saved)

| Name | Meaning |
|---|---|
| `state[key] = { known, expires }` | `known`: read at least once this session; `expires`: the game clock time the buff ends, nil when not active |
| `castMasks[castID]` | the mask at that cast's start, or `false` when it was unknown; dropped when a later cast settles, or when more than eight casts old |
| `tracked[key]` | the `expires` of the buff the last check saw active; cleared at its end, so the end passes once |
| `seen[key]` | the seconds left at the last check of that buff (when first seen: its seconds left then), for the crossings; once at or below 300 the five-minute crossing cannot pass again for that buff |
| `lastMask` | the mask `CastMask` last answered (the debug report) |

### State of a bonus

```
unknown      not read yet this session (a login or reload inside a fight)
active       known, expires set, GetTime() < expires
not active   known, and expires nil or passed
```

Transitions: a read while auras are not restricted sets `known` and `expires`; the clock ends an active bonus;
nothing else changes the state. Reads: `PLAYER_ENTERING_WORLD`, `UNIT_AURA` of the player,
`PLAYER_REGEN_ENABLED`, `FISHING_CAST_START`, and a notice timer that comes due.

### The mask of a cast

```
Mask()            nil when any bonus is unknown; else the sum of the bits of the active bonuses (0: none)
CastMask(castID)  the start mask, when it is a number and equals Mask() now; else 0
```

`CastMask(castID)` drops the kept masks of casts before `castID` and keeps `castID`'s: a miss is settled a second
after its cast stopped, when the next cast may have started, and two modules ask for the same cast.

## Derived values (`CatchDB/Views.lua`)

### A cell through the bonus filter

| `filter.bonus` | The cell counted |
|---|---|
| `"all"` | the cell |
| a key | `c`, `m`, `i` summed over the parts whose mask has the key's bit |
| `"none"` | the cell's `c`, `m`, `i` minus all its parts |

With `bonus ~= "all"` the water filter is read as `"all"`. The filter's cache key: `range|source|water|bonus`.

### The value "bonusOnly" (UI and catalog only)

"Bonus catches only" (research R20) is a filter of the list, not of the sums: no cell is counted differently and it
never reaches `CatchDB`, so `FilterKey` and the views know only `"all"`, `"none"` and the bonus keys.

| Where | What `"bonusOnly"` becomes |
|---|---|
| "What can be caught here" (`UI/CatchHere.lua`) | the tab's value; the query gets `bonus = "all"` (`CatchHere.QueryBonus`), and the view's items are narrowed to those whose `item.bonus` is not `plain` (`CatchHere.BonusItems`) |
| the catalog (`Catalog/Catalog.lua`) | `IndexFilter` turns it into the filter of `"all"` before `FilterKey`, so the index of "All catches" serves it (no index of its own); `Catalog.Items` keeps the rows whose `bonus` is not `plain`; `Places` and `Spots` read that index unchanged |

It lives in memory per tab like the other values, and is offered whenever the filter shows.

### A view item's bonus

```
item.bonus = nil                                              an ordinary item
item.bonus = { key, chance, littleData, catches, players }    a tagged item: an "all" view, or its own bonus's view
item.bonus = { key, littleData = true, catches = 0, players = 0 }   a known item, no data under its bonus ("all")
item.bonus = { key, plain = true }                            a known item under "none" or another bonus's key
```

- `key`: the bonus of the known list that names the item; else, in an "all" view, the highest-ranked bonus under
  which **all** the item's raw catches of the scope were made **and** which the seed, or at least three different
  players (the own catch one of them), hold the item under; in a view under a bonus key, that key when all the
  item's raw catches lie under it and the same holders' rule holds.
- `chance`, `littleData`, `catches`, `players`: the numbers of the same scope summed under that bonus: the item's
  chance there, whether that sum has fewer than 50 catches, all catches of the sum (the chance's denominator) and
  the players with a catch in it. In a view filtered by that key they are the view's own. For the seed the
  players are the largest `k` of the summed parts (a lower bound, like a cell's).
- `plain`: the tag is shown; every number is the ordinary one of that view, not marked "with the bonus".
- The scope is always the view's own (the spot or the map `Query` chose): a bonus is never read from another
  scope.

### A catalog place, spot and row

`chance`, `littleData`, `catches` and `players` come from `item.bonus` when the item has one that is not `plain`,
else from the item and the view as today; `bonus = item.bonus` (the table: its `key`, its `plain`) is carried along.
This holds for the zone rows, the spot rows (`Catalog.Spots`), `Catalog.Places` and the list rows (the best
place's, with its `players` too). A missing chance is written as "Little data"; catches and players are never nil.

## Messages

| Message | Arguments | From | Listeners |
|---|---|---|---|
| `CAMP_BONUS_WARNING` | `text` | `Fishing/Camp.lua` (R10) | `UI/Toast.lua` |

No existing message changes its arguments.
