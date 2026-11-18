# Research: Auction Scan

**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

Where the facts come from: the author's measurements in the game on 2026-11-17 ([docs/forever-api.md](../../docs/forever-api.md),
"The auction house's request system"; summary in [docs/auction-plan.md](../../docs/history/auction-plan.md)), the client export
(`Blizzard_APIDocumentationGenerated/AuctionHouseDocumentation.lua`, build 1.60.1) and a reading of Auctionator 347
(`Source_ModernAH/AH/Mixins/Throttling.lua`, `ItemKeyLoader.lua`, `SearchScan.lua`). Auctionator's licence is "All
Rights Reserved": what is taken from it is knowledge about the game's API, named per decision below; none of its code.

No `NEEDS CLARIFICATION` is left. Four assumptions wait for the game (V54 to V57, [verification.md](verification.md)).

## R1. The item key info comes before the search (FR-001)

- **Decision**: when a scan starts, it calls `C_AuctionHouse.GetItemKeyInfo(C_AuctionHouse.MakeItemKey(itemID))` for
  every item of its list (the call asks the server for what the client lacks). An item is searched only when that call
  returns a table. The scan takes the first item of its order that has the info; an item still without it waits and is
  taken as soon as `ITEM_KEY_ITEM_INFO_RECEIVED(itemID)` arrives. When only waiting items are left, the scan waits
  `INFO_WAIT = 3` s for them and then ends without them: they are not searched, not remembered and get no scan time, so
  the next scan tries them again. The info is asked once per item, at the start: a call for a missing key asks the
  server again, so the scan keeps what the first call returned and reads an item once more only when its event
  arrives.
- **Rationale**: measured: with 25 of 40 keys missing the scan took 162 s and 53 requests and lost a price; with every
  key cached 28 s and 40 requests. The info arrived 0.01 s after it was asked for, and the 25 infos were not throttled
  messages (53 sent messages = 40 searches + 13 pages). Auctionator does the same (`ItemKeyLoader`: ask, wait for the
  event, then search).
- **Alternatives**: a first "warm-up" pass over the list (two passes, no gain); searching at once and repeating the
  empty answers (Auctionator's workaround, a second request per item; rejected in the plan).
- **Open**: asking for the whole list at once (about 100 keys) was seen only for 25: `VERIFY(V56)`.

## R2. When the next request goes out (FR-002, FR-015)

- **Decision**: one function, `Pump`, sends the scan's next request. It runs on the throttle events that can
  free the line (`AUCTION_HOUSE_THROTTLED_SYSTEM_READY`, `..._MESSAGE_RESPONSE_RECEIVED`, `..._MESSAGE_DROPPED`; not
  on `..._MESSAGE_SENT` and `..._MESSAGE_QUEUED`, which only mark it busy), on a result event, on an item key info
  and on its own timer, and sends only when all hold: the
  window is open, no request of the scan is in flight, `C_AuctionHouse.IsThrottledMessageSystemReady()` is true, and
  `MIN_INTERVAL = 0.6` s have passed since the scan's previous request. No retry timer polls the ready state.
- **Rationale**: the ready state is read from the game at each event, never kept in a flag (Auctionator's
  `Throttling.lua` does exactly this: every throttle event re-reads `IsThrottledMessageSystemReady`). One READY event
  per scan was missing in both measured scans (52 of 53, 39 of 40), so READY alone is not enough; the response event
  covers it. The 0.6 s floor is the client's documented limit for `SendSearchQuery`, 100 calls a minute: a healthy
  request is ready again after 0.5 s (120 a minute), and what the server does above its limit is not known. A request
  the server does not answer costs the player a relog, so the scan stays inside the documented limit.
- **A missed READY event**: while a scan waits on a line that reads busy, `Pump` reads it again once a second
  (`RECHECK`). It sends nothing and reads only the client's flag; without it, one missed READY (as in both measured
  scans) would hold the scan until the 10 s timer.
- **Gain**: 0.7 s per request today (a 0.5 s poll after the answer) becomes 0.6 s; the large gain is R1 and R4, not
  the pace.
- **Alternatives**: no floor (FR-002 as first written; 0.5 s per request, above the documented limit: rejected for
  safety, the spec's FR-002 now names the limit); the present 0.5 s poll (idle time and a timer per item).
- **Open**: that a request every 0.6 s is answered like one every 0.7 s: `VERIFY(V57)`, the checklist's long scan.

## R3. One clock for "does not answer" (FR-013, FR-014, FR-016)

- **Decision**: the module follows the ready state while the auction window is open, scan or no scan. `busySince` is
  the moment the system was first seen not ready (set by a throttle event, by `AUCTION_HOUSE_SHOW` and by the scan's
  own send); a ready reading clears it; every response starts it again (the server answers: a jam sends none,
  while another addon's steady traffic, such as Auctionator's scan, may never let the line read ready). When it has been not ready for `ANSWER_TIMEOUT = 10` s without a break, the
  state is `"stalled"`: a running scan stops and keeps its prices, one chat line is printed, `AUCTION_STATE` fires and
  the scan buttons are disabled. The next ready reading ends the state by itself.
- **Which item is to blame**: `outstanding` is the item of the scan's own request that has no answer yet (set at the
  send, cleared by `AUCTION_HOUSE_THROTTLED_MESSAGE_RESPONSE_RECEIVED` or by the item's result event). When the stall
  comes with an `outstanding` item, that item is remembered (R7); a stall without one (another addon's or the
  player's request, or a scan still waiting for its turn) remembers nothing.
- **Why the response event is the scan's own**: the scan sends only while the system is ready, so no other throttled
  message is in flight; in a jam every later request is queued or dropped, never sent, so the next response can only
  be the one the scan waits for.
- **Closing the window** stops the scan as today, with today's line; it is not a stall. An `outstanding` item is kept
  in memory: when the window opens again and the system is ready, it is cleared; when it stays not ready for 10 s, it
  is remembered then. Without this a player who closes the window within 10 s of a jam would be jammed a second time.
  Left out on purpose: a relog without reopening the window forgets the item (it is in memory only), and the second
  jam is then remembered by the normal path (the exception named in the spec's SC-006).
- **The clock is the line's, not the scan's**: `busySince` may be older than the press that started the scan, so a
  scan started on a line that is already busy can stop sooner than 10 s after the press (spec, edge cases).
- **Rationale**: measured: a healthy request is answered in 0.2 s and ready in 0.5 s; a jam leaves the system not
  ready through a closed window and a `/reload`. Ten seconds is the author's decision.
- **Which readings count**: whether the game switches the line to "not ready" inside the send call or a moment
  later was not measured, so the module never trusts a ready reading taken at the scan's own send, at
  `..._MESSAGE_SENT` or at `..._MESSAGE_QUEUED`: those three only mark the line busy (the own send without a
  reading at all). The line counts as free on a ready reading at `..._SYSTEM_READY`, `..._MESSAGE_RESPONSE_RECEIVED`,
  `..._MESSAGE_DROPPED` or `AUCTION_HOUSE_SHOW`, and the 10 s timer reads it once more when it fires. Otherwise a
  reading taken too early would clear the clock and the blame, and a jam, which sends no further event, would never
  be noticed.
- **Ready without a response**: when the line is ready again (a reading at `..._SYSTEM_READY` or
  `..._MESSAGE_DROPPED`) while the scan's request still has no response
  event, the request counts as answered without a result: the item is skipped after `RESULT_WAIT` (not stored, not
  remembered) and the scan goes on. Not seen in the game; without the rule the scan would wait on a ready line with
  no stall to end it.
- **A slow auction house** (the answer came, the system stays not ready longer than 10 s): the scan stops with the
  same line and remembers nothing; the buttons work again when the system is ready. Accepted: it was not seen.
- **Alternatives**: a timer per request as today (4 s, then the next item: it sends into a jammed house); two clocks
  (answer and ready): the same result with more state.

## R4. Paging stops when the price is decided (FR-003)

- **Decision**: after each commodity result the scan asks for the next page only while the price is open:
  not `HasFullCommoditySearchResults`, fewer than `MAX_MORE_REQUESTS = 5` pages asked, and not `PriceDecided`.
  `PriceDecided(listings, listed)` is true when the loaded pieces cover the wanted share
  (`max(1, ceil(listed * 0.2))`), are at least `Prices.FEW_PIECES` (5), and the loaded rows are at least
  `Prices.FEW_LOTS` (3). The next page is a request like any other: it goes out through `Pump` (ready, 0.6 s), not at
  once as today.
- **Why the mark stays equal**: "few lots" is "fewer than 5 pieces or fewer than 3 rows the price saw". With every
  page loaded both counts can only be higher, so a price decided early is never marked, and one that would be marked
  is never decided early (the scan pages on to the end or to the page limit, as today).
- **Why the price stays equal**: the price is the average of the cheapest wanted share; the search is sent with the
  price sort, so the loaded rows are the cheapest ones. That later pages are never cheaper is `VERIFY(V55)`; the rows
  are still sorted locally, as today.
- **Fixed on the way**: today a page is asked for only if the system happens to be ready at the result event (0.2 s
  after the send it usually is not), otherwise the first page decides: the price then depends on timing. Now the
  scan waits for its turn.
- **Not changed**: items that are not commodities use the first result page, as today.
- **Alternatives**: always every page (13 extra requests in the measured scan); never a page (wrong price for an item
  with many price points).

## R5. Items that cannot be sold (FR-004)

- **Decision**: an item is left out of the list when the game says it is of poor quality or bound: `quality == 0`
  or `bindType` 1 (bind on pickup) or 4 (quest) from `C_Item.GetItemInfo` (the third and fourteenth value), read when
  the list is built. When the game has not loaded the item's data yet (`GetItemInfo` returns nothing), the item
  stays in the list: the filter saves requests, it is not a protection (the measured scan asked for such items and
  was answered). The item key info's `quality` is checked once more before the send.
- **Rationale**: the author's own list of 40 holds grey and quest items; each costs 0.6 s for no price.
- **Open**: that such items cannot be listed in WoW Forever: `VERIFY(V54)` (open check 1 of the plan document).
- **Measured 2026-11-18**: `C_AuctionHouse.IsSellItemValid` is true for a grey item (Snapped Spider Limb), so poor
  quality left the rule: only `bindType` 1 and 4 are left out, and the item key info's `quality` is not checked.
- **Alternatives**: `C_AuctionHouse.IsSellItemValid` (needs the item in the bags); the catalog's kinds (layer 2).

## R6. The scan's list without breaking the layers (FR-006 to FR-008)

- **Decision**: `Catch/Auction.lua` (layer 1) knows the own catches (`db.fishedItems` and the statistics' items, as
  today) and takes the rest from an item source handed to it: `Auction.SetItemSource(fn)`, where `fn()` returns two
  sets, the bundled database's items and the items of other players' records. `CatchDB/Views.lua` (layer 2) sets it
  when it loads to the new `CatchDB.ScanItems()`: the seed's items (`P.SeedItems`, present) and, while sharing is on,
  the items of the counted records of other players (the index `P.Others`) that the catalog shows: one the own
  catch has, or one 3 other contributions report on one map (the catalog's rule), so a single forged record cannot
  add an item to the scan.
- **Rationale**: the layer rule forbids `Auction` to name `ns.CatchDB` or `ns.Catalog`; a callback set by the upper
  layer keeps the direction (`Comm.SetPartFilter` is the precedent). The catalog's own index is built in frame steps
  and per filter: the scan must not wait for it nor follow a filter (FR-008).
- **The list**: each ID once, in the first group it belongs to (own, bundled, shared); only positive whole numbers
  the client knows (`C_Item.GetItemInfoInstant(itemID) ~= nil`, the catalog's own rule for a hidden item); without
  the remembered items, the unsellable ones and, when the left-out mark is set, the shared group.
- **Alternatives**: every caller passing the list (five entry points repeat it); a message that asks for the list
  (a message with an answer is not what the bus is for); moving the scan to layer 2 (`Prices` and `Stats` use it).

## R7. Fresh prices and the order (FR-007, FR-010 to FR-012)

- **Decision**: a new saved table `priceScans[itemID] = time()` holds when the item's search was last answered, with
  a price or without. The scan time of an item is the later of that and `prices[itemID].time` (prices of earlier
  versions have only the second); none means never scanned. A scan searches the items whose scan time is 15 minutes
  old or more (`FRESH_SECONDS = 900`); when there is none, it searches the whole list. Order: the group, then the
  scan time from the oldest (never scanned first), then the item ID.
- **An item not on sale keeps the price of an earlier scan**, as today (`prices` is written only when a price is
  found); only its scan time is new. The spec's wording is made exact on this point (User Story 2, scenario 2).
- **Rationale**: a stopped scan resumes by itself: the items it reached are fresh, the others are not. `prices` keeps
  its shape, so earlier versions' prices stay and an older version of the addon reads the file unchanged.
- **Alternatives**: `prices[itemID] = { time }` without a price (changes what an entry means for every reader); a
  list of "left to scan" (a second source of truth).

## R8. The protection's memory (FR-017 to FR-020)

- **Decision**: a new saved table `scanGuard = { version, items }`. `items[itemID]` is the group the item had when
  its request got no answer (`"own"`, `"bundled"`, `"shared"`). The left-out mark is not stored: it is "some item of
  `items` is `"shared"`". The table is read through one function that empties it when `version` differs from
  `ns.version` (FR-019). An item is forgotten when its answer arrives later in the session (R3), which also takes the
  mark back if it was the only shared one.
- **Rationale**: one table, one rule; the mark cannot disagree with the items. The debug report prints the IDs and
  the mark (FR-020).
- **Alternatives**: a separate boolean (two fields to keep in step); a command to forget (out of scope by the spec).

## R9. The saved data needs no migration

- **Decision**: `priceScans` and `scanGuard` are new keys filled by `ApplyDefaults`; `DB_SCHEMA` stays 1 (nothing is
  renamed, moved or reshaped; the precedent is `settings.catalogSort` of spec 017). `docs/auction-plan.md` said
  "a `DB_SCHEMA` bump": corrected there.

## R10. The scan's states for the buttons (FR-014)

- **Decision**: `Auction.GetState()` returns `"closed"`, `"ready"`, `"scanning"` or `"stalled"`; `Auction.CanScan()`
  is `"ready"`; `Auction.WhyNot()` returns the localized reason a scan cannot start (`nil` when it can or one is
  running). Every entry uses them: the button above the auction window shows "Auction house not answering" while
  stalled; `ns.UpdateScanButton` (statistics window) disables the button and shows the reason on hover
  (also while disabled; the settings page's button and hint were removed on 2026-11-18); the minimap menu's entry is disabled and reads
  "Auction house not answering"; `/okf scan` prints the reason. No new message: `AUCTION_STATE` fires on every change
  of the state.
- **Rationale**: one "can scan now" rule for all entries (spec, edge cases); the statistics window's button keeps its
  text, so the window's button rows (measured at creation) do not move.
- **Texts**: three new keys (contracts), nine translations each; the present five scan lines stay.

## R11. Tests without the game (Principle V)

- **Decision**: `tests/wow.lua` gets a stand-in auction house with a request line: `IsThrottledMessageSystemReady`
  follows a flag, `SendSearchQuery` and `RequestMoreCommoditySearchResults` record the request and clear the flag
  (a helper answers: response event, result event, ready event), `GetItemKeyInfo` answers from a table (missing
  items arrive by event), `C_Item.GetItemInfo` gives quality and bind type. The present `auction_price_test.lua`
  keeps its cases (the price rule must not change); the ones that describe the old paging (a page asked at once, the
  4 s timeout) are rewritten to the new rule. New files in `tests/catch/` per user story (quickstart).
- **Rationale**: every rule of R1 to R8 is plain logic over events and a clock, which the stubs already move.

## R12. What only the game can show

- **Decision**: a new checklist `docs/checklists/auction-scan.md`: a first scan after a login and a repeated one with
  their times and price counts (SC-001, SC-002), the catalog by price on a character with few catches (SC-003), a scan
  stopped by closing the window and resumed (SC-004), the buttons' states, and the four `VERIFY` items. The stall is
  not provoked on purpose (it costs a relog and no safe way to cause one is known); if one happens, the checklist says
  what to note. Every auction check stays one step at a time, with items from catches only.
