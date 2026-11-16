# Implementation Plan: Catch Filters by Item Kind

**Branch**: `014-catch-filters` | **Date**: 2026-11-16 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/014-catch-filters/spec.md`; in-game facts of 2026-11-16 (the item
classes) in the spec's clarifications.

## Summary

"What can be caught here" and the catch catalog list their items under five fishing kinds (Fish, Containers,
Potions & drinks, Reagents & herbs, Other), with a checkbox menu that hides kinds in both tabs and is remembered.

- **Data (R3, R4)**: a new `GameData/ItemKinds.lua` (layer 0): the 31 known items by ID, and class rules for the
  rest (`7:8` fish, `7` reagents, `0` potions, else other). A test keeps every seed item and fished container in the
  list.
- **Logic (R2, R5, R7)**: `Catalog.ItemKind`, `Catalog.KINDS`, `Catalog.Group` and the saved choice
  (`Catalog.SetKindShown` -> `settings.hiddenKinds`, `SETTINGS_CHANGED`) in `Catalog/Catalog.lua` (layer 2). The
  filter is applied to the finished item lists, so the views, their sums and their cache keys stay as they are
  (FR-010).
- **UI (R6, R7, R8)**: a checkbox menu helper in `UI/Widgets.lua`; a "Kinds" button and header rows in
  `UI/CatchHere.lua` and `UI/CatalogTab.lua`; the empty-by-filter texts; nine translations.

## Technical Context

**Language/Version**: Lua 5.1 (the WoW Forever client, Interface 16001), tests in fengari (Lua 5.3); Node.js 18+ for
the tools

**Primary Dependencies**: the WoW Mainline API as shipped in Forever 1.60.1 (`C_Item.GetItemInfoInstant` for
`classID` / `subClassID`, `MenuUtil.CreateContextMenu` with `CreateCheckbox`; both already used or in the client
export)

**Storage**: one new account-wide setting `settings.hiddenKinds = {}`; no `DB_SCHEMA` bump (a new key filled by
`ApplyDefaults`)

**Testing**: `npm test`, `npm run check`; `tests/wow.lua` gains `item_classes` for the instant info (its `MenuUtil`
stub already records `CreateCheckbox` entries)

**Target Platform**: WoW Forever client (Windows / macOS)

**Project Type**: game addon (single package `OneKeyFishing/`) with Node tooling

**Performance Goals**: a click in the menu redraws the shown tab at once (a direct `Refresh`, not the next tick): one
pass over the already built item
list (at most a few hundred rows in the catalog); no index rebuild, no new cache

**Constraints**:
- Principle II: kinds by item ID and the client's class numbers, never by name or tooltip; every text through
  `ns.L` with nine translations, looked up when drawn.
- Layers: `GameData/ItemKinds.lua` (0) data only; `Catalog.lua` (2) reads GameData and writes the setting; the UI
  (3) calls Catalog. No lower layer names a frame.
- The statistics window is 580 wide: the filter row keeps its three buttons of 150; Kinds sits at the top right.
- ASCII outside the locales; 120-character lines; a new file in the TOC (game restart, not `/reload`).

**Scale/Scope**:
- Addon: new `GameData/ItemKinds.lua`; changed `Catalog/Catalog.lua`, `UI/Widgets.lua`, `UI/CatchHere.lua`,
  `UI/CatalogTab.lua`, `Core/Core.lua` (default), `OneKeyFishing.toc`, `Locales/*.lua` (10).
- Tests: `tests/catalog/kinds_test.lua`, `tests/ui/here_kinds_test.lua`, `tests/ui/catalog_kinds_test.lua` (new);
  `tests/gamedata/shape_test.lua`, `tests/wow.lua` (extended).
- Documents: `CHANGELOG.md`, `OneKeyFishing/README.md`, `CLAUDE.md` (module map, the cross-module rule),
  `docs/architecture/catalog.md`, `docs/architecture/game-data.md`, `docs/architecture/ui.md`,
  `docs/architecture/core.md` (the setting), new `docs/checklists/catch-filters.md` and its row in the checklists'
  `README.md`; `docs/ROADMAP.md` if it lists item filters.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
|---|---|---|
| I. Blizzard Policy | A display filter; no game action, no server traffic | Pass |
| II. Language-Independent Game Data | Kinds by item ID, then by the client's class numbers; no name, no tooltip, no quality; nine translations; texts read when drawn | Pass |
| III. Safe, Restorable State | One new setting with a default; no field renamed or reshaped; no CVar, gear or camera touched | Pass |
| IV. Verified Forever API | `GetItemInfoInstant`'s class values read in game (2026-11-16); `CreateCheckbox` and its refresh response read from the client export, with a fallback to the radio-style buttons; no new global (`MenuUtil`, `C_Item` already in `.luacheckrc`); the UI handed to the author with a checklist | Pass |
| V. Checked and Tested Changes | Three new test files and two extended (R10), each failing without its change | Pass |
| VI. Simple Module Boundaries | Data in `GameData/`, rules in the catalog module (layer 2), frames in `UI/`; no new message, no new command; the setting written through one function | Pass |
| Technical Constraints | One new Lua file listed in the TOC, ASCII | Pass |

Re-check after Phase 1: the contracts add one data file, seven catalog functions, one widget helper and one setting;
the views and their cache keys are unchanged; no message, command or saved shape changes. Pass.

## Project Structure

### Documentation (this feature)

```text
specs/014-catch-filters/
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

No `verification.md`: the feature has no `VERIFY` marker (research R3, R11).

### Source Code (repository root)

```text
OneKeyFishing/
├── OneKeyFishing.toc            # GameData\ItemKinds.lua after GameData\FishedContainers.lua
├── GameData/ItemKinds.lua       # new: byItem (31 IDs), byClass (R3)
├── Catalog/Catalog.lua          # KINDS, ItemKind, KindText, IsKindShown, ShownKinds, SetKindShown, Group; Describe
├── Core/Core.lua                # settings.hiddenKinds default
├── UI/Widgets.lua               # ns.OpenCheckboxMenu (R6)
├── UI/CatchHere.lua             # kind button, header rows, OpenKindMenu, empty text (R7, R8)
├── UI/CatalogTab.lua            # kind button, header elements, status texts (R7, R8, R9)
└── Locales/*.lua                # 9 new keys, nine translations
tests/
├── wow.lua                      # item_classes
├── catalog/kinds_test.lua       # new
├── gamedata/shape_test.lua      # ItemKinds shape
└── ui/                          # here_kinds_test.lua, catalog_kinds_test.lua (new)
docs/
├── architecture/                # catalog.md, game-data.md, ui.md, core.md
└── checklists/catch-filters.md  # new (R11)
```

**Structure Decision**: the existing layout, no new area. The kinds are item data (`GameData/`), their rules belong
to the catalog, which already owns the item-level questions (names, search, the Poor rule) and is read by both tabs
(`docs/architecture/catalog.md`); the frames stay in the two tabs and the widget helpers.

## Complexity Tracking

No violation to justify.
