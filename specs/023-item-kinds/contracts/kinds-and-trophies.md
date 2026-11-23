# Contract: kinds, trophies and the first catch

## Catalog (layer 2)

| Function | Returns | Notes |
|---|---|---|
| `Catalog.KINDS` | `{ "fish", "containers", "trophies", "potions", "reagents", "quest", "other" }` | display order |
| `Catalog.ItemKind(itemID)` | a kind | `byItem`, then `byClass` (`"12"` -> `"quest"`), else `"other"`; unchanged otherwise |
| `Catalog.KindText(kind)` | text | `L["Trophies"]`, `L["Quest"]` added; looked up when drawn |
| `Catalog.TrophyIDs()` | array of item IDs | the 36, ascending; the same table on every call |
| `Catalog.TrophyCount()` | `caught, total` | caught by the account (`CatchDB.IsOwnItem`), total = 36 |
| `Catalog.IsKindShown`, `ShownKinds`, `SetKindShown`, `Group` | as in spec 014 | seven kinds; `ShownKinds()` total is 7 |

## CatchDB (layer 2)

| Function / message | Contract |
|---|---|
| `CatchDB.IsOwnItem(itemID)` | true when the item is in the account's own catch data (`shared.mine` or a record of the own ID); builds the set on first use |
| `ITEM_FIRST_CAUGHT(itemID, castID)` | fired once per item that a settled catch adds to the own-items set, after the write; never for an item already in it; never on `FISH_MISSED`; in ascending item ID order (the loot order is gone once the items are summed) |

## UI and Sound

| Module | On `ITEM_FIRST_CAUGHT` of a trophy | On `FISH_CAUGHT` |
|---|---|---|
| `UI/Toast.lua` | `ns.Toast(L["New trophy: %s (%d/%d)"]:format(link or name, caught, total), 1, 0.82, 0, true)` | the ordinary toast without the cast's first trophies; none when no item is left |
| `Fishing/Sound.lua` | the rare sound, by its rules, at most once per cast | unchanged |
| `UI/CatalogTab.lua` | (none) | (none); draws the header `L["%s (%d/%d)"]` for `trophies` and the check mark on caught trophies |

The item's link comes from the cast's `FISH_CAUGHT` items (the toast keeps it); the message carries only IDs. With
several new trophies in one loot, `TrophyCount()` already counts all of them when the toast runs: a toast's n is
`caught` minus the cast's new trophies after it in loot order.
