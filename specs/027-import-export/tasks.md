# Tasks: Import and Export of Catch Records

**Input**: Design documents from `specs/027-import-export/` ([plan.md](plan.md), [spec.md](spec.md),
[research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md))

**Tests**: required by the project (constitution V: logic that runs without the game has a test).

Paths are relative to the repository root.

## Phase 1: Setup

- [x] T001 Add `Exchange/ShareTransfer.lua` after `Exchange/ShareGame.lua`, and `UI/TransferPage.lua` after `UI/Settings.lua`, in `OneKeyFishing/OneKeyFishing.toc`. Add the two files with their header comment and `local _, ns = ...`, and list them in the test loader if it keeps a file list (`tests/wow.lua`).
- [x] T002 [P] Add `shared.imported = {}` to the account defaults in `OneKeyFishing/Core/Core.lua` (`ApplyDefaults`; no `DB_SCHEMA` change).

## Phase 2: Foundational

- [x] T003 Add the imported marks in `OneKeyFishing/Exchange/ShareTransfer.lua`:
  - `Share.IsImported(unit)`, reading `ns.db.shared.imported`;
  - in `OneKeyFishing/Exchange/Share.lua` `Store.CleanUp`, drop the marks of units no longer under `store.records`, for stores that hold an `imported` table.
- [x] T004 Add the imported indexes in `OneKeyFishing/CatchDB/Index.lua`:
  - `IndexRecord` also files the entries of a marked unit (`ns.Share.IsImported(key)`) in `P.importedOthers` (`byKey`, `byPrefix`, `byRecord`, the same entry tables), and `UnindexRecord` removes them;
  - add `CountedOthers()`: `Others()` while `ns.Share.IsEnabled()`, else the imported indexes;
  - keep both indexes in step in the `SHARED_DATA_CHANGED` handler (`OneKeyFishing/CatchDB/Events.lua`).
- [x] T005 Replace each `ns.Share.IsEnabled() and Others()` gate with `CountedOthers()` in `OneKeyFishing/CatchDB/Views.lua`: `Sources`, the map list, `EachHeldCells` with `sharingOnly`, `ScanItems`, and any other read of others' cells under that gate. A marked unit counts with sharing off; nothing else changes with sharing on.
- [x] T006 [P] Test in `tests/catchdb/imported_counts_test.lua`:
  - with sharing off, a marked record's cells count in the place view, the map list and the catalog, while an unmarked one's do not;
  - with sharing on, both count;
  - a newer version of a marked unit stays counted;
  - `CleanUp` drops the mark of a unit removed.

**Checkpoint**: counting works with marks set by hand; no UI yet.

## Phase 3: User Story 1 - A player exports their catch data and another imports it (Priority: P1) 🎯 MVP

**Goal**: a string out of one store and into another, with every check of the exchange, counting at once.

**Independent Test**: export store A, import into empty store B: B holds the same records. Damaged, cut, altered or
unknown-format strings store nothing. Forged records are refused one by one.

### Tests for User Story 1

- [x] T007 [P] [US1] Write the round trip and guarantees of `specs/027-import-export/contracts/export-string.md` in `tests/exchange/share/transfer_test.lua`:
  - the own units come first;
  - the text stays under `EXPORT_LIMIT` (262,144 characters) with the freshest `seen` first;
  - a second import gives new = 0, and importing one's own export gives own and known;
  - with sharing off, the export holds only the own units and the marked ones.
- [x] T008 [P] [US1] Write the refusals in `tests/exchange/share/transfer_test.lua` (one file with T007):
  - no `OKF:` gives `empty`;
  - no `:END`, or a count unequal to the tokens, gives `cut`;
  - format `2` gives `format`;
  - one changed character gives `damaged`, and nothing is stored in any of these cases;
  - in a valid string, a record with a broken chain, impossible numbers or a blocked ID is counted refused and the rest is new;
  - a record the seed holds whole is known;
  - whitespace and text around the markers are ignored.
- [x] T009 [P] [US1] Write the steps and marks in `tests/exchange/share/transfer_test.lua`:
  - an import at the limit runs over many `env.after(0)` steps, none over the budget on a fake clock;
  - a second `Import` while one runs answers `busy`;
  - marks are set for new and known records, are not left on refused ones, and are set before `SHARED_DATA_CHANGED`, so the index sees them;
  - import works with sharing off.

### Implementation for User Story 1

- [x] T010 [US1] Implement `Share.Export()` in `OneKeyFishing/Exchange/ShareTransfer.lua` (research R1, R3), in frame steps within `P.WithinBudget`:
  1. call `ns.CatchDB.FlushSeq()`;
  2. take the own units first (proof ready, cells of a game version, `CheckRecord`, at most `MAX_RECORD_BYTES`);
  3. then the others by `seen`, newest first, each checked again, and only the marked units with sharing off;
  4. stop before `EXPORT_LIMIT = 256 * 1024`;
  5. build `OKF:1:<count>:<check>:<tokens>:END`, with `<check>` = `ns.Base32(Share.Hash(tokens joined by ","), 7)`;
  6. keep `{ text, records, bytes }` in the transfer state.
- [x] T011 [US1] Implement `Share.Import(text)` in `OneKeyFishing/Exchange/ShareTransfer.lua` (research R2, R4, R5):
  1. strip whitespace, find the markers, and check the format and the count;
  2. compute the checksum in slices of about 16 KB per step;
  3. for each token, one per step: `Share.Decode`, `CheckRecord`, the own-ID test, then for a newer version `CheckVersion(held, record, PROOF_CHUNK, state)` within the budget;
  4. set the mark, call `Store.Accept(..., true)` and `Store.Evict`, take a refused mark back, and give a known record's unit a `Changed` of its own;
  5. tally new, known, own and refused;
  - refuse a second import with `busy`;
  - add `Share.TransferState()`, which returns a copy (data-model "Transfer state").
- [x] T012 [US1] Add `SettingsUI.AddPage(frame, title)` in `OneKeyFishing/UI/Settings.lua`: queue the page before the `PLAYER_LOGIN` registration, register it after the addon's pages, and return an opener that refuses in combat like `OpenCategory`. Add `SettingsUI.OpenTransfer(choice)`, which forwards to the page's opener and choice.
- [x] T013 [US1] Build the page in `OneKeyFishing/UI/TransferPage.lua` (research R9):
  - the title "Import and export", two radio buttons Import and Export (Import selected on open), and a scroll frame with a multi-line `EditBox` (`SetMaxLetters(0)`, `-- VERIFY(V78)` at it);
  - the hint below, and an **Import** button on the Import side, disabled while busy;
  - Export: "Preparing..." until the string is ready, then the text set, selected and focused, read-only as in `UI/CopyWindow.lua`;
  - Import: an empty, focused box; the button calls `Share.Import`;
  - an `OnUpdate` while shown polls `Share.TransferState()` and writes the result or error into the hint;
  - register the page through `SettingsUI.AddPage`.
- [x] T014 [US1] Make the `share` entry in `OneKeyFishing/Core/Commands.lua` take `rest`: `import` and `export` call `ns.SettingsUI.OpenTransfer`, and anything else prints the status as today. Update its description: "show the state of the shared catch database; import or export opens that page".
- [x] T015 [P] [US1] Add every new text to `OneKeyFishing/Locales/enUS.lua` and its nine translations in `OneKeyFishing/Locales/<code>.lua`, color codes outside the strings:
  - the page title, the radio labels and the button;
  - the hints on both sides: what an export holds (an anonymous ID and catch counts per place, no names), copy with Ctrl+C, paste with Ctrl+V;
  - "Preparing...", the size line, the four counts and the four errors, and "busy".
- [x] T016 [P] [US1] Test the page in `tests/ui/transfer_page_test.lua`:
  - it opens on Import with an empty, focused box;
  - Export fills and selects the box;
  - Import with a string shows the counts, and an error shows its text;
  - the button is disabled while busy;
  - `/okf share import` and `/okf share export` open it on that choice.

**Checkpoint**: US1 is complete and testable on its own (MVP).

## Phase 4: User Story 2 - Code loaded after the addon can extend it (Priority: P3)

**Goal**: documented extension points that change nothing while unused.

**Independent Test**: the defaults keep today's numbers (the simulation); set rules change a node; added lines,
sections, entries and pages show after the addon's own items.

### Tests for User Story 2

- [x] T017 [P] [US2] Test the session rules in `tests/exchange/share/protocol_test.lua` (appended: its fake network is there):
  - a fresh node's rules are `{ gap = 120, strangerChance = nil, offerOthers = true }`;
  - `gap = 30` lets a start follow 30 s after the last one;
  - `strangerChance = 1` starts with every differing channel `HELLO` (no near peer waiting);
  - `offerOthers = false` answers a `WANT` with the own units only;
  - `gap = 5` is clamped to 15;
  - `ResetSessionRules` restores the defaults;
  - the 30 min pause per peer holds under every rule.
- [x] T018 [P] [US2] Test the registries in `tests/ui/extension_points_test.lua`:
  - with nothing added, the `/okf share` lines, the debug report and the minimap menu are as before;
  - an added line, section, menu entry and page show after the addon's own;
  - a failing one adds nothing and leaves the rest (a report section shows `!! failed`).

### Implementation for User Story 2

- [x] T019 [US2] Give each node `rules` (defaults from `P`) in `Share.NewNode`, in `OneKeyFishing/Exchange/ShareNode.lua`. Read `self.rules.gap` at the three `SESSION_GAP` uses, and leave `RESPONDER_GAP` as it is.
- [x] T020 [US2] Read the stranger chance and the offers from the node's rules in `OneKeyFishing/Exchange/ShareProtocol.lua`:
  - use `self.rules.strangerChance or math.min(1, CHANNEL_TARGET / math.max(1, heard or 0))`;
  - in the `WANT` answer, skip units whose record is not of the own ID when `self.rules.offerOthers == false`.
- [x] T021 [US2] Add the rule functions and the status lines in `OneKeyFishing/Exchange/ShareGame.lua`:
  - `Share.SetSessionRules(rules)` (merge, clamp `gap >= 15` and `strangerChance` to 0..1, apply to the game node), `Share.ResetSessionRules()` and `Share.SessionRules()` (a copy);
  - a node made later takes the current rules;
  - show the rules in `Share.Describe()`;
  - add `Share.AddStatusLine(fn)`, printed after the addon's lines in `Share.PrintStatus`, each call through `ns.Safe`.
- [x] T022 [P] [US2] Add `Debug.AddSection(title, fn)` in `OneKeyFishing/Core/Debug.lua`, run through `Section` after the addon's sections.
- [x] T023 [P] [US2] Add `ns.MinimapMenu = { AddEntries = fn }` in `OneKeyFishing/UI/Minimap.lua`; each `fn(root)` runs in `pcall` after the "Debug report" button.
- [x] T024 [US2] Run the channel simulation with the default rules (`tests/exchange/channel/sim_test.lua`) and confirm that its numbers are unchanged (SC-004).

## Phase 5: Polish & Cross-Cutting Concerns

- [x] T025 [P] Add a test in `tests/tools/release_files_test.mjs`: the release file list of `tools/addon.mjs` holds only the TOC, its files, `Bindings.xml`, `README.md` and `Media/*.ogg`, and a Lua file outside the TOC in the addon folder is not in it (FR-016).
- [x] T026 [P] Document the work in the architecture docs:
  - `docs/architecture/exchange.md`: a section on `ShareTransfer.lua` (format, steps, tally, marks, `TransferState`), the session rules and `AddStatusLine`;
  - `docs/architecture/catch-db.md`: `CountedOthers` and the imported indexes;
  - `docs/architecture/ui.md`: `TransferPage.lua`, `SettingsUI.AddPage` and `OpenTransfer`, `MinimapMenu.AddEntries`;
  - `docs/architecture/core.md`: the field `shared.imported` and `Debug.AddSection`.
- [x] T027 [P] Update `CLAUDE.md`:
  - the module table gets `Exchange/ShareTransfer.lua` (in the Exchange row) and `UI/TransferPage.lua` (in the UI row);
  - add a cross-module rule: marks only through `Share.Import`, and the views read others' cells only through `CountedOthers`;
  - add 027 to the features with a `verification.md`.
- [x] T028 [P] Update the player manual `OneKeyFishing/README.md`:
  - a section "Import and export" (the page, the two commands, what an export holds, the counts, imported data counting with sharing off);
  - a paragraph on Battle.net friends of the other faction carrying records across;
  - `/okf share import` and `/okf share export` in the command list.
- [x] T029 [P] Add the change under `[Unreleased]` in `CHANGELOG.md`.
- [x] T030 [P] Write the in-game checklist `docs/checklists/import-export.md` (template in `docs/checklists/README.md`): the steps of the quickstart's "In game" with V78 as step 5. List it in the README's order.
- [x] T031 Run `npm run check` and `npm test`, and fix every failure (luacheck globals, the manual's commands, line length, the translations' keys).

## Dependencies & Execution Order

- Phase 1, then Phase 2 (T003 before T004 and T005; T006 after them).
- US1 (Phase 3) needs Phase 2. T010 and T011 before T013; T012 before T013; T014 after T012.
- US2 (Phase 4) is independent of US1 except `SettingsUI.AddPage` (T012), which US1 already brings. T019 before
  T020 and T021.
- Polish after both stories.

## Parallel Opportunities

- T002 next to T001; T006 once T005 is done.
- US1 tests T007, T008 and T009 together; T015 and T016 next to T013.
- US2 tests T017 and T018 together; T022 and T023 next to T019-T021.
- Polish: T025-T030 together, then T031.

## Implementation Strategy

1. MVP: Phases 1-3, then `npm test`. Import and export work for players.
2. Then Phase 4 (the extension points) and the check that the simulation is unchanged.
3. Polish: docs, manual, changelog, checklist; `npm run check` and `npm test` green.

## Phase 6: Convergence

- [x] T032 Add a test in `tests/exchange/share/transfer_test.lua`: with sharing off, a string imported by `Share.Import` counts at once in `ns.CatchDB.Query` (the mark is set before `Store.Accept` fires `SHARED_DATA_CHANGED`), while a record received earlier through the exchange still does not, per US1/AC5 and T009 (partial)
- [x] T033 Add a test in `tests/exchange/share/channel_sessions_test.lua` (its fake channel is there): a node with `rules.strangerChance = 1` starts a session on every differing channel `HELLO` whatever `H` is, and with `strangerChance = 0` on none, per T017 and FR-014 (partial)
- [x] T034 Add a test in `tests/exchange/share/transfer_test.lua`: a record whose version the bundled seed holds whole (a test seed through `load_addon(beforeLogin)`) is counted as known and not stored, per T008 and the spec's edge case "A record whose versions the bundled database already holds whole" (partial)
- [x] T035 Make `specs/027-import-export/data-model.md` "Index additions" name what the code builds: the imported sets live in `CatchDB.private.others.imported` (`byKey`, `byPrefix`, `byRecord`), not a separate `importedOthers` table, per plan: data model (partial)
- [x] T036 Remove the test-only table `ns.TransferPage` from `OneKeyFishing/UI/TransferPage.lua`; drive the page in `tests/ui/transfer_page_test.lua` through `settings_pages[L["Import and export"]]` and `ns.SettingsUI.OpenTransfer(choice)`, per plan: structure (no module table beyond the page) (unrequested)
