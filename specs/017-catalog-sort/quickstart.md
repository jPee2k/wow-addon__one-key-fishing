# Quickstart: Catalog Sorting

**Feature**: [spec.md](spec.md) | **Contracts**: [contracts/module-api.md](contracts/module-api.md)

What the automated checks prove, and what the author looks at in game.

## Prerequisites

- Node.js 18+, `npm install` once.
- Branch `017-catalog-sort`.

## Automated

```text
npm run check
npm test
```

| Test file | Proves |
|---|---|
| `tests/catalog/sort_test.lua` | FR-001, FR-004 to FR-006, FR-010, SC-002, SC-003, SC-005: the three orders of `Catalog.Items` (vendor, trusted auction, few-lots auction and no price; little-data items last by chance; ties by name; the search keeps the order); by name identical to before; `GetSort` default and unknown value; `SetSort` writes and fires once |
| `tests/ui/catalog_sort_test.lua` | FR-002, FR-003, FR-007 to FR-009, FR-011: the button text, the radio menu, a choice reorders inside the kind groups and resets the scroll, the right column per order with "No price" grey, a price change reorders at the next tick, the three-row layout |
| `tests/ui/catalog_sort_saved_test.lua` | FR-010, SC-004: a saved order is used at the first draw |
| `tests/ui/catalog_sort_saved_unknown_test.lua` | FR-010: an unknown saved value draws by name and is not rewritten |
| `tests/ui/catalog_kinds_test.lua`, `tests/ui/here_kinds_test.lua` (extended) | the Kinds button in row 3 next to Sort; "What can be caught here" keeps its own |
| `tests/core/` (locale tests, present) | FR-012, SC-006: every new key in all nine translations |

Each new test fails when its change is taken out.

## In game

`docs/checklists/catalog-sort.md` (one character, the bundled data, ideally after an auction scan):

1. Open the catalog: three rows of buttons (search; Skill, Source, Water; Sort, Kinds), nothing overlaps; the button
   reads "Sort: Name" and the list is as before.
2. Sort: Price: inside each kind, the dearest first, each row with its price; items without a price last with
   "No price" in grey; the list starts from its top.
3. Sort: Chance: inside each kind, the highest chance first; "Little data" items last; an item's value equals the
   first zone on its own page.
4. `/reload`, then another character of the account: the order is kept.
5. Switch the interface language to French (the longest labels): the buttons still do not overlap.
6. "What can be caught here": its layout is unchanged.
7. Right after a login, before the catalog has finished counting: choose an order; once the list shows, it is in that
   order.
