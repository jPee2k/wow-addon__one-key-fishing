# Data Model: Catch Filters by Item Kind

**Feature**: [spec.md](spec.md) | **Research**: [research.md](research.md)

## Item kind

The five kinds, in display order (FR-001). The name is the key everywhere (data, saved set, list elements); the
text is the `ns.L` key the UI shows.

| Order | Name | Text (`Locales/enUS.lua` key) |
|---|---|---|
| 1 | `fish` | `"Fish"` |
| 2 | `containers` | `"Containers"` |
| 3 | `potions` | `"Potions & drinks"` |
| 4 | `reagents` | `"Reagents & herbs"` |
| 5 | `other` | `"Other"` |

`Catalog.KINDS = { "fish", "containers", "potions", "reagents", "other" }` (layer 2: the order is addon tuning,
the names are the data's vocabulary); the text is looked up when drawn, never while the files load.

## `GameData.ItemKinds` (new file `GameData/ItemKinds.lua`, layer 0, data only)

```lua
GameData.ItemKinds = {
    -- itemID -> kind name: every item of the bundled seed and every fished container (FR-003, research R4)
    byItem = {
        [6291] = "fish", -- Raw Brilliant Smallfish (7 / 8 in game, 2026-11-16)
        ...
        [5523] = "containers", -- Small Barnacled Clam (7 / 11)
        ...
    },
    -- "<classID>:<subClassID>" or "<classID>" -> kind name, for an item outside byItem (FR-004, research R3)
    byClass = {
        ["7:8"] = "fish", -- Trade Goods / Cooking: raw fish
        ["7"] = "reagents", -- every other Trade Goods
        ["0"] = "potions", -- Consumable
    },
}
```

The full `byItem` content (39 entries: the 31 of FR-003, and 8 known catches of higher waters added after the
code review of 2026-11-16, so shared data from those waters is grouped right: Stonescale Eel 13422; Dented Crate
6351, Waterlogged Crate 6352, Small Locked Chest 6354, Battered Chest 6356, Heavy Crate 13874, Ironbound Locked
Chest 13875, Reinforced Locked Chest 13918):

| Kind | Item IDs |
|---|---|
| `fish` | 4603, 6289, 6291, 6292, 6303, 6308, 6309, 6358, 6359, 6361, 6362, 6458, 6522, 8365, 21071 |
| `containers` | 5523, 5524, 6353, 6355, 6357, 7973, 15874, 20708, 21113, 21150 |
| `potions` | 858, 2455, 20709, 21114 |
| `reagents` | 3820, 6470 |

Validation (`tests/gamedata/shape_test.lua`, `tests/catalog/kinds_test.lua`):

- every value of `byItem` and `byClass` is one of the five names;
- every key of `byClass` matches `^%d+$` or `^%d+:%d+$`;
- every item ID of `ns.SeedData` and of `GameData.FishedContainers` is a key of `byItem` (SC-001).

## Kind lookup (`Catalog.ItemKind(itemID)`)

```text
byItem[itemID]
  or byClass[classID .. ":" .. subClassID]   -- from C_Item.GetItemInfoInstant, when it answers
  or byClass[tostring(classID)]
  or "other"                                  -- also when GetItemInfoInstant returns nothing
```

Not cached: an item learned during the session gets its class kind at the next draw.

## Kind choice (saved)

`OneKeyFishingDB.settings.hiddenKinds`: a set of kind names, `{}` by default (every kind shown).

| Rule | Source |
|---|---|
| Filled for existing installs by `ApplyDefaults`; no `DB_SCHEMA` bump | research R5 |
| Written only by `Catalog.SetKindShown(kind, shown)`, which fires `SETTINGS_CHANGED("hiddenKinds")` | research R5 |
| A name that is not one of the five is ignored on read | FR-008 |
| A kind the set does not name is shown | FR-008 |
| One set for "What can be caught here" and the catalog | FR-007 |

## Grouped list (`Catalog.Group(items)`)

Input: rows with an `itemID`, in the view's order (the catch view's items by catches, the catalog's by name).

Output: `list, hiddenCount`, the list as both tabs draw it

```text
list = {
  { header = "fish" }, row, row, ...,               -- a header before each shown kind with at least one row,
  { header = "containers" }, row, ...,              -- in Catalog.KINDS order; rows keep their input order
}
hiddenCount = number of input rows whose kind is hidden
```

## List elements of the two tabs

| Tab | Header | Item |
|---|---|---|
| "What can be caught here" | a fixed row in header mode: kind text only | the present row (icon, name, chance, per catch, price) |
| Catalog list | element `{ header = kind }` | the present element `{ itemID, name, zones, key, poor }` |

Headers count against the catch tab's `MAX_ROWS`; "and %d more" counts items only.

## New texts (each with its nine translations)

| Key | Where |
|---|---|
| `"Fish"`, `"Containers"`, `"Potions & drinks"`, `"Reagents & herbs"`, `"Other"` | headers, menu entries |
| `"Kinds: all"` | the menu button, every kind shown |
| `"Kinds: %d of %d"` | the menu button, some kinds hidden |
| `"The kind filter hides every item."` | catch tab message, catalog status (no search) |
| `"The kind filter hides the matches."` | catalog status (with a search) |
