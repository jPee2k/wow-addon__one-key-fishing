---

description: "Task list for spec 019, Auctionator prices"
---

# Tasks: Auctionator Prices

**Input**: Design documents from `specs/019-auctionator-prices/`

**Prerequisites**:
- [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md)
- [contracts/module-api.md](contracts/module-api.md), [quickstart.md](quickstart.md), [verification.md](verification.md)

**Tests**: required (constitution Principle V). Each test is written first and seen failing before its code.

**Organization**: grouped by the user stories of spec.md (US1 to US5). Work on `019-auctionator-prices`; commit only
when the author asks.

**Rules for every task** (CLAUDE.md):
- `npm run check` and `npm test` pass after it; a test written before its code is the only allowed red.
- Addon Lua: ASCII outside `Locales/`, 120-character lines, Lua 5.1/5.3 neutral (no `//`, no `math.type`).
- No Cyrillic in Markdown. Files with LF line endings.
- A new visible text: a literal English key in `Locales/enUS.lua` and its translation in each of the nine other locale
  files (`deDE`, `esES`, `esMX`, `frFR`, `ukUA`, `koKR`, `ptBR`, `zhTW`, `zhCN`) in the same task, with the words the
  file already uses for "auction", "catch" and "vendor price"; "Auctionator" stays as it is (a product name); color
  codes outside the strings; no `L[...]` lookup while the files load.
- Only Auctionator's public `Auctionator.API.v1` is called, always as `pcall(fn, "OneKeyFishing", ...)` with a number
  for the item; no other field of `Auctionator` is read beyond the presence checks of R2; none of its code is copied
  (its licence is "All Rights Reserved").
- `Catch/Prices.lua` and `Catch/Auction.lua` are layer 1: no `ns.CatchDB`, `ns.Catalog`, `ns.Share`, no frame; the UI
  reads `ns.Prices.UsesAuctionator()` and follows `PRICES_CHANGED` / `SETTINGS_CHANGED`.
- In the addon's code `settings.auctionPrices` and `settings.auctionatorPrices` are written only by
  `Prices.SetAuctionPrices` and `Prices.SetAuctionator`. The four present tests that set `auctionPrices` directly
  (`tests/catalog/sort_test.lua`, `tests/catch/auction_list_test.lua`, `tests/ui/catalog_sort_test.lua`,
  `tests/ui/here_page_test.lua`) stay as they are; new tests use the setters.
- The one assumption carries exactly `-- VERIFY(V59): <what>` above the code that rests on it (`Prices.AddTooltipLine`
  leaving out its line for an Auctionator price). A further assumption only the game can confirm: stop and ask the
  author.
- The stub of Auctionator lives in the test files that use it: a global `Auctionator = { API = { v1 = { ... } } }`
  set before `load_addon()` (the addon registers its notice at `PLAYER_LOGIN`, which `load_addon` fires);
  `tests/wow.lua` stays "no Auctionator".

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: the user story of spec.md (US1 to US5)

---

## Phase 1: Setup (baseline)

**Purpose**: the baseline; no addon behaviour.

- [X] T001 Run `npm run check` and `npm test` from the repository root on `019-auctionator-prices`; note the test count
  and that no `VERIFY` marker is open (018 closed V54 to V58), for the hand-over.
- [X] T002 [P] `OneKeyFishing/OneKeyFishing.toc`: add `## OptionalDeps: Auctionator` after the `## Category-*` lines
  (no new file in the TOC). `.luacheckrc`: add `Auctionator` to `read_globals` (a table with fields; the addon only
  reads it). `npm run check` passes.

---

## Phase 2: Foundational (the setting, the source)

**Purpose**: the saved key, the setters and the source every story reads. Blocks every story.

- [X] T003 Test first, `tests/core/migrations_test.lua` (extended): a fresh `OneKeyFishingDB` gets
  `settings.auctionatorPrices == true`; a saved `false` stays `false`; `settings.auctionPrices` keeps its saved value;
  `DB_SCHEMA` unchanged.
- [X] T004 `OneKeyFishing/Core/Core.lua`: default `auctionatorPrices = true` right after `auctionPrices = true`, with
  the comment "take auction prices from Auctionator when it is installed (Catch/Prices.lua); written only by
  Prices.SetAuctionator". T003 passes.
- [X] T005 Test first, `tests/catch/prices_auctionator_test.lua` (new; the file calls `load_addon()` with no stub
  and sets its stubs afterwards, since the presence is checked at runtime), part "source": the login without
  Auctionator registers nothing and raises no error; with no `Auctionator` global,
  `Prices.HasAuctionator()` false, `GetSource()` `"own"`; with a stub that has both `GetAuctionPriceByItemID` and
  `RegisterForDBUpdate`, true and `"auctionator"`; a stub without `RegisterForDBUpdate` (and one without the price
  function, and `Auctionator = { API = {} }`): false and `"own"`; the harness's default too (an undefined global is a
  permissive stub that can be indexed and called, not nil): false and `"own"`, so the check must rest on
  `type(...) == "function"`; `Prices.SetAuctionPrices(false)`: `"off"` and
  `SETTINGS_CHANGED("auctionPrices")` fired once (a second call with the same value fires nothing);
  `Prices.SetAuctionator(false)`: `"own"`, `UsesAuctionator()` false, `SETTINGS_CHANGED("auctionatorPrices")` once.
- [X] T006 `OneKeyFishing/Catch/Prices.lua`: `CALLER = "OneKeyFishing"`; a local `API()` returning
  `Auctionator.API.v1` when `type(Auctionator) == "table"`, `type(Auctionator.API) == "table"` and
  `type(Auctionator.API.v1) == "table"`, else nil (read at each call, never at load);
  `Prices.HasAuctionator()` (both functions are `"function"` and the session's `failure` is nil);
  `Prices.UsesAuctionator()` (`ns.db.settings.auctionPrices`, `ns.db.settings.auctionatorPrices`,
  `HasAuctionator()`); `Prices.GetSource()` (`"off"`, `"auctionator"`, `"own"`, data-model.md "Price source");
  `Prices.SetAuctionPrices(on)` / `Prices.SetAuctionator(on)`: write `on == true` and fire `SETTINGS_CHANGED` with the
  key only when the value changed. Update the file's header comment (two sources; the rule unchanged). T005 passes.

**Checkpoint**: the source can be read and switched; nothing uses it yet.

---

## Phase 3: User Story 1 - Catch values from Auctionator's prices (Priority: P1) MVP

**Goal**: the values use Auctionator's price when it has one, the own stored price (with "few lots") when not, the
vendor price as the floor; they update after Auctionator's scan without a reload; the addon's tooltip line shows only
its own (fallback) price (FR-014).

**Independent test**: the stubbed price shows in `Stats.GetValue`, in `Prices.FormatValue` and in the catalog's
price column; a burst of notices redraws once; a row tooltip has no own line for an item Auctionator prices.

- [X] T007 [US1] Test first, `tests/catch/prices_auctionator_test.lua`, part "prices" (`item_prices` for the vendor
  price, `ns.db.prices` for the own one, the stub's price table): Auctionator 500 / vendor 100 -> `Get` 500,
  `GetAuction` `500, false, "auctionator"`; Auctionator 50 / vendor 100 -> 100 (FR-002, SC-004); Auctionator none /
  own `{ price = 300, quantity = 20, lots = 5 }` -> 300 with source `"own"`; Auctionator none / own on few lots
  (`quantity = 2`) -> the vendor price and `FormatValue` with the "few lots" mark (FR-004); Auctionator 0 or a
  string -> counts as none; Auctionator's price used whatever its age (the stub's age 400, FR-003); the own price
  never written or removed while Auctionator is in use (FR-005); `SetAuctionator(false)` -> the own price again;
  `SetAuctionPrices(false)` -> the vendor price only. Part "failure": the stub's price function raises an error ->
  that `Get` gives the fallback, `ns.GetErrors()` has one new entry, `HasAuctionator()` false, a second `Get` makes
  no call to the stub and logs nothing more, `Prices.GetAuctionatorFailure()` gives the message; no message is fired
  inside the failing `Get`, and after `advance(0.1)` exactly one `PRICES_CHANGED` and no `SETTINGS_CHANGED`
  (FR-007). The test takes the handed-on error with
  `take_errors()` and finds exactly one (an error left there fails the file).
- [X] T008 [US1] `OneKeyFishing/Catch/Prices.lua`: a local `AuctionatorPrice(itemID)`: nil unless
  `UsesAuctionator()`; `pcall(api.GetAuctionPriceByItemID, CALLER, itemID)`; on failure, the first one only: keep
  `failure = tostring(err)`, record it with `ns.Safe("Auctionator", error, "Auctionator: " .. failure, 0)` (one
  entry in the error log, R5), fire `PRICES_CHANGED` only (no setting changed) through `C_Timer.After(0, ...)`, not
  inside the read (a value is often read in the middle of a redraw), answer nil; a
  result that is not a number above 0 is nil. `Prices.GetAuctionatorFailure()` returns `failure`. `Prices.GetAuction(itemID)` returns `price, fewLots, source` per the
  table of data-model.md "Auction price of an item" (the own price only while `settings.auctionPrices` is on, as
  today). `Prices.Get` and `FormatValue` keep their code (they read the first two values). T007 passes.
- [X] T009 [US1] Test first, `tests/catch/prices_update_test.lua` (new): with the stub, `load_addon()` registers
  exactly one callback (the stub counts calls of `RegisterForDBUpdate` and keeps the function); calling it five
  times within 0.1 s, then `advance(0.6)` -> exactly one `PRICES_CHANGED` (FR-006); after `SetAuctionator(false)` a
  call -> none; one `PRICES_CHANGED` about 1 s after the login when Auctionator is in use (R4). (The login without
  Auctionator is T005's: a test file has one login.)
- [X] T010 [US1] `OneKeyFishing/Catch/Prices.lua`: at `PLAYER_LOGIN` (`ns.RegisterEvent`), when `HasAuctionator()`
  and not yet `registered`: `pcall(api.RegisterForDBUpdate, CALLER, OnNotice)` (a failure goes the way of T008);
  `OnNotice` returns unless `UsesAuctionator()`, else starts `C_Timer.After(0.5, ...)` when no timer is `pending`,
  which clears `pending` and fires `PRICES_CHANGED`; after the registration, `C_Timer.After(1, ...)` fires one
  `PRICES_CHANGED` when `UsesAuctionator()`. T009 passes.
- [X] T011 [P] [US1] `tests/ui/stats_window_test.lua` (extended): with the stub (a price for one caught item), the
  statistics window's item row shows the Auctionator-based value; after the stub's price changes and its callback
  plus `advance(0.6)`, the row shows the new value without a reload (acceptance 1.5). Passes with T008 and T010 (no
  UI change needed: the window redraws on `PRICES_CHANGED`).
- [X] T012 [US1] Test first, `tests/ui/tooltips_test.lua` (extended): with the stub, `ns.ShowItemTooltip(owner, id,
  true)` for an item Auctionator prices adds no line starting with `Auction price (OneKeyFishing)`; for an item it
  does not price and the addon has an own price, the present line (grey with the few-lots text when on few lots);
  without the stub, unchanged.
- [X] T013 [US1] `OneKeyFishing/Catch/Prices.lua`: in `Prices.AddTooltipLine`, return without a line when the third
  value of `GetAuction` is `"auctionator"`, with `-- VERIFY(V59): Auctionator's own line shows on the addon's row
  tooltips (GameTooltip:SetItemByID, its Source/Tooltips/Hooks.lua); if not, add the line with "(Auctionator)"`
  above that return; the comment of the function says the line is the own (or fallback) price. T012 passes.

**Checkpoint**: US1 complete; the values follow Auctionator.

---

## Phase 4: User Story 2 - No second scan button (Priority: P1)

**Goal**: while Auctionator is in use, no scan entry of the addon and no auction request; the command answers with
one line.

**Independent test**: `tests/ui/scan_buttons_test.lua` with the stub.

- [X] T014 [US2] Test first, `tests/ui/scan_buttons_test.lua` (extended with a section at its end; the stub is set
  after the file's `load_addon()`, which is enough here: the presence is checked at runtime and this test needs no
  update notice): with Auctionator in use, `fire("AUCTION_HOUSE_SHOW")` -> the addon's button above the auction window is
  hidden; the statistics window's scan button is hidden; the minimap menu has no entry `Scan auction prices` (nor
  `Auction house not answering`); `/okf scan` prints exactly `Prices come from Auctionator.` and
  `auction_requests` stays empty (FR-011, FR-012, SC-002); `Prices.SetAuctionator(false)` -> the button above the
  auction window and the statistics button shown again, the minimap entry back, `/okf scan` starts a scan
  (SC-003, acceptance 2.4: in the game the auction house is closed by then, so the button's return is seen at its
  next opening; the test checks the button's shown state directly).
- [X] T015 [US2] `OneKeyFishing/Catch/Auction.lua`: `Auction.WhyNot()` returns `L["Prices come from Auctionator."]`
  first while `ns.Prices.UsesAuctionator()`, before the closed and stalled reasons (so `CanScan()` is false and
  `Scan()` prints it and sends nothing). New key `Prices come from Auctionator.` in `Locales/enUS.lua` (under
  `-- Auction.lua`) and its nine translations.
- [X] T016 [US2] `OneKeyFishing/UI/AuctionButton.lua`: in `Update`, `button:SetShown(not ns.Prices.UsesAuctionator())`
  before the text; add `ns.On("SETTINGS_CHANGED", Update)` and `ns.On("PRICES_CHANGED", Update)` (the failure of
  T008 turns the source back). `OneKeyFishing/UI/StatsFrame.lua`: in `UpdateScanButton`,
  `frame.scan:SetShown(not ns.Prices.UsesAuctionator())` (the window already redraws on both messages).
  `OneKeyFishing/UI/Minimap.lua`: build the scan entry only when `not ns.Prices.UsesAuctionator()`. Update the header
  comments. T014 passes.
- [X] T017 [P] [US2] `OneKeyFishing/Core/Commands.lua`: the `scan` description becomes "scan auction prices of the
  catch catalog's items (auction house must be open; not while prices come from Auctionator)" (English, not
  localized); `tests/core/english_commands_test.lua` still passes. No command is added for the two switches
  (FR-013: they change only on the settings page); T014's test also checks that `/okf scan` leaves
  `settings.auctionPrices` and `settings.auctionatorPrices` as they were.

**Checkpoint**: US1 and US2 make the MVP: values from Auctionator and no second scan.

---

## Phase 5: User Story 3 - A settings page for auction prices (Priority: P2)

**Goal**: the "Auction prices" page with the moved switch, the nested Auctionator switch, the source and the counts.

**Independent test**: `tests/ui/auction_page_test.lua` with and without the stub.

- [X] T018 [US3] Test first, `tests/catch/prices_counts_test.lua` (new): `charDB.stats.total.items` with six items:
  one priced by the stub, one with an own price only, one with a vendor price only (`item_prices`), one with none, one
  bound (`item_bind[id] = 1`, priced by the stub), one quest item (`item_bind[id] = 4`) -> `Prices.CountSources()`
  is `{ auctionator = 1, own = 1, vendor = 1, none = 1 }` and the sum is 4 (FR-019, SC-005); an item with
  `item_info_missing` counts as sellable; with Auctionator off the `auctionator` count is 0 and that item moves to
  `vendor` or `none`; `Prices.CanAuction` false for bind types 1 and 4, true for 0, 2, 3 and for a missing item.
- [X] T019 [US3] `OneKeyFishing/Catch/Prices.lua`: `Prices.CanAuction(itemID)` (the body and the `VERIFY`-free
  comment of `Auction.lua`'s local `Unsellable`, inverted: false for a loaded item of bind type 1 or 4) and
  `Prices.CountSources()` over `ns.Stats.GetTotal().items` per data-model.md "Price counts" (`vendor` = no auction
  price and a vendor price above 0). `OneKeyFishing/Catch/Auction.lua`: remove `Unsellable`, call
  `not ns.Prices.CanAuction(itemID)`; `tests/catch/auction_list_test.lua` is not edited and keeps passing (the same rule).
  T018 passes.
- [X] T020 [US3] Test first, `tests/ui/auction_page_test.lua` (new): `settings_pages["Auction prices"]` exists (the
  test reads the translated title through `ns.L`); shown with the stub: two checkboxes checked, the second enabled,
  the status line `Prices come from Auctionator.`, the counts line with the four numbers of `CountSources`;
  clicking the first checkbox off -> `settings.auctionPrices == false` (through `Prices.SetAuctionPrices`), the
  second checkbox disabled, the status `Auction prices are off: catch values use vendor prices.`; without the stub:
  the second checkbox disabled, the note `Auctionator is not installed.` shown, the status names the own scan with
  the date of `Prices.GetLastScanTime()` or "no scan yet"; with the stub after a failing price call (the error
  taken with `take_errors()`): the second checkbox disabled and the note `Auctionator failed this session: the
  addon's own scan is in use.` instead of the not-installed one (FR-016); the main page has no checkbox labelled `Use scanned
  auction prices for catch value`; no button on the page (FR-015 to FR-018); the page redraws on `PRICES_CHANGED`
  while shown.
- [X] T021 [US3] `OneKeyFishing/UI/Settings.lua`: remove the `auctionPrices` entry from the main page's toggle list;
  a new `CreateAuctionPage()` before "Registration": the title `L["Auction prices"]`, a checkbox through
  `CreateCheckbox` (not `CreateSettingCheckbox`) bound to `settings.auctionPrices` / `ns.Prices.SetAuctionPrices`
  with the present label, a second one indented by 24 px bound to `settings.auctionatorPrices` /
  `ns.Prices.SetAuctionator` with `L["Take prices from Auctionator"]`, enabled only while `auctionPrices` is on and
  `ns.Prices.HasAuctionator()`; a grey note shown while it is not: `L["Auctionator failed this session: the addon's
  own scan is in use."]` when `ns.Prices.GetAuctionatorFailure()`, else `L["Auctionator is not installed."]`; the status
  line (`Prices come from Auctionator.` / `Prices come from the addon's own scan (last scan %s).` with
  `date("%Y-%m-%d %H:%M", time)` / `Prices come from the addon's own scan (no scan yet).` / `Auction prices are off:
  catch values use vendor prices.`) and the counts line `Your catches: %d priced by Auctionator, %d by the addon's
  scan, %d at vendor price, %d without a price.`; a `Sync` run on `OnShow`, `SETTINGS_CHANGED` and
  `PRICES_CHANGED` (only while shown). Register it in `PLAYER_LOGIN` after "Sound effects" with
  `Settings.RegisterCanvasLayoutSubcategory(mainCategory, auctionPage, L["Auction prices"])`, created hidden like the
  others. The eight new keys (`Auction prices`, `Take prices from Auctionator`, `Auctionator is not installed.`,
  `Auctionator failed this session: the addon's own scan is in use.`, the
  three own-scan / off status texts, the counts text) in `Locales/enUS.lua` under the settings texts, with their
  nine translations. T020 passes; `tests/ui/windows_test.lua` and the other settings tests keep passing.

**Checkpoint**: US3 complete.

---

## Phase 6: User Story 4 - Knowing which prices are missing (Priority: P2)

**Goal**: the statistics line names Auctionator as the source and the number of own catches without its price.

**Independent test**: `tests/ui/stats_window_test.lua`.

- [X] T022 [US4] Test first, `tests/ui/stats_window_test.lua` (extended): with the stub pricing every own sellable
  catch, the values line reads `Values: higher of vendor and Auctionator price` with no count; with two of them
  unpriced, it adds `2 of your catches have no Auctionator price: run its scan.` (formatted through `ns.L`); nothing
  printed to chat (FR-020, FR-021); without the stub, the present two lines unchanged.
- [X] T023 [US4] `OneKeyFishing/UI/StatsFrame.lua`: in the refresh, when `ns.Prices.UsesAuctionator()`, the line is
  `L["Values: higher of vendor and Auctionator price"]` and, when `own + vendor + none` of
  `ns.Prices.CountSources()` is above 0, a space and `L["%d of your catches have no Auctionator price: run its scan."]`;
  else the present code. Two new keys with nine translations. T022 passes.

**Checkpoint**: US4 complete.

---

## Phase 7: User Story 5 - A debug report that explains the values (Priority: P3)

**Goal**: the "Auction prices" section of `/okf debug`.

**Independent test**: `tests/core/report_sections_test.lua`.

- [X] T024 [US5] Test first, `tests/core/report_sections_test.lua` (extended): the report has a section "Auction
  prices" right before "Auction scan"; with the stub (ages 3 and 12 for two priced catches): lines naming the source
  `auctionator`, `auctionPrices on`, `auctionatorPrices on`, `GetAuctionPriceByItemID present`,
  `RegisterForDBUpdate present`, the four counts, `oldest Auctionator price: 12 days`; with every age nil: `oldest
  Auctionator price: unknown`; with a stub missing `RegisterForDBUpdate`: `RegisterForDBUpdate missing` and source
  `own scan`; after a failing call (its handed-on error taken with `take_errors()`): a line `failed: <message>`
  (FR-022).
- [X] T025 [US5] `OneKeyFishing/Catch/Prices.lua`: `Prices.Describe()` returning those English lines (the ages through
  `pcall(api.GetAuctionAgeByItemID, CALLER, itemID)` over the own sellable catches with an Auctionator price; a
  failing age call counts as nil and is not logged). `OneKeyFishing/Core/Debug.lua`: `Section(lines, "Auction
  prices", ...)` from `ns.Prices.Describe()` before the "Auction scan" section. T024 passes.

**Checkpoint**: every story complete.

---

## Phase 8: Polish and cross-cutting

- [X] T026 [P] Documentation, in English (no Cyrillic):
  - `docs/architecture/catch-and-stats.md`, "Catch/Prices.lua": the two sources, the functions of the contract, the
    failure rule, the notice and its 0.5 s coalescing, `CanAuction` (moved from Auction), `CountSources`; "Catch/
    Auction.lua": `WhyNot`'s Auctionator reason, the rule now in `Prices`; the tests list;
  - `docs/architecture/ui.md`: the "Auction prices" settings page; the three scan entries hidden while Auctionator is
    in use; the statistics values line; the new UI test;
  - `docs/architecture/core.md`: the saved field `settings.auctionatorPrices` (written only by
    `Prices.SetAuctionator`) and that `auctionPrices` is written only by `Prices.SetAuctionPrices`; the debug
    report's "Auction prices" section;
  - `CLAUDE.md`: the module table's `Catch/Prices.lua` row ("item values, from the own scan or Auctionator"); a
    cross-module rule "The auction price switches by `Prices.SetAuctionPrices` and `Prices.SetAuctionator`, never by
    a write of `settings.auctionPrices` / `settings.auctionatorPrices` (they fire `SETTINGS_CHANGED`); Auctionator only
    through its public `Auctionator.API.v1`, every call in `pcall`"; the `PRICES_CHANGED` line (also after
    Auctionator's update notices); feature 019 in the list of features with a `verification.md`; the documents
    table's `auction-plan.md` row; keep it consistent with `.specify/memory/constitution.md`;
  - `docs/forever-api.md`: nothing new until the checklist confirms V59;
  - `docs/auction-plan.md`: the status line and "Feature 2" point to `specs/019-auctionator-prices` as built; once
    V59 is closed the file moves to `docs/history/` (a later step, after the checklist);
  - `docs/ROADMAP.md`, "Planned": "Auctionator as a price source" leaves.
- [X] T027 [P] `docs/checklists/auctionator-prices.md` following `docs/checklists/README.md` "How a checklist is
  built": header (closes V59; needs Auctionator 347 or later, one character at an auction house, a second character
  with Auctionator disabled for step 5), setup (a TOC change: a game restart, not only `/reload`), the five steps of
  quickstart.md "In game" with blanks for the values, the counts and the debug report's lines, each naming its FR, SC
  or V; no `/run` line that sends an auction request. Its row in the table of `docs/checklists/README.md`.
- [X] T028 `CHANGELOG.md`: `## [Unreleased]` above the newest release with `### Added`: with Auctionator installed,
  catch values use its auction prices (the addon's own scan buttons are hidden; your own stored prices fill in for
  items Auctionator has not seen); a settings page "Auction prices" (the auction price switch moved there from the
  main page; a switch to go back to the addon's own scan; which source is in use and how many of your catches have
  a price). `OneKeyFishing/README.md`, "Auction prices": Auctionator as the source, the order of the prices, the
  vendor floor, the hidden buttons and the `/okf scan` answer, the new settings page and its counts, the
  statistics line's advice; the settings pages list.
- [X] T029 Run `npm run check` and `npm test`; compare with T001 (the new tests added, V59 the only marker); set the
  spec's status to "Implemented (in-game checklist `docs/checklists/auctionator-prices.md` open)"; hand the
  checklist to the author. The version stays 1.3.2 here: the bump to 1.4.0 is a release step of
  `docs/publishing.md`, and `npm run build` refuses while V59 is open (the author closes it or releases with
  `--force`).

---

## Dependencies & Execution Order

- Phase 1 -> Phase 2 -> the stories. T002 is independent of T001.
- US1 (T007 to T013) needs Phase 2. US2 (T014 to T017) needs Phase 2 and reads `UsesAuctionator` only, so it can run
  beside US1; its entries follow the failure path of T008 through `PRICES_CHANGED`.
- US3 (T018 to T021) needs Phase 2; T019 changes `Catch/Auction.lua` like T015: do them one after the other.
- US4 (T022, T023) needs `CountSources` (T019). US5 (T024, T025) needs `CountSources` and the failure rule (T008).
- The tooltip part of US1 (T012, T013) needs `GetAuction`'s third value (T008).
- Phase 8 after every story; T026 and T027 in parallel; T028, T029 last.

Files touched by several tasks (no [P] between them): `Catch/Prices.lua` (T006, T008, T010, T013, T019, T025),
`Catch/Auction.lua` (T015, T019), `UI/StatsFrame.lua` (T016, T023), the locale files (T015, T021, T023),
`tests/catch/prices_auctionator_test.lua` (T005, T007), `tests/ui/stats_window_test.lua` (T011, T022).

## Parallel Example: after Phase 2

```
US1: T007 -> T008 -> T009 -> T010 -> T011 -> T012 -> T013
US2: T014 -> T015 -> T016, with T017 [P] at any time
```

The two chains touch different files except `Catch/Prices.lua` (US1) and `Catch/Auction.lua` (US2); they do not meet.

## Implementation Strategy

1. **MVP**: Phases 1 and 2, then US1 and US2 (values from Auctionator, no second scan). It can be tried in game as it
   is: the switch has its default (on), the old main-page checkbox still turns auction prices off.
2. **Then**: US3 (the page and the counts), US4 (the statistics line), US5 (the debug section).
3. **Last**: the documents, the checklist, the changelog and the manual, the final check.

Eleven new visible texts in all (T015: 1, T021: 8, T023: 2), each with nine translations.

## Notes

- `Catch/Prices.lua` grows by about 150 lines; it stays one file (no `.private` split needed).
- No new message, command, file in the TOC or `DB_SCHEMA` bump.
- Commit only when the author asks (`019-auctionator-prices` branch).
