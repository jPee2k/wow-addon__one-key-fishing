# Contract: Fishing Camp Buffs

**Feature**: [../spec.md](../spec.md) | **Data model**: [../data-model.md](../data-model.md) |
**Research**: [../research.md](../research.md)

## `Fishing/Camp.lua` (layer 1, new: `ns.Camp`)

| Function | Contract |
|---|---|
| `Camp.Read()` | reads every bonus's aura when auras are not restricted; else changes nothing. Returns whether a read happened |
| `Camp.IsActive(key)` | `true`, `false`, or `nil` when the bonus's state is unknown |
| `Camp.TimeLeft(key)` | seconds until the bonus ends, or nil when it is not active or unknown |
| `Camp.Mask()` | nil when any bonus is unknown; else the sum of the bits of the active bonuses (0: none) |
| `Camp.CastMask(castID)` | the mask the cast counts for: its start mask when that is a number equal to `Mask()` now, else 0. Drops the kept masks of earlier casts, keeps this one |
| `Camp.HasBit(mask, key)` | whether the mask (a number) holds the bonus's bit |
| `Camp.KnownBonus(itemID)` | the key of the bonus whose known list names the item, or nil |
| `Camp.IsBonusCatch(mask, items)` | whether a catch under the mask holds a known item of one of the mask's bonuses; `items` is the list of `FISH_CAUGHT` (`{ itemID, ... }` entries) |
| `Camp.Describe()` | the debug report's lines, English (R14) |

Guarantees:

- The aura is read by spell ID only, never by name, and never while auras are restricted; the `UNIT_AURA` payload
  is not read.
- No game action: nothing is cast, used or placed; no frame is created.
- A mask kept at a cast's start is still answered after the next cast started (a miss settles a second late).
- `CAMP_BONUS_WARNING(text)` fires at most once per granted buff for "ends in 5 minutes" and once for "has ended",
  only with fishing mode on and `settings.campBonusWarning` on at the crossing, and only after a read confirmed the
  state: never from the clock alone while auras are restricted. A crossing passed silently (mode off, setting off,
  found late) is not shown later.
- No `L[...]` lookup while the files load: the notice texts are read when a notice fires.

Uses at runtime: `ns.GameData.CampBonuses`, `ns.Mode.IsActive()`, `ns.GetFishingCastID()`, `ns.On`, `ns.Fire`,
`ns.RegisterEvent` (a plain registration: `UNIT_AURA` comes for every unit and is filtered by its first argument),
`ns.IsSecret`, `ns.db`, `C_UnitAuras.GetPlayerAuraBySpellID`, `C_Secrets.ShouldAurasBeSecret`, `InCombatLockdown`,
`GetTime`, `C_Timer.After`.

## `CatchDB/*.lua` (layer 2, `ns.CatchDB`)

| Function | Change |
|---|---|
| `Settle(cast, caught)` (private) | a cast with `cast.mask > 0` also adds to `cell.q[tostring(cast.mask)]` of both target cells: `c` and the items, or `m` |
| the `FISH_CAUGHT` / `FISH_MISSED` handlers (`Events.lua`) | set `cast.mask = ns.Camp.CastMask(castID)` before `Settle` |
| `CatchDB.CheckRecord(record)` | a cell's `q` is checked by the rules of the data model; the reasons are new |
| `CatchDB.FilterKey(filter)` | `range|source|water|bonus`; a missing `bonus` reads as `"all"` |
| `CatchDB.Query`, `QueryMap`, `QueryCells`, `Maps` | honour `filter.bonus`; an item may carry `item.bonus` (data-model.md, four shapes), always computed inside the view's own scope |
| a view | under a bonus filter `missRate` is a number (the parts have misses); `littleData` and `catches` are the filtered ones |
| `CatchDB.HasBonusData(key)` | new: whether any held cell (seed, own counts, a held record while sharing is on, any place) has a part with the bonus's bit; without a key, any part with a known bit. Dropped whole on `SHARED_DATA_CHANGED`, at `ADDON_LOADED` and when the own catch writes a new part |
| `CatchDB.BonusKeys()` | new: the keys of `GameData.CampBonuses` in rank order (for the menus) |
| `CatchDB.DescribeBonusParts(placeKey)` | new: the own counts of each part of that place, English, for the debug report |

Guarantees:

- A view with `bonus == "all"` gives every untagged item the numbers of 1.4.0.
- A cell without `q` counts for `"all"` and `"none"` only.
- `q` is inclusive: no total changes because of it; a cast with mask 0 writes no part.
- No view is built by fetching another view: the bonus sums of a scope are filled in the pass that sums the scope.

## `Exchange/Share.lua` (layer 2)

| Function | Change |
|---|---|
| `CleanCell(cell)` (local) | copies `q`: per key a fresh `{ c, m, i }` |

Nothing else of the exchange changes: no message, no version, no limit.

## `Catalog/Catalog.lua` (layer 2)

| Function | Change |
|---|---|
| `Catalog.DefaultFilter()` | also `bonus = "all"` |
| the index (`IndexFor`, `RebuildItems`) | keeps `filter.bonus`; a place's `chance`, `littleData`, `catches`, `players` come from `item.bonus` when present and not `plain`; `place.bonus` is the `item.bonus` table |
| `Catalog.Places(itemID, filter)`, `Catalog.Spots(...)` | the same four numbers and the `bonus` table on their rows; catches and players never nil |
| the list rows (`Catalog.Items`) | carry the best place's `bonus` table and `players`; a missing chance is "Little data" |
| `Catalog.ChanceText(chance, littleData, players, withBonus)` | with `withBonus` (never for a `plain` tag) the chance inside `L["%s with the bonus"]`, then the players' wrapper: "0.47% with the bonus (3 players)", for tooltips, the "Caught in:" lines and the minimap lines; without it the number as today, for the rows' cells; "Little data" stays as it is; a nil chance is "Little data" |
| `Catalog.BonusTag(key)` | new: `L["Fishing Rack bonus"]` / `L["Fishing Hut bonus"]` |
| `Catalog.BonusTip(key)` | new: the tag's explanation line |
| `Catalog.BonusLabel(value)` | new: the filter value's label ("All catches", "No camp bonus", "Fishing Rack", "Fishing Hut") |
| `Catalog.BonusIcon(key)` | new: the camp feature's item icon by `GameData.CampBonuses[...].item`, or nil |
| `Catalog.TooltipLines(itemID)` | each line's `right` uses the place's numbers, with the bonus form for a tagged place; a second return value, the best place's `bonus` table, or nil |
| `Catalog.MinimapLines()` | a tagged item's `right` uses its bonus chance |

## `Catch/Stats.lua` (layer 1)

| Function | Change |
|---|---|
| `NewBucket()` | `bonusCasts = 0`, `bonusCatches = 0` |
| the `FISH_CAUGHT` / `FISH_MISSED` handlers | take the cast ID; add a bonus cast when `Camp.CastMask(castID) > 0`; a bonus catch when `Camp.IsBonusCatch(mask, items)` |
| readers and adders | a missing field of a saved bucket reads as 0 |

## `Core/Data.lua` (layer 0)

| Function | Change |
|---|---|
| `ns.Percent(value)` | the rule of research R9: `37%`, `3.4%`, `0.47%`, `<0.01%`; `0%` only for 0 |

## UI (layer 3)

| File | Change |
|---|---|
| `UI/Widgets.lua` | `ns.AddBonusLines(tooltip, bonus)` (new): the tag's name, its explanation and, unless `plain`, the chance with the bonus and its players, whatever `settings.tooltipChances`. `ns.ShowItemTooltip(owner, itemID, withPrice, bonus)`: after `SetOwner` and before `SetItemByID` keeps `{ owner, itemID }` with a bonus, nil without one (every call); with `bonus` calls `AddBonusLines` after the item's own lines. `ns.TooltipHasBonus(tooltip, itemID)` (new): something kept, `tooltip == GameTooltip`, its owner and the item match. A `GameTooltip:HookScript("OnHide")` clears what is kept |
| `UI/CatchHere.lua` | the bonus filter state and `CatchHere.OpenBonusMenu(owner, current, choose)` (also the catalog's); the button in the Water button's place; the tag icon on a row (research R19); a tagged row's chance cell shows `item.bonus.chance` with `item.bonus.littleData` ("Little data" when set), not the item's ordinary chance, unless the tag is `plain`; the row hands its bonus to `ShowItemTooltip`, and its "Unknown item" branch calls `ns.AddBonusLines` |
| `UI/CatalogTab.lua` | the same button for its own filter; the tag icon in the list rows, the zone rows and the spot rows; a list row hands its bonus to `ShowItemTooltip`, `ShowPlaceTooltip` calls `ns.AddBonusLines` after its catches line; `RightColumn` writes "Little data" for a tagged item without a chance |
| `UI/ItemHooks.lua` | one more line under "Caught in:" for a tagged item, the tag's explanation; none when `ns.TooltipHasBonus(tooltip, itemID)` |
| `UI/Toast.lua` | shows `CAMP_BONUS_WARNING`'s text even with catch notifications off |
| `UI/StatsFrame.lua` | the two rows as the last rows of the "Results" block, hidden (their place kept) while the total has no bonus cast; `HEIGHT` 736 |
| `UI/Settings.lua` | the row `campBonusWarning` on the main page (a label, no hint) |

## `Core/Debug.lua`, `Core/Core.lua`

- `Core/Debug.lua`: a "Camp bonus" section from `Camp.Describe()`; the catch database section gains the current
  place's parts (`CatchDB.DescribeBonusParts`).
- `Core/Core.lua`: the default `campBonusWarning = true`.

## `tools/harvest.mjs`

`cleanCell`, `checkCell`, `sumContributions`, `cellLines` carry `q` with the same rules as the client's check; a
cell that breaks them is skipped like any bad cell. `scaleCell` scales each part and the rest apart and builds the
cell's totals as their sum; `sumContributions` drops `p` from a summed cell with `q` and writes a part's own `k`,
`r`, `x` (research R15).
