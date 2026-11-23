# Implementation Plan: New Item Kinds (Trophies, Quest) and the Trophy Collection

**Branch**: `023-item-kinds` | **Date**: 2026-11-23 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/023-item-kinds/spec.md`; the author's decisions of 2026-11-23
([docs/extravaganza-research.md](../../docs/extravaganza-research.md), sections 9 and 11).

## Summary

Two new item kinds in the catch lists, "Trophies" (the 36 weighed "N Pound" fish) and "Quest" (the quest items), in
the order Fish, Containers, Trophies, Potions & drinks, Reagents & herbs, Quest, Other; a trophy collection in the
catalog (a count "n/36" on the Trophies header, a check mark on each trophy the account caught); a loud notice and the
rare sound for a trophy new to the account.

- **Data (R1, R2)**: `GameData/ItemKinds.lua` (layer 0): the 36 trophies and 12 quest items by ID (the trophies
  already listed as "fish" move), the class rule `["12"] = "quest"`. A test pins every ID.
- **Logic (R3, R4, R5)**: `Catalog.KINDS` with seven kinds, `Catalog.KindText` with two texts,
  `Catalog.TrophyIDs()` / `Catalog.TrophyCount()` (`Catalog/Catalog.lua`, layer 2) over a new
  `CatchDB.IsOwnItem(itemID)` (the existing own-items set). `CatchDB` fires a new message
  `ITEM_FIRST_CAUGHT(itemID, castID)` when a settled cast brings an item new to the account's own catch; the set is
  built before the cast is written, so the first catch is always seen.
- **UI (R6, R7)**: the catalog's Trophies header reads "Trophies (n/36)" and a caught trophy's icon carries a check
  mark (`UI/CatalogTab.lua`); `UI/Toast.lua` turns `ITEM_FIRST_CAUGHT` of a trophy into a loud toast and leaves that
  item out of the cast's ordinary catch toast; `Fishing/Sound.lua` plays the rare sound once per cast for it.

## Technical Context

**Language/Version**: Lua 5.1 (the WoW Forever client, Interface 16001), tests in fengari (Lua 5.3); Node.js 18+ for
the tools

**Primary Dependencies**: the WoW Mainline API as shipped in Forever 1.60.1; nothing new: `C_Item.GetItemInfoInstant`
(the class rule, already used), the atlas `common-icon-checkmark` (in the client export, used by Blizzard's
character creation)

**Storage**: none new. "Caught by the account" reads the own catch data that exists (`shared.mine`, the own records);
`settings.hiddenKinds` keeps its shape (a kind it does not name is shown), so no `DB_SCHEMA` bump

**Testing**: `npm test`, `npm run check`; tests extended in `tests/catalog/kinds_test.lua`, `tests/gamedata/`, and new
tests for the collection and the first-catch message (`tests/catalog/trophies_test.lua`,
`tests/catchdb/first_caught_test.lua`, `tests/ui/trophy_toast_test.lua`)

**Target Platform**: WoW Forever client (Windows / macOS)

**Project Type**: game addon (single package `OneKeyFishing/`) with Node tooling

**Performance Goals**: the first catch check is one table lookup per looted item; the own-items set is built once per
session (one walk of the own data, as today for the views); the count walks 36 IDs when the catalog draws

**Constraints**:
- Principle II: kinds and trophies by item ID, never by name ("Pound" is never matched); texts through `ns.L` with
  nine translations, looked up when drawn.
- Layers: `GameData` (0) data only; `Fishing/Sound.lua` (1) reads `GameData.ItemKinds` only, never `Catalog` or
  `CatchDB`; `CatchDB` and `Catalog` (2) know no frame; the UI (3) listens to the message and calls Catalog.
- `FISH_CAUGHT` keeps its arguments; the new message is listed in `CLAUDE.md`.
- ASCII outside the locales; 120-character lines; no new file in the addon's TOC.

**Scale/Scope**:
- Addon: `GameData/ItemKinds.lua`, `Catalog/Catalog.lua`, `CatchDB/CatchDB.lua` (Settle), `CatchDB/Index.lua`
  (`IsOwnItem`), `Fishing/Sound.lua`, `UI/Toast.lua`, `UI/CatalogTab.lua`, `Locales/*.lua` (10).
- Tests: as above, plus every existing test that counts five kinds.
- Documents: `CHANGELOG.md`, `OneKeyFishing/README.md`, `CLAUDE.md` (the message), `docs/architecture/catalog.md`,
  `docs/architecture/catch-db.md`, `docs/architecture/game-data.md`, `docs/architecture/ui.md`,
  `docs/architecture/fishing-mode.md` (the sound), `docs/ROADMAP.md` (023 leaves "Planned" when done).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
|---|---|---|
| I. Blizzard policy | No game action; a notice and a sound after the player's own catch | Pass |
| II. Language-independent data | Kinds by item ID and class number; no name matching; nine translations of the four new texts; no `L` at load | Pass |
| III. Safe, restorable state | No CVar, gear or camera change; no new saved field | Pass |
| IV. Verified Forever API | Item IDs and classes from the client's tables (build 1.60.1.71037); the atlas from the client export; no `VERIFY` needed (R1) | Pass |
| V. Checked and tested | Tests for the lists, the count, the first catch, the toast and the sound; `npm run check` | Pass |
| VI. Simple module boundaries | Data in layer 0, rules in layer 2, frames in layer 3, joined by a message; Sound (1) reads only GameData | Pass |

Re-check after Phase 1: unchanged, all pass. No violation to justify.

## Project Structure

### Documentation (this feature)

```text
specs/023-item-kinds/
├── spec.md
├── plan.md              # this file
├── research.md          # Phase 0
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1: what the tests prove, the in-game look
├── contracts/
│   └── kinds-and-trophies.md
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
OneKeyFishing/
├── GameData/ItemKinds.lua     # trophies, quest items, class rule 12
├── CatchDB/Index.lua          # CatchDB.IsOwnItem
├── CatchDB/CatchDB.lua        # Settle: own-items set first, ITEM_FIRST_CAUGHT
├── Catalog/Catalog.lua        # KINDS (7), KindText, TrophyIDs, TrophyCount
├── Fishing/Sound.lua          # rare sound for a first trophy, once per cast
├── UI/Toast.lua               # the trophy toast, the ordinary toast without it
├── UI/CatalogTab.lua          # header count, check mark
└── Locales/*.lua              # "Trophies", "Quest", "%s (%d/%d)", "New trophy: %s (%d/%d)"
tests/
├── catalog/kinds_test.lua, catalog/trophies_test.lua
├── catchdb/first_caught_test.lua
├── gamedata/ (the ID lists)
└── ui/trophy_toast_test.lua
```

**Structure Decision**: the addon's existing areas; no new folder or file in the TOC.

## Complexity Tracking

No violations.
