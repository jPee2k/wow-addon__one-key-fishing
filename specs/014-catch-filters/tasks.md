---

description: "Task list for spec 014, catch filters by item kind"
---

# Tasks: Catch Filters by Item Kind

**Input**: Design documents from `specs/014-catch-filters/`

**Prerequisites**:
- [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md)
- [contracts/module-api.md](contracts/module-api.md), [quickstart.md](quickstart.md)

**Tests**: required (constitution Principle V). Each test is written first and seen failing before its code.

**Organization**: grouped by the user stories of spec.md (US1 to US3). Work on `014-catch-filters`; commit only when
the author asks.

**Rules for every task** (CLAUDE.md):
- `npm run check` and `npm test` pass after it; a test written before its code is the only allowed red.
- Addon Lua: ASCII outside `Locales/`, 120-character lines, Lua 5.1/5.3 neutral.
- No Cyrillic in Markdown.
- Write files with LF line endings (`.gitattributes` `eol=lf`).
- A new visible text: a literal English key in `Locales/enUS.lua` and its translation in each of the nine other
  locale files (`deDE`, `esES`, `esMX`, `frFR`, `ukUA`, `koKR`, `ptBR`, `zhTW`, `zhCN`) in the same task; color codes
  outside the strings; no `L[...]` lookup while the files load.
- `GameData/` files: data only (no function, no call, no `L`, no other module); `npm run check` rejects anything else.
- New file in the TOC: the author restarts the game (not only `/reload`).
- No `VERIFY` marker is expected (research R3); if one turns out to be needed, stop and ask the author.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: the user story of spec.md (US1 to US3)

---

## Phase 1: Setup (baseline, stubs)

**Purpose**: the baseline and the test stubs; no addon behaviour yet.

- [X] T001 Run `npm run check` and `npm test` from the repository root on `014-catch-filters`; note the test count and
  the open `VERIFY` markers (one: V51) for the hand-over.
- [X] T002 In `tests/wow.lua`: add the global `item_classes = {}` (documented in the header list next to `known_items`:
  "`item_classes[itemID] = { classID, subClassID }` C_Item.GetItemInfoInstant returns the seven values with these class
  numbers"). `C_Item.GetItemInfoInstant` keeps its present answers (nil for unknown items, the item ID alone otherwise)
  and, when `item_classes[itemID]` is set, returns `itemID, "", "", "", 134400, classID, subClassID`. Check that the
  existing tests that read `classID` (the pole check of `Fishing/Gear.lua`, `tests/fishing/`) still pass; if they
  replace the stub themselves, leave them as they are. `MenuUtil`'s `CreateCheckbox` is already stubbed (`menu_entries`,
  kind `"checkbox"`); nothing to add there.

---

## Phase 2: Foundational (data, kind lookup, saved choice, texts)

**Purpose**: everything both tabs read. Blocks US1 to US3.

- [X] T003 [P] Write `tests/catalog/kinds_test.lua` first (fails until T004 to T007):
  - every ID of data-model "The full `byItem` content" gets its kind from `ns.Catalog.ItemKind`;
  - class rules with `item_classes`: an unlisted item with `{ 7, 8 }` is `"fish"`, `{ 7, 11 }` and `{ 7, 6 }` are
    `"reagents"`, `{ 0, 5 }` and `{ 0, 1 }` are `"potions"`, `{ 15, 0 }` and `{ 4, 0 }` are `"other"`; an item in
    `unknown_items` is `"other"`, and after it leaves `unknown_items` with `{ 7, 8 }` it is `"fish"` (no cache,
    research R3); a listed item keeps its list kind whatever `item_classes` says (5523 with `{ 7, 11 }` is
    `"containers"`); quality is never read (an item stub with quality 0 changes nothing);
  - SC-001: every item ID found in `ns.SeedData.cells` (each cell's `i` keys, and any pool part's `p.i` keys) and every
    key of `ns.GameData.FishedContainers` is a key of `ns.GameData.ItemKinds.byItem`;
  - `Catalog.KINDS` is exactly `{ "fish", "containers", "potions", "reagents", "other" }`;
  - `Catalog.Group(rows)` with rows `{ itemID = ... }` in a given order: groups in `KINDS` order, rows inside a group
    in input order, no empty group, rows untouched (same tables); with `hiddenKinds = { containers = true }` the
    container rows are left out and `hiddenCount` counts them;
  - the saved choice: a fresh install has `ns.db.settings.hiddenKinds` as an empty table; `IsKindShown` is true for
    all five; `SetKindShown("other", false)` sets `hiddenKinds.other = true`, fires `SETTINGS_CHANGED` with
    `"hiddenKinds"` (listen with `ns.On`), and `ShownKinds()` returns `4, 5`; `SetKindShown("other", true)` removes the
    key (nil, not false); a second identical call fires nothing; `SetKindShown("nope", false)` writes and fires
    nothing; a saved `hiddenKinds = { nope = true, fish = true }` gives `ShownKinds() == 4, 5` and `fish` hidden.
  Use the loading helpers of the existing `tests/catalog/*_test.lua` files.
- [X] T004 [P] Create `OneKeyFishing/GameData/ItemKinds.lua` (header comment like `GameData/FishedContainers.lua`:
  "GameData/ItemKinds: the kind of each item the addon knows, and class rules for the rest (specs/014-catch-filters,
  docs/architecture/game-data.md). Data only."): `GameData.ItemKinds = { byItem = { ... }, byClass = { ... } }` with
  exactly the 31 IDs of data-model "The full `byItem` content", one per line with the item's English name as a
  comment (and the in-game class where the spec's table has it), sorted by kind then ID; `byClass = { ["7:8"] = "fish",
  ["7"] = "reagents", ["0"] = "potions" }` with a comment on each. Add `GameData\ItemKinds.lua` to
  `OneKeyFishing/OneKeyFishing.toc` right after `GameData\FishedContainers.lua`.
- [X] T005 [P] Extend `tests/gamedata/shape_test.lua`: every value of `GameData.ItemKinds.byItem` and `byClass` is one
  of the five kind names; every `byItem` key is a positive integer; every `byClass` key matches `^%d+$` or `^%d+:%d+$`.
  Check that `tests/gamedata/load_order_test.lua` (or `tools/addon.mjs`, whichever lists the GameData files) accepts
  the new file; add it there if a list exists.
- [X] T006 In `OneKeyFishing/Core/Core.lua` `DB_DEFAULTS.settings`: add `hiddenKinds = {}` with the comment "the item
  kinds hidden in "What can be caught here" and the catalog (spec 014); written only by Catalog.SetKindShown". No
  `DB_SCHEMA` change.
- [X] T007 In `OneKeyFishing/Catalog/Catalog.lua`, a new section "Item kinds (specs/014-catch-filters)" implementing
  contracts/module-api.md "Catalog/Catalog.lua":
  - `Catalog.KINDS`; `Catalog.ItemKind(itemID)` (data-model "Kind lookup": `byItem`, then
    `byClass[classID .. ":" .. subClassID]`, then `byClass[tostring(classID)]`, then `"other"`; read
    `C_Item.GetItemInfoInstant` only when `byItem` has no entry; no cache);
  - `Catalog.KindText(kind)`: a table `{ fish = "Fish", ... }` of English keys looked up as `L[key]` inside the
    function (never at load);
  - `Catalog.IsKindShown(kind)`, `Catalog.ShownKinds()` (counts only the five names), `Catalog.SetKindShown(kind,
    shown)` (ignores a name not in `KINDS`; writes `ns.db.settings.hiddenKinds[kind] = true` or `nil`; fires
    `ns.Fire("SETTINGS_CHANGED", "hiddenKinds")` only when the value changed);
  - `Catalog.Group(items)` (data-model "Grouped list").
  T003 passes.
- [X] T008 Add the nine new keys of data-model "New texts" to `OneKeyFishing/Locales/enUS.lua` (one block with a
  comment "Item kinds (spec 014)") and their translations to the nine other locale files: `"Fish"`, `"Containers"`,
  `"Potions & drinks"`, `"Reagents & herbs"`, `"Other"`, `"Kinds: all"`, `"Kinds: %d of %d"`,
  `"The kind filter hides every item."`, `"The kind filter hides the matches."`. Translations use the game's own words
  where the game has them (the kind names as fishing players say them in each language), the same placeholders in
  the same order. `npm test` (the locale tests in `tests/core/`) passes.

**Checkpoint**: kinds, grouping and the saved choice work and are tested; no frame changed yet.

---

## Phase 3: User Story 1 - See the catch list grouped by kind (Priority: P1) MVP

**Goal**: both lists show their items under kind headers in the fixed order (FR-006).

**Independent Test**: at a spot with a fish, a chest, a potion and a herb, "What can be caught here" shows four
headers in order with each item under its own; the catalog list is grouped the same way.

- [X] T009 [P] [US1] Write `tests/ui/here_kinds_test.lua` first (model it on `tests/ui/here_page_test.lua`): seed a
  spot with items 6291 (fish), 6355 (container), 858 (potion), 3820 (reagent) and one unknown item (in
  `unknown_items`); open the page; expect the visible rows in this order: header "Fish", 6291, header "Containers",
  6355, header "Potions & drinks", 858, header "Reagents & herbs", 3820, header "Other", the unknown item; a header
  row has no `itemID`, no icon texture and empty chance / per catch / price texts, and its `OnMouseUp` and `OnEnter`
  do nothing; the chance text of 6291 equals the one computed by `ns.CatchDB.Query` for the same filter. With more
  rows than `MAX_ROWS` (seed enough items), "and %d more" counts only the items not shown.
- [X] T010 [P] [US1] Write `tests/ui/catalog_kinds_test.lua` first, the grouping part (model it on
  `tests/ui/catalog_list_test.lua`, which reads the list's elements or rows): with items of three kinds, the list's
  elements are `{ header = "fish" }`, the fish rows by name, `{ header = "containers" }`, ...; a header element draws
  `Catalog.KindText(kind)` in the name text, no icon, empty zones text, and its `OnClick` / `OnEnter` do nothing. Both
  the scroll list and the fixed-rows fallback (the existing fallback test shows how to force it) draw headers.
- [X] T011 [US1] In `OneKeyFishing/UI/CatchHere.lua`: `CreateRow` gets a header mode: a `row.header` font string
  (`GameFontNormal`, anchored like `row.name`), and a function `SetHeader(row, kind)` that hides the icon and the
  column texts, shows `row.header` with `ns.Catalog.KindText(kind)`, and clears `row.itemID` / `row.unknown` (so the
  existing `OnEnter` / `OnMouseUp` guards already do nothing); `FillRow` hides `row.header` and shows the columns.
  `CatchHere.Refresh` passes `view.items` through `ns.Catalog.Group` and fills `page.rows` in group order, a header row
  before each group, until `MAX_ROWS` rows are used; "and %d more" is the number of items (not headers) not drawn.
  Update the file's header comment. T009 passes.
- [X] T012 [US1] In `OneKeyFishing/UI/CatalogTab.lua`: `ShowList` passes the rows of `ns.Catalog.Items(filter, search)`
  through `ns.Catalog.Group` and builds the elements `{ header = kind }` followed by that group's rows;
  `InitItemRow` draws a header element (name text = `ns.Catalog.KindText(element.header)` in `GameFontNormal`, icon
  hidden, zones text empty, `row.itemID = nil`; the `OnEnter` and `OnClick` scripts return at once when
  `row.itemID` is nil) and restores the item look for an item element (icon shown, `GameFontHighlight`). `StatusText`
  receives the item count before the kind filter so its present cases are unchanged. T010 passes.

**Checkpoint**: both lists are grouped; with the default (nothing hidden) every item is shown.

---

## Phase 4: User Story 2 - Hide the kinds the player does not care about (Priority: P1)

**Goal**: a kind menu in both tabs hides kinds, one remembered choice (FR-007 to FR-011).

**Independent Test**: untick every kind but Fish in "What can be caught here": only fish; the catalog: only fish;
`/reload` (in the tests: a fresh load with the same saved table): unchanged.

- [X] T013 [P] [US2] Extend `tests/ui/here_kinds_test.lua`: the page has a kind button reading "Kinds: all"; clicking it
  builds a menu (`menu_entries`) of five `"checkbox"` entries with the kind texts in `KINDS` order, each `isSelected()`
  true; calling the containers entry's `onClick` hides containers (`ns.db.settings.hiddenKinds`), and right after the
  call, with no tick, the page shows no Containers header and no 6355 (FR-007 "at once"), the button reads "Kinds: 4 of
  5", and every remaining row's chance, per catch and price texts are unchanged, and so are the scope line and the
  counts line with its players (FR-010, SC-004); with every kind hidden the rows are empty and the message is "The kind
  filter hides every item." (not "Nothing has been caught here yet."); the skill, source and water buttons still exist
  and the four buttons are 130 wide, the kind button third, the water button (with pool data) fourth.
- [X] T014 [P] [US2] Extend `tests/ui/catalog_kinds_test.lua`: the catalog has the same kind button; a kind hidden from
  the catch tab's menu is hidden in the catalog list too (one choice); with every kind hidden the status is "The kind
  filter hides every item."; with a search whose matches are all hidden it is "The kind filter hides the matches.";
  with no data the present text ("Nothing has been caught yet." ...) still shows; a saved
  `hiddenKinds = { containers = true }` loaded at start hides containers at the first draw (the remembered choice,
  FR-008); a toggle from the catalog's own kind button updates its list right after the click, with no tick
  (FR-007); with containers hidden, `ns.Catalog.TooltipLines(21113)` returns the same lines as with nothing hidden
  (spec edge case: tooltips are not filtered).
- [X] T015 [US2] In `OneKeyFishing/UI/Widgets.lua`: `ns.OpenCheckboxMenu(owner, choices, isChecked, toggle)` next to
  `ns.OpenRadioMenu`: without `MenuUtil.CreateContextMenu` nothing; per choice `root:CreateCheckbox(choice.text,
  function() return isChecked(choice.value) end, function() toggle(choice.value) end)` when `root.CreateCheckbox`
  exists (Blizzard's checkbox keeps the menu open: `MenuResponse.Refresh`, research R6), else `root:CreateButton` with
  `CHECK_MARK` before a checked text (that menu closes after each click: FR-007 "where the client's menu supports
  checkboxes").
- [X] T016 [US2] In `OneKeyFishing/UI/CatchHere.lua`: `CatchHere.OpenKindMenu(owner)` opens `ns.OpenCheckboxMenu` over
  `ns.Catalog.KINDS` with `ns.Catalog.KindText`, `ns.Catalog.IsKindShown` and a toggle calling
  `ns.Catalog.SetKindShown(kind, not ns.Catalog.IsKindShown(kind))` and then `CatchHere.Refresh()` and
  `ns.CatalogTab.Refresh(true)` (each returns at once when its page is hidden), so the list follows the click at once;
  `page.kindButton` (third place, after the source button); the water button anchored after the kind button; all four
  buttons 130 wide; the button text in `Refresh`: `L["Kinds: all"]` when `ShownKinds()` is 5 of 5, else `(L["Kinds: %d
  of %d"]):format(ns.Catalog.ShownKinds())`; when `view.items` is not empty but `Group` returns no group, `page.message`
  is `L["The kind filter hides every item."]`. The existing `SETTINGS_CHANGED` -> `MarkDirty` stays as the fallback for
  the other tab. T013 passes.
- [X] T017 [US2] In `OneKeyFishing/UI/CatalogTab.lua`: the same kind button in the list view (third place, through
  `ns.CatchHere.OpenKindMenu`), the water button after it, the four buttons 130 wide; its text set in `Refresh` like
  the catch tab's; `StatusText(items, state, hiddenCount)`: when the index is ready, rows exist and none is shown, it
  returns `L["The kind filter hides the matches."]` with a search and `L["The kind filter hides every item."]`
  without; the other cases stay as they are and come first only when there are no rows at all. T014 passes.

**Checkpoint**: the menu hides kinds in both tabs, the choice is kept, the empty states say why.

---

## Phase 5: User Story 3 - The catalog still finds a hidden item on request (Priority: P3)

**Goal**: opening one item by ID ignores the kind filter (FR-012).

**Independent Test**: hide Containers, open the catalog for 21113 by ID: its zones and spots show.

- [X] T018 [US3] Extend `tests/ui/catalog_kinds_test.lua`: with `hiddenKinds = { containers = true }`,
  `ns.CatalogTab.Show(21113)` (and `ns.StatsFrame.OpenCatalog(21113)`, the path of a link and of the catch tab) shows
  the item view with its zone rows (as `catalog_list_test.lua` reads them), and `Back` returns to a list without
  containers; the command path with an item link (`ns.Catalog.CommandArg` of
  `"|cffffffff|Hitem:21113::::::::|h[Watertight Trunk]|h|r"`, passed to `ns.StatsFrame.OpenCatalog`, as
  `Core/Commands.lua:8` does) opens the item too; `CatalogTab.Show("Watertight")` (a name) fills the search, chooses
  nothing, and the status reads "The kind filter hides the matches.". If the test passes without code changes (research
  R9 expects it), keep it as the guard of FR-012 and note that in the task; else fix `OneKeyFishing/UI/CatalogTab.lua`
  so that `Show(itemID)` never reads the kind choice.
  **Done note**: the ID paths passed without a change; the name search did not (a single hidden match was chosen),
  so `CatalogTab.Show` now chooses a single match by name only when its kind is shown (research R9).

**Checkpoint**: all three stories work.

---

## Phase 6: Polish and cross-cutting

- [X] T019 [P] In `OneKeyFishing/Catalog/Catalog.lua` `Catalog.Describe()`: add the line `kinds hidden: <names in KINDS
  order, comma-separated>` or `kinds hidden: none` (debug report, not localized); append it as the last line, so the
  first-line check of "no index yet" stays valid; extend `tests/catalog/index_test.lua` (its `describe()` helper, lines
  71-104) to expect it.
- [X] T020 [P] Documentation, in English:
  - `CLAUDE.md`: in the module table, `GameData/*.lua` gains `ItemKinds`; the `Catalog/Catalog.lua` job adds "the
    item kinds and the kind choice"; a cross-module rule "The kind choice by `Catalog.SetKindShown`, never by a write
    of `settings.hiddenKinds` (it fires `SETTINGS_CHANGED`)."; `SETTINGS_CHANGED` needs no change (the key is data).
  - `docs/architecture/catalog.md`: a section "Item kinds" (the lookup order, `Group`, the choice, why the filter is
    applied after the views: research R2).
  - `docs/architecture/game-data.md`: the `ItemKinds` entity (byItem, byClass, the SC-001 test).
  - `docs/architecture/ui.md`: the kind button, the header rows of both tabs, `ns.OpenCheckboxMenu`, the 130-wide
    filter buttons.
  - `docs/architecture/core.md`: `settings.hiddenKinds` in the list of saved fields.
  - `docs/development.md` (or wherever the harvest is described): after `npm run harvest`, a new seed item fails
    `tests/catalog/kinds_test.lua` until it gets a kind in `GameData/ItemKinds.lua`.
- [X] T021 [P] `docs/checklists/catch-filters.md` following `docs/checklists/README.md` "How a checklist is built":
  header (feature, `specs/014-catch-filters`, closes no `VERIFY`, needs one character with the bundled data), setup
  (a game restart: new file in the TOC), the six steps of quickstart.md "In game" with `[ ]` boxes, a step for the
  longest translations of the filter buttons (for example `deDE`, `frFR`, `ukUA`), results; add its
  row to the table in `docs/checklists/README.md`.
- [X] T022 `CHANGELOG.md` under `## [Unreleased]` / `### Added`: "Catch kinds in **What can be caught here** and the
  **catch catalog**: the items are grouped under Fish, Containers, Potions & drinks, Reagents & herbs and Other, and
  the **Kinds** button hides the kinds you do not want; the choice is kept." `OneKeyFishing/README.md`: in "What can
  be caught here" and "Catch catalog", the grouping, the Kinds button (both tabs share it, it is remembered, a link
  still opens a hidden item), and the message when the filter hides everything.
- [X] T023 Run `npm run check` and `npm test`; compare with T001 (the new tests added, nothing else changed, one open
  `VERIFY` marker, V51). Walk through quickstart.md "Automated" and confirm each listed test exists and fails without
  its change (revert the change locally once per test file, then restore it). Hand the author
  `docs/checklists/catch-filters.md` and remind them that the TOC changed (a game restart).

---

## Dependencies and execution order

### Phase dependencies

- **Setup (Phase 1)**: none.
- **Foundational (Phase 2)**: after Setup; blocks every story. T003 before T007; T004 before T005 and T007; T006 before
  T007; T008 before any UI task.
- **US1 (Phase 3)**: after Phase 2.
- **US2 (Phase 4)**: after Phase 2; T016 and T017 edit the files T011 and T012 edit, so they follow US1 in practice.
- **US3 (Phase 5)**: after T012 and T017 (it reads the catalog's list and status).
- **Polish (Phase 6)**: after the stories; T019 to T021 in parallel, T022 then T023 last.

### Within each story

- The test task first, seen failing; then the code until it passes.
- One file is edited by one task at a time (`UI/CatchHere.lua`: T011 then T016; `UI/CatalogTab.lua`: T012, T017,
  then T018 if it needs code).

### Parallel opportunities

- T003, T004, T005 (three different files) once T002 is done.
- T009 and T010 (two new test files); T013 and T014 (two test files).
- T019, T020, T021 in the polish phase.

## Parallel example: Foundational

```text
Task: "Write tests/catalog/kinds_test.lua first (T003)"
Task: "Create OneKeyFishing/GameData/ItemKinds.lua and its TOC line (T004)"
Task: "Extend tests/gamedata/shape_test.lua (T005)"
```

## Implementation strategy

### MVP first

1. Phase 1 and Phase 2.
2. Phase 3 (US1): the grouping alone already removes the "one pile"; stop and validate (`npm test`).

### Incremental delivery

1. US1: grouping.
2. US2: the kind menu and the remembered choice (the request's "filters").
3. US3: the guard that a direct request still opens a hidden item.
4. Polish: debug line, documents, checklist, changelog and manual.

## Notes

- [P] tasks touch different files and depend on no unfinished task.
- No commit unless the author asks.
- The game is never run by Claude: the in-game look is the author's, through `docs/checklists/catch-filters.md`.
