# Quickstart: Catch Filters by Item Kind

**Feature**: [spec.md](spec.md) | **Contracts**: [contracts/module-api.md](contracts/module-api.md)

What the automated checks prove, and what the author looks at in game.

## Prerequisites

- Node.js 18+, `npm install` once.
- Branch `014-catch-filters`.

## Automated

```text
npm run check
npm test
```

| Test file | Proves |
|---|---|
| `tests/catalog/kinds_test.lua` | FR-002 to FR-005, FR-008, SC-001: every listed ID gets its kind; the class rules (7 / 8 fish, 7 / 11 reagents, 0 / 5 potions, 15 / 0 other, no instant info other); an item learned mid-session leaves Other; every seed item and fished container is listed; `Group` order, stability, empty and hidden kinds, `hiddenCount`; `SetKindShown` writes the set and fires `SETTINGS_CHANGED`; an unknown saved name is ignored and a missing kind is shown |
| `tests/ui/here_kinds_test.lua` | FR-006, FR-007, FR-009 to FR-011, SC-002, SC-004: headers in order, hidden kinds left out, chances and scope unchanged with hidden kinds, the button text, the empty-by-filter message, "and %d more" with headers |
| `tests/ui/catalog_kinds_test.lua` | FR-006, FR-007, FR-011, FR-012: list headers, one choice for both tabs, the two status texts, a hidden item opened by ID shows its places |
| `tests/gamedata/shape_test.lua` | the shape of `GameData.ItemKinds` |
| `tests/core/` (locale tests, present) | SC-005: every new key in all nine translations |

Each new test fails when its change is taken out.

## In game

`docs/checklists/catch-filters.md` (one character, the bundled data):

1. Open "What can be caught here" at a water with several kinds: headers in the order Fish, Containers, Potions &
   drinks, Reagents & herbs, Other; the four filter buttons fit the window in English and in the longest languages.
2. Open the kind menu, untick four kinds one after another: the menu stays open, the list follows each click, the
   button reads "Kinds: 1 of 5".
3. Switch to the catalog tab: the same kinds are hidden, headers in the scroll list look like the rows' height.
4. `/reload`, then a relog: the choice is kept.
5. With Containers hidden, click a chest's chat link (or `/okf catalog` on its item): its zones and spots open.
6. Untick every kind: "The kind filter hides every item." in both tabs; tick them all back.
