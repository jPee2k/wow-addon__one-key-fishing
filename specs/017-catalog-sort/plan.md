# Implementation Plan: Catalog Sorting

**Branch**: `017-catalog-sort` | **Date**: 2026-11-17 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/017-catalog-sort/spec.md`; the author's decisions of 2026-11-17 in its
clarifications.

## Summary

The catch catalog's item list gets a Sort button with three orders: Name (today's, the default), Price and Chance
(highest first), inside the kind groups, remembered per account. The item row's right column shows the value the list
is ordered by. The catalog's buttons move into three rows (search; Skill, Source, Water; Sort, Kinds).

- **Logic (R1 to R5)**: `Catalog/Catalog.lua` (layer 2): `SORTS`, `GetSort`, `SetSort` (-> `settings.catalogSort`,
  `SETTINGS_CHANGED("catalogSort")`), `SortText`; `Catalog.Items` sorts its list (prices from `Prices.Get` on each
  call; chance from the item's best place, which `SortedItems` adds to its rows).
- **UI (R6 to R8)**: `UI/CatalogTab.lua`: the three-row layout, the Sort button and radio menu, the right column
  ("No price" grey), the redraw from the top on a new order.
- **Texts (R9)**: `Sort: %s`, `Name`, `No price`, nine translations each.
- A draft of the logic and part of the UI exists on the branch (uncommitted, written before the agreement): it is
  brought to this plan by the tasks (Kinds into row 3, Water back to row 2, "No price", the tests).

## Technical Context

**Language/Version**: Lua 5.1 (the WoW Forever client, Interface 16001), tests in fengari (Lua 5.3); Node.js 18+ for
the tools

**Primary Dependencies**: the addon's own modules (`Catch/Prices.lua`, `Catalog/Catalog.lua`, `UI/Widgets.lua`'s
radio menu, the scroll list in use since spec 005); no new WoW API call, no new global

**Storage**: one new account-wide setting `settings.catalogSort = "name"`; no `DB_SCHEMA` bump (a new key filled by
`ApplyDefaults`)

**Testing**: `npm test`, `npm run check`; `tests/wow.lua` records anchors (`SetPoint`, `ClearAllPoints`) and text
colors (`SetTextColor`) so the layout and the grey are asserted

**Target Platform**: WoW Forever client (Windows / macOS)

**Project Type**: game addon (single package `OneKeyFishing/`) with Node tooling

**Performance Goals**: a choice in the menu redraws at once; sorting a list of a few hundred rows with prices read
once per row per draw (well under a millisecond); no index rebuild, no new cache

**Constraints**:
- Principle II: items by ID; every text through `ns.L`, nine translations, looked up when drawn; the grey color set
  outside the string.
- Layers: `Catalog.lua` (2) may call `Prices` (1); the UI (3) calls `Catalog`; no lower layer names a frame.
- The statistics window is 580 wide: at most three buttons in a row (research R6).
- ASCII outside the locales; no Cyrillic in the Markdown files; 120-character lines; no new file in the TOC.

**Scale/Scope**:
- Addon: `Catalog/Catalog.lua`, `UI/CatalogTab.lua`, `Core/Core.lua` (default), `Locales/*.lua` (10).
- Tests: `tests/catalog/sort_test.lua`, `tests/ui/catalog_sort_test.lua`, `tests/ui/catalog_sort_saved_test.lua`,
  `tests/ui/catalog_sort_saved_unknown_test.lua` (new); `tests/ui/catalog_kinds_test.lua`,
  `tests/ui/here_kinds_test.lua` (the catch tab's Kinds anchor), `tests/wow.lua` (extended).
- Documents: `CHANGELOG.md` (Unreleased), `OneKeyFishing/README.md` (catch catalog section), `CLAUDE.md` (the
  cross-module rule for `Catalog.SetSort`, the catalog's setting messages), `docs/architecture/catalog.md`,
  `docs/architecture/ui.md`, `docs/architecture/core.md` (the setting), new `docs/checklists/catalog-sort.md` and its
  row in `docs/checklists/README.md`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
|---|---|---|
| I. Blizzard Policy | A display order; no game action, no server traffic | Pass |
| II. Language-Independent Game Data | Items by ID; prices and chances from the addon's own data; three new texts with nine translations each, read when drawn; color outside the strings | Pass |
| III. Safe, Restorable State | One new setting with a default; no field renamed or reshaped; no CVar, gear or camera touched | Pass |
| IV. Verified Forever API | No new API: the price function, the radio menu and the scroll list are in game since 1.0.0 to 1.3.0; the look is handed to the author with a checklist; no `VERIFY` marker | Pass |
| V. Checked and Tested Changes | Four new test files and three extended (R10), each failing without its change | Pass |
| VI. Simple Module Boundaries | Rules in the catalog module (layer 2), frames in `UI/`; no new message (a new key of `SETTINGS_CHANGED`), no new command; the setting written through one function | Pass |
| Technical Constraints | No new file in the TOC; ASCII outside the locales | Pass |

Re-check after Phase 1: the contracts add four catalog functions or fields, two row fields and one setting; the
views, their cache keys, the indexes and `Group` are unchanged; no message, command or saved shape changes. Pass.

## Project Structure

### Documentation (this feature)

```text
specs/017-catalog-sort/
├── plan.md              # This file
├── research.md          # Phase 0
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1
├── contracts/
│   └── module-api.md    # Phase 1
├── checklists/
│   └── requirements.md
└── tasks.md             # /speckit-tasks
```

No `verification.md`: the feature has no `VERIFY` marker (research R11).

### Source Code (repository root)

```text
OneKeyFishing/
├── Catalog/Catalog.lua          # SORTS, GetSort, SetSort, SortText; SortedItems rows + chance, littleData; Items sorts
├── Core/Core.lua                # settings.catalogSort default
├── UI/CatalogTab.lua            # three rows, Sort button and menu, right column, redraw on catalogSort
└── Locales/*.lua                # 3 new keys, nine translations
tests/
├── wow.lua                      # anchors and text colors recorded
├── catalog/sort_test.lua        # new
└── ui/                          # catalog_sort_test.lua, catalog_sort_saved_test.lua,
                                 # catalog_sort_saved_unknown_test.lua (new); catalog_kinds_test.lua, here_kinds_test.lua
docs/
├── architecture/                # catalog.md, ui.md, core.md
└── checklists/catalog-sort.md   # new
```

**Structure Decision**: the existing layout, no new area. The catalog owns the list's rules and order
(`docs/architecture/catalog.md`), the tab draws it, the price comes from the module the statistics use.

## Complexity Tracking

No violation to justify.
