---

description: "Task list for spec 017, catalog sorting"
---

# Tasks: Catalog Sorting

**Input**: Design documents from `specs/017-catalog-sort/`

**Prerequisites**:
- [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md)
- [contracts/module-api.md](contracts/module-api.md), [quickstart.md](quickstart.md)

**Tests**: required (constitution Principle V). Each test is written first and seen failing before its code.

**Organization**: grouped by the user stories of spec.md (US1 to US4). Work on `017-catalog-sort`; commit only when
the author asks.

**The draft**: before the agreement a draft was written on the branch (uncommitted): `Catalog/Catalog.lua` (`SORTS`,
`GetSort`, `SetSort`, `SortText`, `SortRows`, the `chance` / `littleData` row fields), `Core/Core.lua` (the default),
`UI/CatalogTab.lua` (Sort button with Water after it in row 3, Kinds still at the top right, `RightColumn` without
"No price", the `catalogSort` redraw) and the keys `"Sort: %s"` / `"Name"` in the ten locale files. A task that names
draft code checks it against this list, keeps what matches and changes the rest; its test is still written first and
must fail when the draft's part is taken out (revert that part briefly, or check the test against `develop`).

**Rules for every task** (CLAUDE.md):
- `npm run check` and `npm test` pass after it; a test written before its code is the only allowed red.
- Addon Lua: ASCII outside `Locales/`, 120-character lines, Lua 5.1/5.3 neutral.
- No Cyrillic in Markdown.
- Write files with LF line endings (`.gitattributes` `eol=lf`).
- A new visible text: a literal English key in `Locales/enUS.lua` and its translation in each of the nine other
  locale files (`deDE`, `esES`, `esMX`, `frFR`, `ukUA`, `koKR`, `ptBR`, `zhTW`, `zhCN`) in the same task; color codes
  outside the strings; no `L[...]` lookup while the files load.
- No `VERIFY` marker is expected (research R11); if one turns out to be needed, stop and ask the author.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: the user story of spec.md (US1 to US4)

---

## Phase 1: Setup (baseline, stubs)

**Purpose**: the baseline and the test stubs; no addon behaviour.

- [X] T001 Run `npm run check` and `npm test` from the repository root on `017-catalog-sort` (with the draft); note
  the test count and the open `VERIFY` markers for the hand-over.
- [X] T002 In `tests/wow.lua` (the `Frame` methods near `Frame:SetWidth`): `Frame:SetPoint(...)` appends
  `{ ... }` (the raw arguments) to `self.points` (created on first use); `Frame:ClearAllPoints()` sets
  `self.points = {}`; `Frame:SetTextColor(r, g, b, a)` stores `self.textColor = { r, g, b, a }`. Font strings and
  textures are frames in the stub, so they get the same methods. Add a helper `anchor(frame, point)` that returns
  the recorded point table whose first argument is `point` (`"TOPLEFT"`, `"LEFT"`, ...), or without `point` the first
  recorded one, or nil; a frame anchored twice (the scroll list: `TOPLEFT`, then `BOTTOMRIGHT`) is read by name.
  In the `MenuUtil` stub's `MenuRoot`, add `function root:CreateRadio(text, isSelected, onClick) return Add("radio",
  text, isSelected, onClick) end` and let `Add` store `isSelected` and `onClick` for `"radio"` as it does for
  `"checkbox"` (today `ns.OpenRadioMenu` falls back to buttons with a check mark in their text in the tests; no present
  test reads that fallback). Document both in the file's header list. Check that every present test still passes
  (they called `SetPoint`, `ClearAllPoints` and `SetTextColor` as no-ops until now).

---

## Phase 2: Foundational (the saved order, its texts)

**Purpose**: what every story reads. Blocks US1 to US4.

- [X] T003 [P] Write `tests/catalog/sort_test.lua` first, the setting part (load like `tests/catalog/kinds_test.lua`):
  `Catalog.SORTS` is exactly `{ "name", "price", "chance" }`; a fresh install has `ns.db.settings.catalogSort ==
  "name"` and `GetSort() == "name"`; `SetSort("price")` writes `"price"` and fires `SETTINGS_CHANGED` once with
  `"catalogSort"` (listen with `ns.On`); a second `SetSort("price")` fires nothing; `SetSort("nope")` writes and fires
  nothing; a saved `catalogSort = "later"` (set directly) gives `GetSort() == "name"` and is left as it is;
  `SortText` returns `L["Name"]`, `L["Price"]`, `L["Chance"]` for the three orders and `L["Name"]` for anything else.
  Also define in this file a local helper `settle(filter, search)` modelled on `tests/catalog/index_test.lua`'s
  `settle()`: `Catalog.Items(filter, search)`, then `advance(0)` (the index is built in frame steps; a new filter's
  index starts empty, and the default one only 10 s after the loading screen), then return
  `Catalog.Items(filter, search)` after asserting its state is `"ready"`. T007 and T011 read every list through it.
- [X] T004 In `OneKeyFishing/Core/Core.lua` `DB_DEFAULTS.settings` (draft): `catalogSort = "name"` after
  `hiddenKinds`, with the comment "The order of the catalog's list (spec 017): "name", "price" or "chance"; written
  only by Catalog.SetSort." No `DB_SCHEMA` change.
- [X] T005 In `OneKeyFishing/Catalog/Catalog.lua` (draft), the section "The list's order
  (specs/017-catalog-sort)" before `Catalog.Items`, per contracts/module-api.md: `Catalog.SORTS`, `Catalog.GetSort()`
  (`"name"` when `ns.db` is missing or the value is no order), `Catalog.SetSort(sort)` (writes and fires
  `ns.Fire("SETTINGS_CHANGED", "catalogSort")` only for a known, different value), `Catalog.SortText(sort)` (`L[...]`
  inside the function). Update the file's header comment: the catalog now sends two setting messages, `hiddenKinds`
  and `catalogSort`. T003 passes.
- [X] T006 [P] Texts (draft has the first two): `"Sort: %s"`, `"Name"`, `"No price"` in `OneKeyFishing/Locales/enUS.lua`
  (one block, comment "Catalog.lua, UI/CatalogTab.lua: the order of the catalog's list (spec 017)") and their
  translations in the nine other locale files, in the same order, the `%s` kept; short words as the game uses them
  (deDE "Sortierung: %s" / "Name" / "Kein Preis", esES and esMX "Orden: %s" / "Nombre" / "Sin precio", frFR
  "Tri : %s" / "Nom" / "Sans prix", ptBR "Ordem: %s" / "Nome" / "Sem preço", koKR, zhCN, zhTW and ukUA in their
  own words). The locale tests in `tests/core/` pass.

**Checkpoint**: the order is a tested setting; nothing is sorted yet.

---

## Phase 3: User Story 1 - Sort the catalog by price (Priority: P1) MVP

**Goal**: Sort: Price orders each kind group by the statistics' price, highest first, with the price in each row and
"No price" last (FR-001 to FR-004, FR-006 to FR-009).

**Independent Test**: with known prices, choose Price in the Sort menu: inside each kind the items run from the
highest price down, each row shows its price, an item without one is last with "No price" in grey.

- [X] T007 [P] [US1] Extend `tests/catalog/sort_test.lua`, the price part (SC-002: at least ten items): a seed cell
  `["1415:3:47"] = catch_cell(110, 0, { ... })` holding eleven items 90101 to 90111, 10 catches each
  (`{ 10, 10 }`), named through `item_names` "Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "Golf",
  "Hotel", "India", "Juliet", "Kilo" (A to K below); K is grey (`item_qualities[K] = 0`).
  `item_prices` (vendor): A 5, B 100, C 50, D 0, E 100, F 20, G 0, H 75, I 20, J 1, K 30. A trusted auction price for
  C (`ns.db.prices[C] = { price = 500, quantity = 20, lots = 10, time = 1 }`) and a few-lots one for D
  (`{ price = 9999, quantity = 1, lots = 1, time = 1 }`). Every list below is read through `settle` of T003 (with
  `ALL`, or the search given). Expectations with `SetSort("price")`:
  - `Catalog.Items(ALL)` gives C, B, E, H, F, I, A, J, D, G (B before E and F before I: ties by name; D and G last,
    D before G by name: the few-lots price is not used; K left out: grey without a search);
  - with `settings.auctionPrices = false`: B, E, H, C, F, I, A, J, D, G;
  - with the search "o" (Bravo, Echo, Foxtrot, Golf, Hotel, Kilo): B, E, H, K, F, G (the grey K ordered with the
    others by its price, spec edge case);
  - every adjacent pair has a price not increasing, or equal prices in name order (SC-002); each price used equals
    `ns.Prices.Get(itemID)` (SC-003);
  - `SetSort("name")` gives A to J exactly as before (SC-005); the rows are the same tables in both orders (not
    copied).
- [X] T008 [US1] In `OneKeyFishing/Catalog/Catalog.lua` (draft): `SortRows(list)` (research R1, R3) called by
  `Catalog.Items` after the search and the Poor rule: for `"price"` a key table filled once per row with
  `ns.Prices.Get(row.itemID)` (never inside the comparator), descending, ties by the row's position (the name order);
  `"name"` returns at once. `Catalog.Find` stays by name. Update the comment of `Catalog.Items`. T007 passes.
- [X] T009 [P] [US1] Write `tests/ui/catalog_sort_test.lua` first, the price part (model it on
  `tests/ui/catalog_kinds_test.lua`: open the window, choose the catalog tab, `advance(0)`, `tick`). The data, exactly
  (also used by T013 and T016; no `item_names`, so the stub names the items "Item <id>"):
  - seed cells: `["1415:3:47"] = catch_cell(100, 0, { [6291] = { 50, 50 }, [6303] = { 30, 30 }, [6355] = { 10, 10 },
    [21113] = { 10, 10 } })`; `["1416:3:11"] = catch_cell(60, 0, { [6303] = { 50, 50 }, [21150] = { 10, 10 } })`;
    `["1417:3:11"] = catch_cell(10, 0, { [6289] = { 10, 10 } })` (little data: 10 catches on the map);
  - fish 6291, 6303, 6289, containers 6355, 21113, 21150 (their kinds by `GameData.ItemKinds`);
  - `item_prices`: 6291 300, 6303 200, 6289 100, 6355 50, 21113 80; 21150 has no `item_prices` and no
    `ns.db.prices` entry (no price).
  Expectations: the Sort button reads `(L["Sort: %s"]):format(L["Name"])`; its `OnClick` builds a menu
  (`menu_entries`) of three `"radio"` entries (T002) with the texts `L["Name"]`, `L["Price"]`, `L["Chance"]`, only
  Name's `isSelected()` true; the Price entry's `onClick` reorders at once (no tick): the elements are
  `H:fish, 6291, 6303, 6289, H:containers, 21113, 6355, 21150`; the button reads `Sort: Price`; each priced row's
  `zones.text` is `ns.FormatMoney(ns.Prices.Get(id))`; 21150's row reads `L["No price"]` with a grey
  `zones.textColor` (r = g = b, below 1); a reused row turns white again: `scroll_rows` makes new frames on every
  call, so take 21150's row frame from it and call `tab.list.box.view.initializer(row, element)` on that same frame
  with the element of 6291 (by Name: `zones.text` is `Zones: 1` and `zones.textColor` white, `{ 1, 1, 1 }`);
  then `ns.db.prices[6289] = { price = 1000, quantity = 20, lots = 10, time = 1 }`, `ns.Fire("PRICES_CHANGED")` and a
  `tick` give the fish `6289, 6291, 6303`; then `ns.db.settings.auctionPrices = false`,
  `ns.Fire("SETTINGS_CHANGED", "auctionPrices")` (as the settings page does) and a `tick` give `6291, 6303, 6289`
  again (FR-009).
- [X] T010 [US1] In `OneKeyFishing/UI/CatalogTab.lua` (draft): `OpenSortMenu(owner)` through `ns.OpenRadioMenu` over
  `ns.Catalog.SORTS` with `ns.Catalog.SortText`, the current order marked, a choice calling `ns.Catalog.SetSort`;
  `page.sortButton` (min width 150) created in the list view; its text set in `Refresh`; `RightColumn(element)`
  (research R7): by price `ns.FormatMoney(price)` when the price is above 0, else `L["No price"]`; `InitItemRow`
  sets the right text and its color on every draw (grey `0.5, 0.5, 0.5` for "No price", white otherwise; header rows
  keep their empty text); the `SETTINGS_CHANGED` handler calls `CatalogTab.Refresh()` for `"catalogSort"`. Update the
  file's header comment. T009 passes.

**Checkpoint**: the gold question is answered: Sort: Price works with the statistics' prices.

---

## Phase 4: User Story 2 - Sort the catalog by chance (Priority: P2)

**Goal**: Sort: Chance orders each kind group by the best zone's chance, little-data items last (FR-005, FR-008).

**Independent Test**: choose Chance: inside each kind the items run from the highest best-zone chance down; an item
seen only in zones with little data is last with "Little data".

- [X] T011 [P] [US2] Extend `tests/catalog/sort_test.lua`, the chance part. Use the local helper of
  `tests/catalog/index_test.lua` (`cell(c, items, k)`: `catch_cell(c, 0, items)` with `out.k = k or 1`; `k` is the
  seed cell's weight, not its skill range: leave it out here, so every cell weighs 1). A place's skill range is the
  middle part of its key, `<mapID>:<range>:<cell>` (`docs/architecture/catch-db.md`). Five items 90201 to 90205
  named "Amber", "Birch", "Cedar", "Dune", "Elm" (A to E). The seed cells, exactly:
  - `["1415:3:47"] = cell(100, { [A] = { 60, 60 }, [B] = { 30, 30 }, [C] = { 10, 10 } })`: range 3, enough data;
  - `["1416:3:11"] = cell(10, { [D] = { 10, 10 } })`: range 3, little data, D only;
  - `["1417:3:11"] = cell(10, { [E] = { 5, 5 }, [B] = { 5, 5 } })`: range 3, little data, E and B;
  - `["1418:2:11"] = cell(80, { [C] = { 80, 80 } })`: range 2, enough data.
  Every list below is read through `settle` of T003 with its own filter (the `range = 3` filter builds a new index,
  empty until its steps ran). Expectations with `SetSort("chance")`:
  - `Catalog.Items(ALL)` gives C, A, B, D, E: C's best place is map 1418 (1.0), then A 0.6, B 0.3 (its best place is
    1415, not the little-data 1417); D (1.0) and E (0.5) only in little-data maps, after the others;
  - B's row has `littleData == false` and chance 0.3; D's row has `littleData == true`; every row's `chance` and
    `littleData` equal those of `Catalog.Places(itemID, ALL)[1]`;
  - with the filter `{ range = 3, source = "all", water = "all" }` (map 1418 left out): A, B, C, then D, E (C now
    0.1 from map 1415);
  - every adjacent pair keeps the rule (little data last, chance not increasing, ties by name; SC-002).
- [X] T012 [US2] In `OneKeyFishing/Catalog/Catalog.lua` (draft): `SortedItems` adds `chance = places[1].chance,
  littleData = places[1].littleData` to each row (research R4; update its comment); `SortRows` for `"chance"`: rows
  whose `littleData` is false first, then `chance` descending, then the name order. T011 passes.
- [X] T013 [P] [US2] Extend `tests/ui/catalog_sort_test.lua`, the chance part, on the data of T009: the Chance
  entry gives `H:fish, 6303, 6291, 6289, H:containers, 21150, 21113, 6355` (6303 by its map 1416, 50 of 60; 6289 last:
  little data only; 21113 before 6355: equal chance, by name); each row's `zones.text` is
  `ns.Catalog.ChanceText(chance, littleData)` of its best place (6289 reads `L["Little data"]`), and equals the chance
  text of the first zone row on that item's page (click the row, read the first zone row's `chance.text`, go Back);
  with Sort: Price chosen, the page of 6303 lists its zones 1416 then 1415 (by chance, as with Sort: Name: the order
  applies to the item list only, spec edge case).
- [X] T014 [US2] In `OneKeyFishing/UI/CatalogTab.lua` (draft): `RightColumn` by chance returns
  `ns.Catalog.ChanceText(element.chance, element.littleData)`. T013 passes.

**Checkpoint**: both new orders work.

---

## Phase 5: User Story 3 - Back to the order by name, and the choice remembered (Priority: P2)

**Goal**: Name is the default and today's list; the choice survives a reload; a new order shows the list from its top
(FR-001, FR-002, FR-010).

**Independent Test**: choose Price, load again with the same saved table: still by price; choose Name: alphabetical
with "Zones: N".

- [X] T015 [P] [US3] Write two test files first, each one load (model them on
  `tests/ui/catalog_kinds_saved_test.lua`; a file cannot load the addon twice):
  Both use the data of T009 (the three seed cells, the six items, the same `item_prices`, no `ns.db.prices`):
  - `tests/ui/catalog_sort_saved_test.lua`: `OneKeyFishingDB = { settings = { catalogSort = "price" } }` before
    `load_addon`; the first draw of the catalog gives `H:fish, 6291, 6303, 6289, H:containers, 21113, 6355, 21150`,
    the priced rows show `ns.FormatMoney(ns.Prices.Get(id))`, 21150 reads `L["No price"]`, and the button reads
    `Sort: Price`;
  - `tests/ui/catalog_sort_saved_unknown_test.lua`: `OneKeyFishingDB = { settings = { catalogSort = "later" } }`
    (a later version's value); the first draw gives the name order of T016,
    `H:fish, 6289, 6291, 6303, H:containers, 21113, 21150, 6355`, with `Zones: N` (6303 `Zones: 2`, the others
    `Zones: 1`), the button reads `Sort: Name`, and `ns.db.settings.catalogSort` is still `"later"` (not rewritten
    until the player chooses).
- [X] T016 [P] [US3] Extend `tests/ui/catalog_sort_test.lua`: with the default order (before any choice) the
  elements are exactly `H:fish, 6289, 6291, 6303, H:containers, 21113, 21150, 6355` (SC-005, by name as before: the
  stub's names are "Item <id>" without an `item_names` entry, compared as text, so 21113 and 21150 come before 6355)
  and every item row's `zones.text` is `(L["Zones: %d"]):format(1)`, except 6303's, `(L["Zones: %d"]):format(2)`;
  after any order change the scroll box's last `SetDataProvider` had `retainScroll == nil` (the list from its top,
  FR-002), while a kind toggle still passes `true`.
- [X] T017 [US3] In `OneKeyFishing/UI/CatalogTab.lua` (draft): check that the handler's `"catalogSort"` branch calls
  `CatalogTab.Refresh()` without `retain` and that `RightColumn` by name returns `(L["Zones: %d"]):format(
  element.zones)`. T015 (both files) and T016 pass.

**Checkpoint**: the feature is complete for the player except the final layout.

---

## Phase 6: User Story 4 - The new button layout (Priority: P3)

**Goal**: three rows: search; Skill, Source, Water; Sort, Kinds (FR-011). "What can be caught here" unchanged.

**Independent Test**: the anchors of the catalog's buttons put them in the three rows; the list starts below row 3;
the catch tab's Kinds button keeps its anchor.

- [X] T018 [P] [US4] Extend `tests/ui/catalog_sort_test.lua`, the layout part, with `anchor(frame, point)` of T002:
  `anchor(search, "TOPLEFT")` has y `TOP` (-32); `anchor(skillButton, "TOPLEFT")` y -60; `anchor(sourceButton,
  "LEFT")` names `skillButton` and `"RIGHT"`; `anchor(waterButton, "LEFT")` names `sourceButton` and `"RIGHT"`;
  `anchor(sortButton, "TOPLEFT")` y -86, min width 150; `anchor(kindButton, "LEFT")` names `sortButton` and
  `"RIGHT"`; `anchor(tab.list.box, "TOPLEFT")` y -120 (the box has a `BOTTOMRIGHT` point too).
  Change `tests/ui/catalog_kinds_test.lua`'s test "the Kinds button, at the top right" to expect the Kinds button
  next to the Sort button (min width still 120) and the three filter buttons still 150; add to
  `tests/ui/here_kinds_test.lua` (or check it is already asserted) that the catch tab's Kinds button is anchored as
  before (`TOPRIGHT`).
- [X] T019 [US4] In `OneKeyFishing/UI/CatalogTab.lua`: constants `FILTER_TOP = TOP - 28` (Skill, Source, Water),
  `SORT_TOP = TOP - 54` (Sort, Kinds), `LIST_TOP = TOP - 88`; `waterButton` anchored after `sourceButton` again
  (the draft put it after Sort); `kindButton` anchored `LEFT` to `sortButton`'s `RIGHT`, 8 apart, instead of
  `TOPRIGHT`; comments say why (row 2 has room for three buttons in every language, research R6). T018 passes.

**Checkpoint**: the layout matches the agreement; ready for the game.

---

## Phase 7: Polish and cross-cutting

- [X] T020 [P] Documentation, in English (no Cyrillic):
  - `docs/architecture/catalog.md`: a section "List order (spec 017)" (the four functions, `settings.catalogSort`,
    `Items` sorted by `SortRows`, prices read per call and why, the two row fields; the catalog's setting messages
    are now `hiddenKinds` and `catalogSort`); the tests list gets `tests/catalog/sort_test.lua`;
  - `docs/architecture/ui.md`: the catalog tab's three rows, the Sort button and the right column; the new UI tests;
  - `docs/architecture/core.md`: `catalogSort` in the `settings` row (only through `Catalog.SetSort`, written by
    Catalog/Catalog.lua);
  - `CLAUDE.md`: the cross-module rule "The order of the catalog's list by `Catalog.SetSort`, never by a write of
    `settings.catalogSort` (it fires `SETTINGS_CHANGED`)"; the catalog paragraph names its two setting messages;
    keep it consistent with `.specify/memory/constitution.md`.
- [X] T021 [P] `docs/checklists/catalog-sort.md` following `docs/checklists/README.md` "How a checklist is built",
  with the steps of quickstart.md "In game" (English and French for the layout), and its row in the table of
  `docs/checklists/README.md` (needs: one character, the bundled data, an auction scan). The checklist is the only
  check that no button covers another (FR-011, SC-006: the tests see the anchors, not the drawn widths); it also
  covers the Sort button used while the catalog is still counting (right after login, before the index is ready:
  the order applies once the list shows; spec edge case).
- [X] T022 `CHANGELOG.md` under `## [Unreleased]` / `### Added` (the file starts at `## [1.3.0]` since the release:
  create `## [Unreleased]` above it if it is still missing): "**Sort** in the catch catalog: by name, by price
  (dearest first, the price in each row; "No price" for items without one) or by chance (the best zone's chance);
  the choice is kept between sessions. The catalog's buttons are now in three rows." `OneKeyFishing/README.md`, the
  "Catch catalog" section: a **Sort** bullet after **Filters** (the three orders, the right column, the price is the
  statistics' value, kept between sessions) and the Kinds button's new place; keep the author's uncommitted edit of
  the "Statistics" section as it is.
- [X] T023 Run `npm run check` and `npm test`; compare with T001 (the new tests added, nothing else changed, no new
  `VERIFY` marker); set the spec's status to "Implemented" and hand the checklist to the author. The version stays
  1.3.0 here: the bump to 1.3.1 (`package.json`, the TOC, the changelog heading) is a release step of
  `docs/publishing.md`, done when the author releases.

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (Phase 1)**: none.
- **Foundational (Phase 2)**: after T002 (the stubs are not needed by T003, but keep the order simple). Blocks every
  story.
- **US1 (Phase 3)**: after Phase 2. The MVP.
- **US2 (Phase 4)**: after Phase 2; touches the same files as US1 (`Catalog.lua`, `CatalogTab.lua`, the two sort
  tests), so it runs after US1 in practice.
- **US3 (Phase 5)**: after US1 (it checks the order change of T010).
- **US4 (Phase 6)**: after T002 and T010 (the Sort button exists).
- **Polish (Phase 7)**: after the stories it documents; T023 last.

### Within each story

- The test task first, seen failing; then the code task; the story's checkpoint before the next story.

### Parallel opportunities

- T003 and T006 (different files) in Phase 2; T004 with them.
- In each story, the `tests/catalog/` task and the `tests/ui/` task ([P]) can be written together.
- T020 and T021 in Phase 7.

## Parallel Example: User Story 1

```text
Together: T007 (tests/catalog/sort_test.lua, price part) and T009 (tests/ui/catalog_sort_test.lua, price part)
Then:     T008 (Catalog.lua), then T010 (CatalogTab.lua)
```

## Implementation Strategy

### MVP first (User Story 1)

1. Phase 1 and Phase 2.
2. Phase 3 (US1): the order by price with the price in each row.
3. Stop and validate: `npm test`; the author can already try Sort: Price in game.

### Incremental delivery

1. US1 (price), then US2 (chance), then US3 (default and memory checked), then US4 (the agreed layout).
2. Polish: documents, checklist, changelog and manual in the same change as the code (definition of done).
3. Hand the checklist to the author; commit only when the author asks.
