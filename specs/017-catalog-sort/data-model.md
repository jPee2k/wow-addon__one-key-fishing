# Data Model: Catalog Sorting

**Feature**: [spec.md](spec.md) | **Research**: [research.md](research.md)

## Saved setting

| Field | Where | Type | Default | Written by | Read by |
|---|---|---|---|---|---|
| `settings.catalogSort` | `OneKeyFishingDB` (account-wide) | `"name"`, `"price"` or `"chance"` | `"name"` | `Catalog.SetSort` only | `Catalog.GetSort` |

- A missing key is filled by `ApplyDefaults`; no `DB_SCHEMA` bump, no migration.
- A value that is not one of the three (a later version's) reads as `"name"` and is not rewritten until the player
  chooses an order.
- Shown in `/okf debug` under "Addon settings" (`catalogSort = price`) by the existing section.

## List order

`Catalog.SORTS = { "name", "price", "chance" }`: the menu's order.

| Order | Key of a row | Direction | Ties | Right column |
|---|---|---|---|---|
| `name` | the folded name (`ns.CompareText`), then the item ID | A to Z (as today) | item ID | `Zones: N` |
| `price` | `Prices.Get(itemID)` in copper, 0 for no price | highest first; 0 last | by name | `FormatMoney(price)`, or `No price` in grey |
| `chance` | `littleData` of the best place (false first), then its `chance` | highest first | by name | `ChanceText(chance, littleData)` |

## Item row of `Catalog.Items`

As today, plus two fields set by `SortedItems` from the item's best place (`places[1]` in `PlaceBefore` order, for the
index's filter):

| Field | Type | Meaning |
|---|---|---|
| `itemID`, `name`, `zones`, `key`, `poor` | as today | |
| `chance` | number 0..1 | the chance of the best place |
| `littleData` | boolean | the best place has fewer than 50 catches (so every place of the item has) |

The rows are the index's cached tables; `Catalog.Items` sorts its own list of them and never writes a row.

## State transitions

```text
settings.catalogSort: "name" --SetSort("price")--> "price" --SetSort("chance")--> "chance" --SetSort("name")--> "name"
each change: SETTINGS_CHANGED("catalogSort") -> CatalogTab.Refresh() (list from its top)
SetSort(same value) or SetSort(unknown): nothing written, no message
```
