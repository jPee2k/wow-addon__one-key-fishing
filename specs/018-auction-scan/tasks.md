---

description: "Task list for spec 018, auction scan"
---

# Tasks: Auction Scan

**Input**: Design documents from `specs/018-auction-scan/`

**Prerequisites**:
- [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md)
- [contracts/module-api.md](contracts/module-api.md), [quickstart.md](quickstart.md), [verification.md](verification.md)

**Tests**: required (constitution Principle V). Each test is written first and seen failing before its code.

**Organization**: grouped by the user stories of spec.md (US1 to US5). Work on `018-auction-scan`; commit only when
the author asks.

**Rules for every task** (CLAUDE.md):
- `npm run check` and `npm test` pass after it; a test written before its code is the only allowed red.
- Addon Lua: ASCII outside `Locales/`, 120-character lines, Lua 5.1/5.3 neutral (a whole number is checked with
  `math.floor(n) == n`; no `//`, no `math.type`).
- No Cyrillic in Markdown. Write files with LF line endings (`.gitattributes` `eol=lf`).
- A new visible text: a literal English key in `Locales/enUS.lua` and its translation in each of the nine other
  locale files (`deDE`, `esES`, `esMX`, `frFR`, `ukUA`, `koKR`, `ptBR`, `zhTW`, `zhCN`) in the same task, with the
  words the file already uses for "auction house" and "log out"; color codes outside the strings; no `L[...]` lookup
  while the files load.
- `Catch/Auction.lua` is layer 1: it names no `ns.CatchDB`, `ns.Catalog`, `ns.Share` and no frame.
- The scan never calls `C_AuctionHouse.SearchForItemKeys`, `SendBrowseQuery` or `ReplicateItems`, and no event
  starts a scan.
- The four assumptions carry exactly these markers, each above the code that rests on it: `-- VERIFY(V54): ...`
  (unsellable items), `-- VERIFY(V55): ...` (later pages are never cheaper), `-- VERIFY(V56): ...` (item key info for
  the whole list at once), `-- VERIFY(V57): ...` (a request every 0.6 s). A further assumption only the game can
  confirm: stop and ask the author.
- No auction `/run` line is given to the author outside `docs/checklists/auction-scan.md`; every one sends at most
  one request and names only items from catches.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: the user story of spec.md (US1 to US5)

---

## Phase 1: Setup (baseline, the stand-in auction house)

**Purpose**: the baseline and the test stubs; no addon behaviour.

- [X] T001 Run `npm run check` and `npm test` from the repository root on `018-auction-scan`; note the test count and
  the open `VERIFY` markers for the hand-over.
- [X] T002 In `tests/wow.lua`, the auction stubs (near `auction_queries`), documented in the file's header list:
  - `auction_ready = true`: `C_AuctionHouse.IsThrottledMessageSystemReady()` returns it.
  - `auction_requests = {}`: `SendSearchQuery(itemKey)` appends `{ kind = "search", itemID = itemKey.itemID,
    at = GetTime(), notReady = not auction_ready }` and `RequestMoreCommoditySearchResults(itemID)` appends the same
    with `kind = "more"`; both then set `auction_ready = false` and keep filling the present lists
    (`auction_queries`, `commodity_more_requests`). They fire no event.
  - `auction_key_info = nil`: `C_AuctionHouse.GetItemKeyInfo(itemKey)` returns `{ itemID = id, itemName = "Item
    <id>", quality = 1, isCommodity = true, iconFileID = 134400 }` for every item while it is nil; when it is a table,
    it returns that base merged with `auction_key_info[id]`, or nil for a missing ID, appending the ID to
    `auction_key_requests = {}`.
  - `item_quality[itemID] = n`, `item_bind[itemID] = n`, `item_info_missing[itemID] = true` (all empty by default):
    `C_Item.GetItemInfo` returns nothing for a missing item, otherwise fourteen values: the present eleven with
    `item_quality[itemID] or 1` as the third, then `0, 0` (class IDs) and `item_bind[itemID] or 0` as the fourteenth.
  - Helpers: `auction_answer(itemID, kind)` answers the newest request (it must be unanswered, else an error): marks
    it `answered`, fires `AUCTION_HOUSE_THROTTLED_MESSAGE_RESPONSE_RECEIVED`, then the result event for
    `itemID or request.itemID` (`kind == "item"`: `ITEM_SEARCH_RESULTS_UPDATED` with `{ itemID = id }`; a `"more"`
    request: `COMMODITY_SEARCH_RESULTS_ADDED`; otherwise `COMMODITY_SEARCH_RESULTS_UPDATED`), then sets
    `auction_ready = true` and fires `AUCTION_HOUSE_THROTTLED_SYSTEM_READY`. `auction_run(limit)` loops at most
    `limit or 500` times: `advance(1)` (the scan's turn and its timers), then `auction_answer()` when the newest
    request is unanswered, otherwise it ends; it returns the number answered. `auction_key_arrives(itemID, info)` sets `auction_key_info[itemID] = info or {}`
    and fires `ITEM_KEY_ITEM_INFO_RECEIVED` with the ID. `auction_searched()` returns the item IDs of the
    `"search"` requests in order.
  - `Frame:SetMotionScriptsWhileDisabled` (a no-op that stores its argument) if the frame stub lacks it.
  Every present test still passes (nothing reads the new stubs yet).

---

## Phase 2: Foundational (saved fields, shared values)

**Purpose**: what every story reads. Blocks US1 to US5.

- [X] T003 [P] Extend `tests/core/migrations_test.lua` first: a new player has `OneKeyFishingDB.priceScans` as an
  empty table and `OneKeyFishingDB.scanGuard` with `version == ""` and an empty `items`; data of an earlier version
  (`prices = { [123] = { price = 5, time = 1 } }`, no new field) keeps `prices[123]` untouched, gets both fields and
  `schema == 1`; a saved `scanGuard = { version = "1.3.2", items = { [6291] = "own" } }` is not overwritten by the
  defaults.
- [X] T004 In `OneKeyFishing/Core/Core.lua` `DB_DEFAULTS`, after `prices`: `priceScans = {}` with the comment
  "itemID -> time() of the last answered auction search, with a price or not on sale (spec 018)", and
  `scanGuard = { version = "", items = {} }` with the comment "items the auction house did not answer for: itemID ->
  "own", "bundled" or "shared"; emptied by another addon version (Auction.lua, spec 018)". `DB_SCHEMA` stays 1, no
  migration entry (research R9).
- [X] T005 [P] In `OneKeyFishing/Catch/Prices.lua`: the two locals become fields, `Prices.FEW_PIECES = 5` and
  `Prices.FEW_LOTS = 3` (the comments kept), and `Prices.GetAuction` reads the fields. No behaviour change:
  `tests/catch/auction_price_test.lua` still passes.

**Checkpoint**: the stubs and the saved fields exist; the scan itself is untouched.

---

## Phase 3: User Story 1 - A fast scan that loses no prices (Priority: P1) MVP (with US3)

**Goal**: the scan searches an item only with its item key info, sends on the game's ready signal within 0.6 s
steps, pages only while the price is open and leaves unsellable items out; the price rule is unchanged.

**Independent Test**: `tests/catch/auction_pace_test.lua` and the adapted `auction_price_test.lua`; in game, the
first scan after a login against a repeated one (quickstart steps 2 and 3).

### Tests for User Story 1 (write first, see them fail)

- [X] T006 [P] [US1] Write `tests/catch/auction_pace_test.lua`. Setup: `load_addon()`, then
  `ns.Auction.SetItemSource(nil)` (own catches only; the function arrives in T008, so the file fails until then),
  items through `ns.db.fishedItems`, `fire("AUCTION_HOUSE_SHOW")`. Cases:
  - item key info (FR-001): with `auction_key_info = { [A] = {} }` and items A, B, a scan asks
    `GetItemKeyInfo` for both at its start (`auction_key_requests` holds B), searches A only; after
    `auction_key_arrives(B)` and A's answer, B is searched; with B never arriving, the scan ends 3 s after A is done
    (`advance(4)`), the finished line counts both items, `ns.db.priceScans[B]` is nil and no request for B exists; while B is missing and the scan sends several
    requests for other items, B stands in `auction_key_requests` exactly once (the info is asked once, at the start,
    and read again only on its event);
  - the turn (FR-002, FR-015): after a send, no further request while `auction_ready` is false, whatever events
    fire (`AUCTION_HOUSE_THROTTLED_MESSAGE_SENT`, `..._QUEUED`); after `auction_answer()` the next request goes
    out only once 0.6 s have passed since the previous one (`advance(0.3)`: none; `advance(0.4)`: one); no entry of
    `auction_requests` has `notReady`; never two unanswered requests; a READY event that never comes does not stop
    the scan when the response event came and the line is ready (set `auction_ready = true`, fire only
    `AUCTION_HOUSE_THROTTLED_MESSAGE_RESPONSE_RECEIVED` and the result event);
  - paging (FR-003): `commodity_full[A] = false` with 3 rows of 10 pieces and `commodity_total[A] = 100` (wanted 20,
    loaded 30): no `"more"` request, the price equals the one of the full list; with loaded pieces below the wanted
    share: a `"more"` request goes out through the turn (not inside the result event, and not before 0.6 s), and
    the price uses both pages; with 2 rows (fewer than `FEW_LOTS`) or 4 pieces (fewer than `FEW_PIECES`) and more to
    come: a `"more"` request; after 5 `"more"` requests the loaded pages decide; the stored price and
    the `fewLots` of `Prices.GetAuction` equal the ones of a scan with every page loaded for each case (`lots` and
    `quantity` count what was loaded, so they may be lower);
  - a result that never comes (research R3): response received (`auction_ready = true`, fire the response event
    only), no result event: after 3 s the scan goes on with the next item, nothing is stored for the first; the
    same when the line is ready again without any response event (`auction_ready = true`, fire only
    `AUCTION_HOUSE_THROTTLED_SYSTEM_READY`): no further request before the 3 s, then the next item, no stall; a
    reading that does not count: right after a send set `auction_ready = true` and fire
    `AUCTION_HOUSE_THROTTLED_MESSAGE_SENT`: the request stays unanswered (`advance(5)`: no skip, no further
    request), and `auction_answer()` then settles it with its price;
  - unsellable (FR-004): `item_quality[G] = 0`, `item_bind[Q] = 4`, `item_bind[P] = 1` are not searched and not
    counted in the start line; `item_info_missing[U] = true` is searched; an item whose key info says
    `quality = 0` is dropped before its send;
  - progress (US1 scenario 5): `AUCTION_STATE` with `GetProgress()` going `scanning 0/2`, `1/2`, then `idle`;
  - no scan by itself (FR-021): `fire("AUCTION_HOUSE_SHOW")` alone leaves `auction_requests` and
    `auction_key_requests` empty.
- [X] T007 [US1] Adapt `tests/catch/auction_price_test.lua` to the request line (the price rule's cases stay, with
  the same numbers): after `load_addon()` call `ns.Auction.SetItemSource(nil)`; the helper `scan(itemID, kind)`
  becomes `fishedItems`, `fire("AUCTION_HOUSE_SHOW")`, `ns.Auction.Scan()`, `advance(1)`,
  `auction_answer(itemID, kind)`; the progress test answers through `auction_answer`; the three paging tests are
  rewritten to the new rule: "more results on their way" asks for the next page only after the answer and
  `advance(1)` and uses both pages; "when more results never come" becomes "after the page limit the loaded pages
  decide"; "each page with its own wait" becomes "later pages arrive as `COMMODITY_SEARCH_RESULTS_ADDED`" (two
  `"more"` requests, each answered, the price from three pages, `lots == 3`). The file fails until T008.

### Implementation for User Story 1

- [X] T008 [US1] Rewrite the request machine of `OneKeyFishing/Catch/Auction.lua` (data-model.md "The scan in
  memory", research R1 and R2); the header comment says what the file does now. Keep `IsOpen`, `GetProgress`,
  `GetCoverage`, `RobustPrice`, `Sorts`, the result parsing and the five chat lines. Remove `QUERY_TIMEOUT`,
  `RETRY_DELAY`, `StartTimeout`, `querySerial` and the retry in `Send`. Add:
  - constants `MIN_INTERVAL = 0.6` (with `-- VERIFY(V57): a request every 0.6 s, the documented 100 a minute, is
    answered like the measured one every 0.7 s`), `INFO_WAIT = 3`, `RESULT_WAIT = 3`;
  - `Auction.SetItemSource(fn)` storing the function (used from T013 on; nil clears it);
  - `BuildList()`: for now the own catches (`ns.db.fishedItems` and `ns.Stats.GetTotal().items`), each a positive
    whole number with `C_Item.GetItemInfoInstant(itemID) ~= nil`, sorted by ID; returns the list;
  - `Auction.Scan()`: the present checks and lines; builds the list, sets `queue`, `total`, `found`, `requests`,
    `startedAt`, calls `C_AuctionHouse.GetItemKeyInfo(C_AuctionHouse.MakeItemKey(itemID))` once for every item
    (`-- VERIFY(V56): the item key info of the whole list is asked at once and arrives without a throttled
    message`) and keeps what it returned in `info[itemID]`, prints the start line with `total`, then `Pump()`. A
    call for a missing key asks the server again, so the scan never repeats it on its own: only
    `ITEM_KEY_ITEM_INFO_RECEIVED(itemID)` for a queued item reads that item once more;
  - `Pump()`: returns unless open and a scan runs and no request is unanswered and
    `C_AuctionHouse.IsThrottledMessageSystemReady()`; when `GetTime() - lastSendAt < MIN_INTERVAL`, one timer for
    the remainder calls `Pump` again (a token so that only the newest timer acts); when `wantsMore`, sends
    `RequestMoreCommoditySearchResults(current)`; otherwise takes the first queued item with `info[itemID]`,
    sets `current` and sends `SendSearchQuery(key, Sorts(), false)`; when the queue holds only
    items without info, one `INFO_WAIT` timer ends the scan without them (they get no scan time and count in
    `noInfo`); when the queue is empty, finishes: the finished line, `PRICES_CHANGED`, `AUCTION_STATE`;
  - every send sets `lastSendAt = GetTime()`, counts `requests` and marks the request unanswered;
  - handlers: `ITEM_KEY_ITEM_INFO_RECEIVED` -> the item's info is read once, then `Pump`; the five throttle
    events (contracts) -> the request is answered on `AUCTION_HOUSE_THROTTLED_MESSAGE_RESPONSE_RECEIVED`, and
    also by a ready reading at `AUCTION_HOUSE_THROTTLED_SYSTEM_READY` or `..._MESSAGE_DROPPED` while it is still
    unanswered (the line took it back without a response: an answer without a result), then `Pump`; a reading at
    `..._MESSAGE_SENT`, `..._MESSAGE_QUEUED` or right after the scan's own send never counts as an answer (the game
    may not have switched the line yet), and those two events do not run `Pump`; a result event for `current` also marks it answered; an answered `current`
    without a result for `RESULT_WAIT` is skipped (nothing stored) and `Pump` runs, so no path leaves the scan
    waiting on a ready line;
  - `Settle` stores the price as today (`{ price, quantity, lots, time }`), counts `found`, clears `current`, fires
    `AUCTION_STATE`, calls `Pump`;
  - `AUCTION_HOUSE_CLOSED` stops the scan as today (the stopped line, `PRICES_CHANGED`) and invalidates the timers.
  The "does not answer" stop comes in T019: until then an unanswered request leaves the scan waiting.
- [X] T009 [US1] In `OneKeyFishing/Catch/Auction.lua`, the paging rule (research R4): a local
  `PriceDecided(listings, listed)` true when the loaded pieces are at least `math.max(1, math.ceil(listed *
  CHEAPEST_SHARE))` and at least `ns.Prices.FEW_PIECES`, and `#listings >= ns.Prices.FEW_LOTS`
  (`-- VERIFY(V55): with the price sort a later page holds no cheaper row than the loaded ones`). In the commodity
  handler: `Settle` when `HasFullCommoditySearchResults`, or `moreRequests >= MAX_MORE_REQUESTS`, or `PriceDecided`;
  otherwise keep the loaded rows, set `wantsMore` and let `Pump` ask for the page at its turn. Item searches keep
  using their first page.
- [X] T010 [US1] In `OneKeyFishing/Catch/Auction.lua`, the unsellable filter (research R5): a local
  `Unsellable(itemID)` true when `C_Item.GetItemInfo(itemID)` returns a quality of 0 or a bind type (the fourteenth
  value) of 1 or 4, false when it returns nothing (`-- VERIFY(V54): poor quality and bound items cannot be listed at
  auction`); `BuildList` leaves such items out and counts them for the debug report; `Pump` drops a queued item
  whose key info has `quality == 0` before its send (counted the same way, not in `noInfo`).

**Checkpoint**: T006 and T007 pass; `npm test` green. A healthy scan is fast and exact; the stop on an unanswered
request is User Story 3, built next.

---

## Phase 4: User Story 2 - Auction prices in the whole catalog (Priority: P1)

**Goal**: the scan's list is the own catches, then the bundled database's items, then the items of other players'
records; every place that shows a value uses the found price.

**Independent Test**: `tests/catchdb/scan_items_test.lua` and the group cases of `tests/catch/auction_list_test.lua`;
in game, the catalog by price on a character with few catches (quickstart step 4).

### Tests for User Story 2 (write first, see them fail)

- [X] T011 [P] [US2] Write `tests/catchdb/scan_items_test.lua` (setup like `tests/catchdb/items_test.lua`: a small
  `ns.SeedData` set in `load_addon`'s callback, another player's record through a `contribution` helper,
  `SHARED_DATA_CHANGED`): `CatchDB.ScanItems()` returns two sets; the first holds exactly the seed's item IDs; the
  second the items of the other player's record while sharing is on (`ns.Share.SetEnabled(true)`), and is empty with
  sharing off; an own record frozen by a roll (key `<myID>@<epoch>`) does not put its items into the second set; an
  item of both the seed and a record is in both sets (the scan orders them, T014); the call writes nothing to
  `ns.db`.
- [X] T012 [P] [US2] Write `tests/catch/auction_list_test.lua`, the group cases (setup: `load_addon()`,
  `ns.Auction.SetItemSource(function() return bundled, shared end)` with test tables, `fire("AUCTION_HOUSE_SHOW")`,
  the searched order read with `auction_run()` and `auction_searched()`): own items first, then bundled, then
  shared (FR-006, FR-007); an item of several groups is searched once, in its first group; inside a group by item
  ID while no scan time exists; non-numbers, 0, negatives, fractions and IDs with `unknown_items[id] = true` from
  the source are never searched (FR-008); a source that raises an error or returns nothing leaves the own catches;
  `SetItemSource(nil)` the same; the start line names the number of all three groups together (FR-012); after the
  scan `ns.Prices.Get(bundledItem)` and `Prices.GetAuction` return the found price for an item that is not in
  `fishedItems` (FR-009). The spec's edge cases: with `ns.db.settings.auctionPrices = false` a scan still runs and
  stores its prices (`ns.db.prices`), while `Prices.GetAuction` returns nil; an item added to `fishedItems` after
  a scan is searched by the next one in the own group, even when it is also in the shared set; a list that is empty
  after the checks (only unknown and unsellable items) prints `Nothing to scan yet: catch some fish first.` and
  sends no request.

### Implementation for User Story 2

- [X] T013 [US2] In `OneKeyFishing/CatchDB/Views.lua`: `CatchDB.ScanItems()` per contracts (the seed's items from
  `P.SeedItems()`; with `ns.Share.IsEnabled()` a new set built from the cells of `P.Others().byRecord` entries,
  `entry.cell.i` keys; otherwise an empty set), and at the end of the file
  `ns.Auction.SetItemSource(CatchDB.ScanItems)` (`Catch/Auction.lua` is earlier in the TOC). T011 passes.
- [X] T014 [US2] In `OneKeyFishing/Catch/Auction.lua` `BuildList` (data-model.md "The scan list", steps 1, 2, 4
  without the scan time): calls the source through `ns.Safe` (two sets, or none), gives each ID its group (`"own"`,
  then `"bundled"`, then `"shared"`), keeps the group per ID for later tasks, applies the present ID checks and
  `Unsellable` to every group, and orders by group, then ID. T012 passes.
- [X] T015 [P] [US2] In `OneKeyFishing/Core/Commands.lua`: the description of `scan` becomes
  `scan auction prices of the catch catalog's items (auction house must be open)`; the command table of
  `OneKeyFishing/README.md` gets the same wording by hand (`npm run check` only requires every command to be in
  the manual).

**Checkpoint**: a scan covers the catalog's items; the catalog, "What can be caught here", the statistics and the
tooltips show their prices through the unchanged `Prices` functions.

---

## Phase 5: User Story 3 - The scan stops when the auction house stops answering (Priority: P1)

**Goal**: ten seconds without a ready auction house stop the scan with one chat line; the scan buttons and the
command say why they cannot start one, and work again when it answers.

**Independent Test**: the stall cases of `tests/catch/auction_stall_test.lua` and `tests/ui/scan_buttons_test.lua`.
In game it cannot be provoked on purpose (quickstart step 10).

### Tests for User Story 3 (write first, see them fail)

- [X] T016 [P] [US3] Write `tests/catch/auction_stall_test.lua`, the stall cases (setup as T006, three own items
  with commodity results):
  - FR-013: the second request is never answered: after `advance(10)` the scan has stopped (`GetProgress()` not
    scanning), `GetState() == "stalled"`, the chat holds text 1 of the contracts exactly once with the counts
    `1` and `3`, the first item's price is stored, `PRICES_CHANGED` fired once, and a further `advance(60)` adds no
    request; before the 10 s (`advance(9)`) nothing of this happened;
  - FR-014: while stalled `CanScan()` is false, `WhyNot()` is text 2 and `Scan()` prints text 2 and sends nothing;
    with `auction_ready = true` and `fire("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")` the state is `"ready"`,
    `AUCTION_STATE` fired, `WhyNot()` is nil and a scan starts;
  - a stall without a scan: `auction_ready = false`, `fire("AUCTION_HOUSE_THROTTLED_MESSAGE_SENT")`,
    `advance(10)`: `"stalled"`, no chat line; the same when the window opens on a line that is not ready;
  - a scan started on a busy line (edge case): `auction_ready = false` at `Scan()`: the state is `"scanning"`, no
    request; ready after 5 s: the scan runs; never ready: after 10 s it stops with text 1 and counts `0`;
  - a busy line that recovers resets the clock: not ready for 9 s, ready (with its READY event), not ready for
    9 s: no stall;
  - the clock starts at the scan's own send, whatever the line reads then: right after a send set
    `auction_ready = true`, fire `AUCTION_HOUSE_THROTTLED_MESSAGE_SENT`, then set `auction_ready = false` with no
    further event: after `advance(10)` the scan has stalled as in the first case;
  - FR-016: `fire("AUCTION_HOUSE_CLOSED")` with a request unanswered prints the present stopped line, not text 1;
    the state is `"closed"`, `WhyNot()` is `Open the auction house first.`; `advance(60)` changes nothing;
  - `GetState()` is `"closed"` before the window opens, `"ready"` after, `"scanning"` during a scan.
- [X] T017 [P] [US3] Write `tests/ui/scan_buttons_test.lua` (`load_addon()`, then `ns.Auction.SetItemSource(nil)` and one
  item in `ns.db.fishedItems`, so the list is one item whatever the bundled database holds; the statistics window
  opened with
  `ns.StatsFrame.Toggle()` as in `tests/ui/stats_window_test.lua`; the main settings page, which holds the
  "Actions" buttons, taken from `settings_pages["OneKeyFishing"]` and shown through its `OnShow` script as
  `tests/ui/sound_page_test.lua` does for its page; the minimap menu read through `menu_entries`): closed: the statistics and settings buttons are disabled, the settings hint shows
  `(open the auction house first)`; open and ready: all enabled, the hint hidden, the button above the auction
  window reads `Scan fish prices`; scanning: all disabled, that button reads `Scanning 0/1`; stalled (as T016): all
  disabled, that button reads text 3, the settings hint shows text 2, the tooltip of the statistics window's button
  (its `OnEnter` script run while disabled) holds text 2, the minimap entry reads text 3 and is disabled; ready
  again: everything as "open and ready" without a reload; `/okf scan` (run with `SlashCmdList.ONEKEYFISHING("scan")`, as
  `tests/core/english_commands_test.lua` runs commands) prints text 2 while stalled and
  `Open the auction house first.` while closed.

### Implementation for User Story 3

- [X] T018 [US3] In `OneKeyFishing/Locales/enUS.lua` under `-- Auction.lua`, the three keys of the contracts
  ("Texts", 1 to 3), and their translations in the nine other locale files.
- [X] T019 [US3] In `OneKeyFishing/Catch/Auction.lua`, the stall (research R3, data-model.md "States"): constant
  `ANSWER_TIMEOUT = 10`; `busySince`, `stalled`; a local `Watch(event)` run by the five throttle events and by
  `AUCTION_HOUSE_SHOW`. The line counts as free only on a ready reading at
  `AUCTION_HOUSE_THROTTLED_SYSTEM_READY`, `..._MESSAGE_RESPONSE_RECEIVED`, `..._MESSAGE_DROPPED` or
  `AUCTION_HOUSE_SHOW`: that clears `busySince` and, when `stalled`, clears it and fires `AUCTION_STATE`. Everything
  else marks it busy: a not-ready reading at any of them, `..._MESSAGE_SENT` and `..._MESSAGE_QUEUED` whatever
  the reading (the game may not have switched the line yet), and the scan's own send, which takes no reading at
  all and restarts the clock (`busySince = GetTime()`: the line was ready a moment before). Marking busy otherwise
  sets `busySince = busySince or GetTime()` and arms one timer for
  `busySince + ANSWER_TIMEOUT` that reads the line when it fires: if `busySince` is unchanged and the line is not
  ready, it sets `stalled`,
  stops a running scan (text 1 with `found` and `total`, the queue emptied, `PRICES_CHANGED`) and fires
  `AUCTION_STATE`; `Watch` runs before `Pump` in the event handlers. `AUCTION_HOUSE_CLOSED` clears `busySince`
  and `stalled`. `Auction.GetState()`, `Auction.CanScan()` (`GetState() == "ready"`) and `Auction.WhyNot()` per
  contracts; `Auction.Scan()` prints `WhyNot()` when it has one. Keep `outstanding = { itemID, group }` of the
  scan's unanswered request across the stop and the closed window (cleared by the response, the item's result, or
  a ready reading at `AUCTION_HOUSE_THROTTLED_SYSTEM_READY`, `..._MESSAGE_DROPPED` or `AUCTION_HOUSE_SHOW`): T027 reads it. The group is the one `BuildList` gave
  the item (T014); while US2 is not built, it is `"own"`. T016 passes.
- [X] T020 [US3] In `OneKeyFishing/UI/Widgets.lua` `ns.UpdateScanButton(button, hint)`: enabled =
  `ns.Auction.CanScan()`; `button.reason = ns.Auction.WhyNot()`; a new helper in the same file,
  `ns.ShowReasonOnHover(button)`, gives a button once `SetMotionScriptsWhileDisabled(true)`, an `OnEnter` that
  shows `button.reason` (when set) in `GameTooltip` (white, wrapped) and an `OnLeave` that hides it, and
  `ns.UpdateScanButton` calls it; the hint, when given, shows
  `L["(open the auction house first)"]` while the state is `"closed"`, text 2 while `"stalled"`, and is hidden
  otherwise. `UI/StatsFrame.lua` and `UI/Settings.lua` keep calling it on `AUCTION_STATE` (no change expected; check).
- [X] T021 [P] [US3] In `OneKeyFishing/UI/AuctionButton.lua` `Update`: by `ns.Auction.GetState()`: `"scanning"` as
  today; `"stalled"`: text 3, disabled, `button.reason` text 2, shown by
  `ns.ShowReasonOnHover(button)` of T020 (called once in `Ensure`; `button.reason` is nil in the other states); otherwise `Scan fish prices`, enabled when `CanScan()`.
  `Ensure` measures the width over the three texts.
- [X] T022 [P] [US3] In `OneKeyFishing/UI/Minimap.lua`: the scan entry's text is text 3 while
  `ns.Auction.GetState() == "stalled"`, else `Scan auction prices`; disabled unless `CanScan()`. T017 passes.

**Checkpoint**: US1 and US3 together are the MVP: a fast scan that stops instead of sending into a silent house.

---

## Phase 6: User Story 4 - A repeated scan is short (Priority: P2)

**Goal**: a press searches only the items scanned 15 minutes ago or longer, the oldest first; a stopped scan
resumes; when everything is fresh, everything is scanned again.

**Independent Test**: the fresh cases of `tests/catch/auction_list_test.lua`; in game quickstart steps 5 and 6.

### Tests for User Story 4 (write first, see them fail)

- [X] T023 [US4] Extend `tests/catch/auction_list_test.lua` (saved times are set directly, `time()` is the real
  clock in the tests): an answered search sets `ns.db.priceScans[itemID]` to `time()` whether a price was found or
  the item is not on sale, and an item not on sale keeps the entry `ns.db.prices[itemID]` of an earlier scan
  unchanged (FR-010, research R7); items with `priceScans` 100 s old are not searched and the start line names only
  the others (FR-011, US4 scenario 1); with every item fresh, all are searched (scenario 2); a scan closed after 2
  of 5 answers, then a new scan: exactly the other 3 are searched (SC-004); `priceScans` 901 s old is searched,
  899 s old is not; inside one group: never scanned first, then the oldest scan time, ties by ID, and the group
  order still wins over the age (FR-007); a price of an earlier version (`prices[id].time` only, no `priceScans`)
  counts by its `time` (fresh when new, searched when old); an item skipped without item key info or without a
  result gets no scan time.

### Implementation for User Story 4

- [X] T024 [US4] In `OneKeyFishing/Catch/Auction.lua`: constant `FRESH_SECONDS = 15 * 60`; a local
  `ScanTime(itemID)` (the later of `ns.db.priceScans[itemID]` and `ns.db.prices[itemID].time`, 0 for none);
  `Settle` writes `ns.db.priceScans[itemID] = time()` for every answered item (not for a skipped one);
  `BuildList` orders by group, then `ScanTime` ascending, then ID, and returns the items with
  `time() - ScanTime >= FRESH_SECONDS`, or the whole kept list when there is none; it also counts the fresh ones for
  the debug report. T023 passes.

**Checkpoint**: the second press within 15 minutes is short; the whole catalog is paid once per visit.

---

## Phase 7: User Story 5 - A forged record cannot keep the auction house stopped (Priority: P2)

**Goal**: an item the auction house did not answer for is remembered with its group and not asked again; a shared
one leaves the shared group out; a new version of the addon forgets; the debug report shows it.

**Independent Test**: the guard cases of `tests/catch/auction_stall_test.lua` and the report test.

### Tests for User Story 5 (write first, see them fail)

- [X] T025 [US5] Extend `tests/catch/auction_stall_test.lua` (an item source with own, bundled and shared items):
  - FR-017: the stall on an own item's request writes `ns.db.scanGuard.items[itemID] = "own"` and
    `scanGuard.version = ns.version`; after `auction_ready = true` and a ready event, the next scan does not search
    it and does search the others;
  - a stall without an own request (a busy line, a scan still waiting) writes nothing;
  - FR-018: the stall on a shared item writes `"shared"`; later scans search no shared item at all, and still the
    own and bundled ones; a stall on a bundled item writes `"bundled"` and leaves the shared group in;
  - US5 scenario 6: an item of both the own catches and the shared set is remembered as `"own"` and does not set the
    mark;
  - scenario 3: after the stall, `auction_answer()` for that request (the late answer) removes the item from
    `scanGuard.items`; when it was the only shared one, the shared group is searched again;
  - FR-019: with `ns.db.scanGuard = { version = "0.0.1", items = { [A] = "shared" } }` a scan searches A and the
    shared group, and the table then holds the current version and no A;
  - research R3: a request unanswered when `AUCTION_HOUSE_CLOSED` fires is not remembered; `AUCTION_HOUSE_SHOW`
    with the line ready forgets it for good; `AUCTION_HOUSE_SHOW` with the line still not ready and `advance(10)`
    remembers it (state `"stalled"`, no chat line since no scan runs);
  - FR-020: `ns.Auction.Describe()` returns the lines of the contracts: the state, the last scan's numbers, the
    list's counts, `auction guard (<version>): <id>=<group>` sorted by ID or `none`, and
    `other players' items left out: yes` or `no`.
- [X] T026 [P] [US5] Extend `tests/core/report_sections_test.lua`: the report has a section "Auction scan" with the
  line starting `auction: closed` and the line `auction guard`, no section fails, and the "Catch database" section
  no longer holds `last price scan`.

### Implementation for User Story 5

- [X] T027 [US5] In `OneKeyFishing/Catch/Auction.lua` (research R8): a local `Guard()` returning
  `ns.db.scanGuard` after emptying `items` and setting `version = ns.version` when the versions differ; the stall
  timer of T019, when `outstanding` is set, writes `Guard().items[outstanding.itemID] = outstanding.group`; the
  response or result that clears `outstanding` also removes that item from `Guard().items` (a ready reading
  alone clears `outstanding` and leaves the item remembered: the line recovered, the answer did not come); `BuildList` leaves out
  the remembered items and, when some value of `Guard().items` is `"shared"`, the whole shared group.
- [X] T028 [US5] In `OneKeyFishing/Catch/Auction.lua`: `Auction.Describe()` per contracts (English, item IDs and
  counts only; the last scan's `searched`, `requests`, whole seconds, `found`, `noInfo`; the list's counts of the
  last `BuildList`; the guard line; the present coverage line). In `OneKeyFishing/Core/Debug.lua`: a section
  `"Auction scan"` after "Catch database" that adds each line of `ns.Auction.Describe()`; the coverage line leaves
  the "Catch database" section. T025 and T026 pass.

**Checkpoint**: every story is built; `npm run check` lists exactly the markers V54 to V57 as new.

---

## Phase 8: Polish and cross-cutting

- [X] T029 [P] Documentation, in English (no Cyrillic):
  - `docs/architecture/catch-and-stats.md`, "Catch/Auction.lua": rewritten (the request machine and its turn, item
    key info first, the paging rule, the list and its groups, fresh prices, the stall and the states, the guard, the
    functions of the contracts, the constants); "Catch/Prices.lua": the two fields; the tests list;
  - `docs/architecture/catch-db.md`: `CatchDB.ScanItems()` and that `Views.lua` sets it as the scan's item source;
  - `docs/architecture/ui.md`: `ns.UpdateScanButton` (reason, hint, tooltip), the button above the auction window
    and the minimap entry while stalled; the new UI test;
  - `docs/architecture/core.md`: the saved fields `priceScans` and `scanGuard` (written by Auction.lua); the
    "Auction scan" section of the debug report;
  - `CLAUDE.md`: the messages line (`AUCTION_STATE`: scan progress and the scan's state; `PRICES_CHANGED`: a scan
    finished or stopped, also on a stall); a cross-module rule "The scan's items beyond the own catches come from
    `CatchDB.ScanItems` through `Auction.SetItemSource`; `Catch/Auction.lua` names no module of layer 2"; feature
    018 in the list of features with a `verification.md`; the documents table's `auction-plan.md` row (the scan is
    built, Auctionator not); keep it consistent with `.specify/memory/constitution.md`;
  - `docs/auction-plan.md`: the status line and "Feature 1" point to `specs/018-auction-scan` as built; open check 1
    stays until V54 closes;
  - `docs/ROADMAP.md`, "Planned": the scan leaves, Auctionator as a price source (spec 019, 1.4.0) stays.
- [X] T030 [P] `docs/checklists/auction-scan.md` following `docs/checklists/README.md` "How a checklist is built":
  header (closes V54 to V57; needs one character at an auction house, a second character with few catches for step
  4, a grey item for step 8), setup (no new file in the TOC: a `/reload` is enough), the ten steps of quickstart.md
  "In game" with blanks for seconds, items, prices and the debug report's "Auction scan" lines, each naming its FR,
  SC or V; the rule that every step is one action and that nothing else is typed into the auction house during a
  scan; the grey-item line of `verification.md` V54 written out. Its row in the table of
  `docs/checklists/README.md`.
- [X] T031 `CHANGELOG.md`: create `## [Unreleased]` above `## [1.3.1]` with `### Changed`: the auction scan covers
  every item of the catch catalog, not only your own catches (the first scan of a visit takes about a minute); it is
  several times faster right after a login and no longer loses prices; a press within 15 minutes scans only what
  was not scanned yet; when the auction house stops answering, the scan stops within 10 seconds and says so, and
  the scan buttons show it. `OneKeyFishing/README.md`, "Auction prices": what is scanned (the three groups in plain
  words), the fresh prices and the resumed scan, the auction house that does not answer and the relog, that grey and
  bound items are not searched; the feature bullet "Auction scan" near the top (no longer "everything you have ever
  caught").
- [X] T032 Run `npm run check` and `npm test`; compare with T001 (the new tests added, the markers V54 to V57 the only
  new ones); set the spec's status to "Implemented"; hand `docs/checklists/auction-scan.md` to the author; what the checklist confirms is recorded in
  `docs/forever-api.md` when the author closes V54 to V57 (the steps of `verification.md`). The
  version stays 1.3.1 here: the bump to 1.3.2 is a release step of `docs/publishing.md`, and `npm run build` refuses
  while a marker is open (the author closes them with the checklist or releases with `--force`).

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (Phase 1)**: none.
- **Foundational (Phase 2)**: after T002. Blocks every story.
- **US1 (Phase 3)**: after Phase 2.
- **US2 (Phase 4)**: after US1 (`BuildList` and `SetItemSource` exist).
- **US3 (Phase 5)**: after US1 (the machine). Independent of US2; may be built before it (the plan's order of work:
  US1, US3, US2).
- **US4 (Phase 6)**: after US2 (the order inside the groups).
- **US5 (Phase 7)**: after US2 (the groups) and US3 (the stall and `outstanding`).
- **Polish (Phase 8)**: after the stories it documents; T032 last.

### Within each story

- The test task first, seen failing; then the code tasks in their order; the story's checkpoint before the next.
- `OneKeyFishing/Catch/Auction.lua` is touched by T008, T009, T010, T014, T019, T024, T027, T028: one at a time.

### Parallel opportunities

- Phase 2: T003 and T005; T004 after T003.
- US2: T011 and T012 (two test files); T015 with anything.
- US3: T016 and T017 (two test files); T021 and T022 after T020 (T021 uses its helper).
- US5: T026 with T025.
- Polish: T029 and T030.

## Parallel Example: User Story 3

```text
Together: T016 (tests/catch/auction_stall_test.lua) and T017 (tests/ui/scan_buttons_test.lua)
Then:     T018 (texts), T019 (Auction.lua), T020 (Widgets.lua)
Together: T021 (AuctionButton.lua) and T022 (Minimap.lua)
```

## Implementation Strategy

### MVP first (User Stories 1 and 3)

1. Phase 1 and Phase 2.
2. Phase 3 (US1) and Phase 5 (US3): the fast scan of the own catches that stops on a silent auction house. US1 alone
   is not shippable: without the stall it would wait forever on an unanswered request.
3. Stop and validate: `npm test`; the author can run quickstart steps 1 to 3 and 9 in game.

### Incremental delivery

1. US2 (the catalog's items), then US4 (fresh prices), then US5 (the protection). US2 is not released without US5:
   the items of other players' records need the guard.
2. Polish: documents, checklist, changelog and manual in the same change as the code (definition of done).
3. Hand the checklist to the author; commit only when the author asks.

## Notes

- 32 tasks: Setup 2, Foundational 3, US1 5, US2 5, US3 7, US4 2, US5 4, Polish 4.
- The stall is covered by tests only (it cannot be provoked in game on purpose); the checklist's step 10 says what to
  note if one happens.
