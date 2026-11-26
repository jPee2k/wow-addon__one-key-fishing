# Implementation Plan: Import and Export of Catch Records

**Branch**: `027-import-export` | **Date**: 2026-11-25 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/027-import-export/spec.md`; the research and the author's decisions of
2026-11-25 ([docs/import-export-research.md](../../docs/import-export-research.md)).

## Summary

A settings page "Import and export" turns the player's catch records into one string to copy, and reads a string
pasted in. Every record of a string passes the checks of a record received through the exchange. A checksum refuses
a damaged or cut string. Imported records count at once, also with sharing off. Beside it, the exchange and the views
get neutral extension points: settable session rules, and runtime additions to the minimap menu, the `/okf share`
lines, the debug report and the settings pages. With none used, nothing changes.

- **Logic (R1-R6)**: a new file `Exchange/ShareTransfer.lua` of the module `ns.Share`, with `Share.Export`,
  `Share.Import`, `Share.TransferState` and the imported marks `shared.imported`. Both run in frame steps within
  the merge's per-step budget. `CatchDB/Index.lua` and `CatchDB/Views.lua` count the imported records with sharing
  off (`CountedOthers`).
- **Extension points (R7, R8)**:
  - `Share.SetSessionRules` / `ResetSessionRules` / `SessionRules`: the node reads `self.rules`, with today's
    constants as defaults and clamped limits;
  - `Share.AddStatusLine`, `Debug.AddSection`, `ns.MinimapMenu.AddEntries`, `SettingsUI.AddPage`.
- **UI (R9)**: a new file `UI/TransferPage.lua`. The page has a selector, a text area and a hint, plus an
  **Import** button on the Import side. It registers itself through `SettingsUI.AddPage`.
- **Commands**: `/okf share import` and `/okf share export` (`Core/Commands.lua`, the `share` entry takes `rest`).

## Technical Context

**Language/Version**: Lua 5.1 (WoW Forever client, Interface 16001), tests in fengari (Lua 5.3); Node.js 18+ for the
tools

**Primary Dependencies**:
- the record encoding the exchange already uses (`C_EncodingUtil`: CBOR, Deflate, Base64; V15 seen in game);
- the record checks `CatchDB.CheckRecord` and `CheckVersion`, and `Share.Store.Accept`;
- the settings canvas API (in use), and an `EditBox` multi-line with `HighlightText` and `SetFocus` (in use in
  `UI/CopyWindow.lua`).

No new WoW global.

**Storage**: `OneKeyFishingDB.shared.imported` (unit `"<id>@<epoch>"` -> `true`), a new field filled by
`ApplyDefaults`. It reshapes nothing, so `DB_SCHEMA` stays. The marks of units no longer stored are dropped at
`ADDON_LOADED` by the store's `CleanUp`.

**Testing**: `npm test` (fengari), with new tests in `tests/exchange/share/` (export, import, marks, session rules),
`tests/catchdb/` (counting with sharing off), `tests/ui/` (the page, the menu and report additions) and
`tests/tools/` (the release holds only TOC files). The exchange simulation keeps its numbers with the default rules
(SC-004).

**Target Platform**: WoW Forever 1.60.1 client (Windows/macOS)

**Project Type**: game addon (single Lua project, tools in Node)

**Performance Goals**: no frame spends more on import or export than the merge's step budget (`PROOF_BUDGET_MS`,
4 ms, plus one decode); a string at the limit (about 256 KB) imports in a few seconds of frame steps.

**Constraints**:
- Blizzard policy: no clipboard access (the player copies and pastes), nothing leaves the game by itself;
- the layers (Exchange is layer 2, UI layer 3);
- every text through `ns.L` with nine translations;
- ASCII Lua, lines of 120 characters at most.

**Scale/Scope**: up to 20,000 stored places (about 2 MB); an export holds the own record plus about 256 KB of others'
records, the freshest first.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Result |
|---|---|---|
| I. Policy | No game action, no automatic reaction, nothing sent outside the game: the player copies and pastes by hand. Import and export use no message, so the exchange's budget is untouched. The session rules keep every limit toward peers (clamped). | Pass |
| II. By ID | Records are keyed by contribution ID and map IDs, with no names. | Pass |
| III. Restorable state | Nothing of the game is changed; only saved data. | Pass |
| IV. Verified API | Only calls already in use; the edit box's limit for a large paste is V78 (accepted 2026-11-26). | Pass (V78) |
| V. Tested | Export, import, marks, counting and session rules all run without the game, so they get tests. | Pass |
| VI. Boundaries | The logic is in `ns.Share` (Exchange, layer 2) and the frames in `UI/`. The commands are in `Commands.lua`, the new saved field in `core.md` and `CLAUDE.md`, and no new message (SHARED_DATA_CHANGED and SETTINGS_CHANGED as they are). "Smallest change" is weighed for the extension points in Complexity Tracking. | Pass, one justified item |

Re-check after Phase 1: unchanged. The design adds no message, no protected call and no traffic.

## Project Structure

### Documentation (this feature)

```text
specs/027-import-export/
├── plan.md              # this file
├── research.md          # Phase 0
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1
├── contracts/
│   ├── export-string.md     # the string's format and the import's answers
│   └── extension-points.md  # the module functions for code loaded after the addon
├── verification.md      # V78
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
OneKeyFishing/
├── OneKeyFishing.toc            # + Exchange/ShareTransfer.lua (after ShareGame.lua), + UI/TransferPage.lua
├── Core/Core.lua                # ApplyDefaults: shared.imported = {}
├── Core/Debug.lua               # Debug.AddSection; the transfer's line in the report
├── Core/Commands.lua            # share [import|export]
├── Exchange/Share.lua           # Store.CleanUp drops marks of units gone; session rule defaults in P
├── Exchange/ShareNode.lua       # self.rules.gap instead of SESSION_GAP
├── Exchange/ShareProtocol.lua   # self.rules.strangerChance, self.rules.offerOthers
├── Exchange/ShareGame.lua       # SetSessionRules/ResetSessionRules/SessionRules, AddStatusLine, rules in Describe
├── Exchange/ShareTransfer.lua   # NEW: Export, Import, TransferState, IsImported
├── CatchDB/Index.lua            # imported entries, CountedOthers
├── CatchDB/Views.lua            # CountedOthers where Share.IsEnabled() gated Others()
├── UI/Minimap.lua               # ns.MinimapMenu.AddEntries
├── UI/Settings.lua              # SettingsUI.AddPage, SettingsUI.OpenTransfer
├── UI/TransferPage.lua          # NEW: the page
└── Locales/*.lua                # the page's texts, nine translations

tests/
├── exchange/share/transfer_test.lua; protocol_test.lua (the session rules, appended)
├── catchdb/imported_counts_test.lua
├── ui/transfer_page_test.lua, extension_points_test.lua
└── tools/release_files_test.mjs

docs/architecture/exchange.md, catch-db.md, ui.md, core.md; CLAUDE.md; OneKeyFishing/README.md; CHANGELOG.md
```

**Structure Decision**: one more file of `ns.Share` (the module already spans `Share*.lua` and shares `Share.private`),
and one more UI file for the page, so `UI/Settings.lua` (740 lines) does not grow. The page registers itself through
the new `SettingsUI.AddPage`, the same way any later page can.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| Extension points with no use inside the addon (session rules setter, `AddStatusLine`, `AddSection`, `MinimapMenu.AddEntries`; `AddPage` is used by the page itself) | Spec User Story 2: code loaded after the addon in local development builds needs documented entry points. Without them it would patch module internals, which breaks with every refactor. | Leaving them out moves the cost to fragile patches outside the repository. Each point is a few lines, tested, and changes nothing when unused (SC-004). |
