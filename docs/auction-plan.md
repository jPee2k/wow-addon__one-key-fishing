# Auction plan

Two features around auction prices, researched on 2026-11-17; the first is built (spec 018), the second is not:

1. **A faster and safer price scan** (`Catch/Auction.lua`).
2. **Auctionator as a price source**: a player who also runs Auctionator gets its prices, and the addon's own scan
   button goes away.

Status: the research and the in-game checks are done and the author's decisions are taken (2026-11-17, "Decisions"
below). The scan is spec 018 (`specs/018-auction-scan`, built; its in-game checks V54 to V57 are open) and release
1.3.2; Auctionator is spec 019 and release 1.4.0, not specified yet; each on its own branch. When a feature is built, its part of this file moves to the spec, and the file goes to
`docs/history/` once both are done.

## Where the facts come from

- **The game** (Thunder Bluff, 2026-11-17, `/run` with an event listener): every measured fact below is recorded in
  [forever-api.md](forever-api.md), "Verified in game", the entry "The auction house's request system".
- **The client export** (`Blizzard_APIDocumentationGenerated/AuctionHouseDocumentation.lua`, build 1.60.1): the
  functions and events named here exist; `SendSearchQuery` is documented as limited to 100 calls a minute.
- **Auctionator 347** (a copy in `static/examples/`, not in the repository): read to learn how the game's auction
  API behaves. Its licence is "All Rights Reserved": the addon takes knowledge about the game API from it and calls
  its public API (`Auctionator.API.v1`), and copies none of its code.

## What the game showed

| Fact | Numbers |
|---|---|
| A healthy request | sent, answered 0.2 s later, the system ready 0.5 s after the send |
| The addon's scan, every item key cached | 40 items in 28 s: 40 requests, 0.7 s each, 32 prices |
| The same scan, 25 item keys not cached | 162 s: 53 requests (13 extra pages), 31 prices |
| Auctionator's scan of the whole house | 6765 items in 32 s (browse summaries: the cheapest price and the count) |
| A request the server never answers | the auction house is jammed until the character logs out and in |

Two requests are known to get no answer: `C_AuctionHouse.SearchForItemKeys` (any call), and `SendSearchQuery` for
an item the client knows but the game does not have yet (13755, 13890). An item that exists and is not listed is
answered.

## Rules that follow

These hold for every change to the scan:

- **Never call `SearchForItemKeys`.**
- **Search only items that came from a catch**: the player's own, the bundled catch database, other players'
  records. An item ID from any other list may be one the server does not answer. A record of another player may
  be forged, so those items go last and an unanswered item is remembered ("Decisions", 7).
- **One request at a time, only when the system is ready.** A request sent while it is not ready is queued, and
  the next one drops it.
- **A request without an answer ends the scan.** The scan must notice it, stop sending and tell the player that
  the auction house needs a relog; today it keeps going with a 4 s timeout per item.
- The server's pace is 0.7 s per request: a scan gets faster only by sending fewer requests and by not waiting.

## Feature 1: the scan

Built in spec 018: the spec, plan and research in [specs/018-auction-scan](../specs/018-auction-scan/) hold what
was decided; the table below is the plan it started from.

What to change, in the order of what it gains:

| # | Change | Gain | Basis |
|---|---|---|---|
| 1 | Have the item key info before a search: ask `C_AuctionHouse.GetItemKeyInfo` for every item when the scan starts, wait for `ITEM_KEY_ITEM_INFO_RECEIVED` of the missing ones (0.01 s in the test), then search | 162 s to 28 s on a cold cache, and no lost prices | measured |
| 2 | A watchdog: no `AUCTION_HOUSE_THROTTLED_MESSAGE_RESPONSE_RECEIVED` within a few seconds of a send, or the system not ready when the scan starts and still not after the same wait: stop, keep the prices found, tell the player to log out and in | the scan no longer runs on in a jammed house | measured (the jam), the wait is a choice |
| 3 | Skip fresh prices: an item scanned less than N minutes ago is not searched again; the oldest prices go first; a scan stopped by closing the window goes on from there the next time | a repeated scan takes seconds | design (`db.prices[itemID].time` exists) |
| 4 | Stop paging early: the price needs the cheapest 20% of the listed pieces and the results come in rising price order, so no further page once the loaded pieces cover that share | fewer requests for items with many listings | design, the order was seen (V4) |
| 5 | Send the next request on `AUCTION_HOUSE_THROTTLED_SYSTEM_READY`, not on a 0.5 s retry timer | no idle time between requests | the event was seen |
| 6 | Leave out items that cannot be listed (poor quality, bound) | fewer requests | open check 1; a `VERIFY` marker until then |
| 7 | Scan every item of the catalog, not only the player's own catches (80 items in the bundled database of 1.3.1, 40 in the author's own list): the own catches first, then the bundled database, then items known only from other players' records | the catalog shows auction prices; today it shows the vendor price for what the player never caught | decision 6 |
| 8 | Remember an item the server did not answer (saved, never searched again); after that on an item of other players' records, such items are not scanned until the next version of the addon | a forged record costs one relog at most | decision 7 |

Not in 018: asking once more when an answer is empty although the item is listed (Auctionator's workaround). It
did not show in the tests and costs a request per unlisted item.

Where: all of it inside `Catch/Auction.lua` (layer 1). The messages stay (`AUCTION_STATE`, `PRICES_CHANGED`);
`Auction.GetProgress()` may gain a state for the watchdog's stop, and the scan button shows it. The new texts go
through `ns.L` with their nine translations; the new events and functions go into `.luacheckrc`. The price itself
(the cheapest 20%, "few lots") does not change.

Tests (without the game, in `tests/catch/`): the key info wait, the watchdog, the fresh-price skip and its order,
the early stop of paging, the resume after a closed window. In game: a checklist with a cold and a warm scan and
their times.

## Feature 2: Auctionator as a price source

What its public API gives (seen working in WoW Forever):

| Call | Result |
|---|---|
| `Auctionator.API.v1.GetAuctionPriceByItemID(callerID, itemID)` | the cheapest unit price in copper at its last scan or search, or nil |
| `Auctionator.API.v1.GetAuctionAgeByItemID(callerID, itemID)` | the days since the item was last seen, nil after 21 days or when never seen |
| `Auctionator.API.v1.RegisterForDBUpdate(callerID, callback)` | a callback after each of its searches and at the end of a scan; it cannot be removed |

The limits:

- **Another kind of price.** Auctionator keeps the cheapest lot; the addon keeps the average of the cheapest 20% of
  the listed pieces. Its prices are lower, and one lot far below the market decides them.
- **No count of pieces or lots**, so the "few lots" rule cannot be applied to its prices.
- **Only what it has seen.** Its full scan is the player's choice; an item it never met has no price, so every item
  needs a fallback (the addon's own price, then the vendor price).
- **Ready after `PLAYER_LOGIN`**; before that the calls return nil. A wrong argument raises an error: the calls go
  through `ns.Safe`.
- **The callback is frequent**: it also comes during the addon's own scan (Auctionator hears the game's search
  events). `PRICES_CHANGED` must be sent at most once per moment, not per callback.
- **Presence is checked per function** (`Auctionator.API.v1.RegisterForDBUpdate ~= nil`), at run time, never while
  the files load.
- Auctionator keeps its prices per game mode (`PvP`); the addon's `db.prices` is one table for the account. See
  the open question about the auction houses in [forever-api.md](forever-api.md).

Where:

- `Catch/Prices.lua` (layer 1) learns the price source: its own scan or Auctionator. `Prices.GetAuction` asks the
  source; the callback of `RegisterForDBUpdate` becomes `PRICES_CHANGED`, which the windows already follow.
- `UI/AuctionButton.lua` asks `Prices` whether the own scan is in use and hides the button otherwise; the lower
  layer names no frame.
- A setting for the source, changed through a module function that fires `SETTINGS_CHANGED` (the rule of
  `CLAUDE.md` for settings with an effect).
- `## OptionalDeps: Auctionator` in the TOC, `Auctionator` in `.luacheckrc`, a line in `/okf debug` (the source,
  whether the API is there), the manual and the changelog.

Tests: `Prices` with a stub of `Auctionator.API.v1` (a price, no price, an old price, an error, no Auctionator).
In game: a checklist with and without Auctionator.

## Rejected

- **`SearchForItemKeys`** as one request for the whole list: the server does not answer it.
- **`ReplicateItems`** (the whole house, once in 15 minutes): far more than 40 items need, and not checked.
- **A browse of the whole house as the price**: it gives only the cheapest price, which breaks the addon's price
  rule; 32 s for what the own scan does in 28 s.

## Decisions

Taken by the author on 2026-11-17.

The work:

1. **Two specs, the scan first**: 018 the scan, released as 1.3.2; 019 Auctionator, released as 1.4.0.

The scan (018):

2. **What goes in**: fixes 1 to 8 of the table above.
3. **Fresh prices**: a price is fresh for 15 minutes. A press of the button scans what is not fresh, the oldest
   first; when every price is fresh, it scans everything again (no dead press, no modifier key).
4. **The watchdog**: no answer within 10 s of a request (a healthy one takes 0.2 s). The scan stops and keeps the
   prices found; one chat line says the auction house does not answer and needs a relog; the scan buttons are
   disabled with that text while the system is not ready, also when something else jammed it before the scan.
   The scan itself must not cause a jam: the rules above.
5. **No scan by itself**: only a press starts it, not the opening of the auction house.
6. **The scan's list**: everything the catalog shows. The display rule stays: the auction price when the scan
   found one, else the vendor price, else "No price".
7. **Protection of that list**: the order own catches, bundled database, other players' records; an unanswered
   item is remembered and never searched again; after one on an item of other players' records, those items are
   left out until the next version of the addon.
8. **Prices per game mode**: not now. `db.prices` stays one table until the game shows how the auction houses are
   split (open check 4); it goes to the roadmap.

Auctionator (019):

9. **Which price**: Auctionator's when it has one for the item, else the addon's own stored price, else the vendor
   price.
10. **The switch**: a checkbox "take prices from Auctionator" next to the auction price setting, on by default,
    active only when Auctionator is installed. Off: the addon's own scan and prices are back.
11. **No age limit**: Auctionator's price is taken at any age, as the addon's own prices are.
12. **No "few lots" rule** for Auctionator's prices: they go into the sums as they are, the same price its tooltips
    show. Accepted risk: one overpriced lone lot of a rare item raises the catch value.
13. **The scan's entries**, with Auctionator's prices in use: the four buttons (above the auction house, the
    statistics window, the settings page, the minimap menu) are hidden; the slash command answers that the prices
    come from Auctionator.
14. **The hint**: the statistics window's line about the values says the prices come from Auctionator and, when
    some of the player's items have no price there, how many, with the advice to run its scan. Nothing in chat.

## Follows from the decisions

- With the catalog's items in the list the first scan is about a minute (80 items and more at 0.7 s); the fresh
  prices make the next ones short.
- The remembered unanswered items and the "leave out other players' items" mark are new saved fields, filled by
  `ApplyDefaults` without a `DB_SCHEMA` bump (nothing is renamed or reshaped), listed in
  `docs/architecture/core.md`.
- `Catch/Auction.lua` is layer 1 and the catalog layer 2: the scan cannot ask `ns.Catalog` for its items. The
  catch database hands them to the scan through a callback (`Auction.SetItemSource`, plan of spec 018, research R6).
- The pace: the next request on the ready signal, but not above the documented 100 a minute (0.6 s between
  requests; plan of spec 018, research R2).
- Feature 2's part "Where" names one button; decision 13 hides four and changes the slash command's answer.
- 1.3.2 is a patch by the author's choice, though the buttons' behaviour changes; the changelog says so.

## Open checks in game

1. Can a poor-quality item be listed? `C_AuctionHouse.IsSellItemValid` on one in the bags, with the auction house
   open (fix 6). The line is in the conversation of 2026-11-17; it sends nothing to the server.
2. Does a jammed auction house ever recover without a relog (a long wait)? Seen only up to a few minutes.
3. On a cold cache, is a search answered late or with an empty result? It decides nothing once fix 1 is in; only
   the reason for the 162 s.
4. The open question of [forever-api.md](forever-api.md): one auction house per game mode, per faction or shared.

Every further check of the auction API is one request at a time with the listener on, and none with an item that
did not come from a catch.
