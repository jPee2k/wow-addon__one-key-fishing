# Quickstart: New Item Kinds and the Trophy Collection

## Run

```text
npm run check
npm test
```

## What the tests prove

| Test | Proves |
|---|---|
| `tests/catalog/kinds_test.lua` (lists) | each of the 36 trophies is "trophies", each of the 12 quest items is "quest" (SC-001); every seed item keeps a kind |
| `tests/catalog/kinds_test.lua` | seven kinds in the order of FR-001 (SC-002); class 12 is "quest"; a saved choice of five kinds still hides what it hid and shows the new kinds (FR-005) |
| `tests/catalog/trophies_test.lua` | `TrophyCount` counts the own data of every game version and ignores others' data and the seed (FR-007, SC-003); search and hidden kinds do not change it |
| `tests/catchdb/own_item_test.lua` | `CatchDB.IsOwnItem`: own data of every version, not others' or the seed's; true right after a new catch |
| `tests/catchdb/first_caught_test.lua` | the first catch of an item fires `ITEM_FIRST_CAUGHT` once, also when no view built the set before; a repeat, a miss and an item in the own record of an older version fire none (SC-004) |
| `tests/ui/trophy_toast_test.lua` | a first trophy gives the loud toast with the new count, also with catch notifications off, and the ordinary toast leaves it out; a repeated trophy gives the ordinary toast only; two new trophies in one loot give two toasts with counts n+1, n+2 |
| `tests/fishing/sound_events_test.lua` | the rare sound plays once for a first trophy, once for a first trophy with a green item in the same loot, never in a fight or outside fishing mode |
| `tests/ui/catalog_trophies_test.lua` | the Trophies header reads "Trophies (n/36)"; caught trophies carry the mark, others not |

## In game (no `VERIFY`; a look after the build)

1. `/okf catalog`: the kind menu lists seven kinds in the new order; the Trophies header shows "n/36"; a trophy the
   account caught shows a check mark at the bottom right corner of its icon, others none.
2. Catch a trophy the account never caught: the gold toast "New trophy: ... (n/36)" and the rare sound; catch it again:
   the ordinary toast.
