# Data Model: New Item Kinds and the Trophy Collection

No saved field is added or reshaped (no `DB_SCHEMA` bump).

## Item kind (`Catalog.KINDS`)

`fish`, `containers`, `trophies`, `potions`, `reagents`, `quest`, `other`, in this display order.

| Kind | Text (enUS key) |
|---|---|
| fish | `Fish` |
| containers | `Containers` |
| trophies | `Trophies` (new) |
| potions | `Potions & drinks` |
| reagents | `Reagents & herbs` |
| quest | `Quest` (new) |
| other | `Other` |

## Kind table (`GameData.ItemKinds`, layer 0, data only)

- `byItem[itemID] = kind`:
  - `"trophies"`: 6292, 6294, 6295, 6309, 6310, 6311, 6363, 6364, 13876, 13877, 13878, 13879, 13880, 13882, 13883,
    13884, 13885, 13886, 13887, 13901, 13902, 13903, 13904, 13905, 13906, 13907, 13908, 13909, 13910, 13911, 13912,
    13913, 13914, 13915, 13916, 13917 (36).
  - `"quest"`: 1467, 6717, 6718, 16967, 16968, 16969, 16970, 19803, 19804, 19805, 19806, 19807 (12).
- `byClass`: adds `["12"] = "quest"` (Questitem); the others stay (`7:8` fish, `7` reagents, `0` potions).

Validation: each ID above has exactly its kind; no trophy or quest item is left as "fish"; every item of the bundled
seed still has a listed kind (spec 014's test).

## Own-items set (existing, `CatchDB` private `P.ownItems`)

`itemID -> true` for every item of `shared.mine` and of the records of the own ID. Now always built before a cast is
written (R4). Read through `CatchDB.IsOwnItem(itemID)`.

## Trophy collection (derived, `Catalog`)

- `TrophyIDs()`: the IDs whose `byItem` kind is `"trophies"`, ascending; built once.
- `TrophyCount()`: `caught, total`: caught = IDs with `CatchDB.IsOwnItem`, total = `#TrophyIDs()`.

## Message `ITEM_FIRST_CAUGHT(itemID, castID)`

Fired by `CatchDB` (Settle) once per item new to the account's own catch, after the cast is written and the set grown,
inside the `FISH_CAUGHT` (never `FISH_MISSED`) of that cast. Listeners: `UI/Toast.lua`, `Fishing/Sound.lua`.

State per cast in `UI/Toast.lua`: `firstTrophies[castID] = { [itemID] = true }`, read and cleared by its
`FISH_CAUGHT` handler of the same cast.
