# Contract: Catalog Sorting

**Feature**: [../spec.md](../spec.md) | **Data model**: [../data-model.md](../data-model.md)

## `Catalog/Catalog.lua` (layer 2)

| Function | Contract |
|---|---|
| `Catalog.SORTS` | `{ "name", "price", "chance" }`, the menu's order |
| `Catalog.GetSort()` | the saved order; `"name"` when `ns.db` is missing or the saved value is no order |
| `Catalog.SetSort(sort)` | the one way to change the order: writes `settings.catalogSort` and fires `SETTINGS_CHANGED("catalogSort")` when `sort` is an order and differs from the current one; otherwise nothing |
| `Catalog.SortText(sort)` | the order's name in the addon's language (`Name`, `Price`, `Chance`), looked up when called |
| `Catalog.Items(filter, search)` | unchanged arguments and state; the rows (now with `chance` and `littleData`) are in the saved order (data-model.md "List order"); by name exactly as before |

Unchanged: `Catalog.Group` (keeps the input order inside each kind), `Catalog.Find` (by name), `Places`, `Spots`,
the tooltips, `Describe`.

Calls `ns.Prices.Get` (layer 1) at runtime only.

## `UI/CatalogTab.lua` (layer 3)

- **Layout** (the list view): row 1 the search box (`TOP`); row 2 Skill, Source, Water (`TOP - 28`, Water after
  Source, shown with pool data only); row 3 Sort (min width 150, `TOP - 54`) then Kinds (`CatchHere.KIND_WIDTH`)
  anchored to its right; the item list from `TOP - 88`.
- **Sort button**: text `L["Sort: %s"]` with `Catalog.SortText(Catalog.GetSort())`, set on every `Refresh`; a click
  opens `ns.OpenRadioMenu` with one entry per `Catalog.SORTS`, the current order marked; a choice calls
  `Catalog.SetSort`.
- **Item row**: the right column follows data-model.md; its color is white except `No price` (grey), set on every
  draw.
- **Redraw**: `SETTINGS_CHANGED("catalogSort")` -> `CatalogTab.Refresh()` without `retain` (the list from its top);
  `PRICES_CHANGED` and other settings keep marking the page dirty for the tick.

`UI/CatchHere.lua`: unchanged (its Kinds button stays at the top right).

## Messages, commands, saved data

- No new message: `SETTINGS_CHANGED` gains the key `"catalogSort"`.
- No new slash command.
- One new saved field, `settings.catalogSort` (data-model.md).
