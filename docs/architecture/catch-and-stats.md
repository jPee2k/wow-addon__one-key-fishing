# Architecture: catches, statistics and prices

How casts become catch messages, how they are counted, and how items are valued.

## Catch/Catch.lua

- Turns casts and loot into `FISH_CAUGHT` / `FISH_MISSED` messages.
- The items of `FISH_CAUGHT` are `{ link, itemID, quantity, quality }`; `itemID` is read once here from the loot link
  (`ns.ItemIDFromLink`, also for an item the client does not know yet), so Stats and CatchDB do not look it up again.
  `quality` is the loot slot's (`GetLootSlotInfo`, 5th value), else `C_Item.GetItemQualityByID`, else nil; the
  fishing sounds read it for the rare sound (spec 013).
- Whether the loot came from a fishing pool is not known: in Forever a pool catch has the bobber (35591) as its
  loot source, like open water (V3, spec 011).
- A cast without loot is settled as a miss 1 s after it ends, also when the next cast already started.
- The game's lines `ERR_FISH_ESCAPED` / `ERR_FISH_NOT_HOOKED` (`UI_INFO_MESSAGE` or `UI_ERROR_MESSAGE`, compared
  with the client's own strings) while the line is out or within the same 1 s after it fire `FISH_ESCAPED` (castID), once per cast: the
  answer of a hook press without a catch, which the hook sound needs (spec 013). The cast is still settled by
  `FISH_MISSED`.
- The messages are consumed by Stats.lua, UI/Toast.lua, CatchDB/Events.lua ([catch-db.md](catch-db.md)) and
  Fishing/Sound.lua ([fishing-mode.md](fishing-mode.md)), which also reads `FISH_ESCAPED`.

## Catch/Stats.lua

- Counts time in segments (fishing mode on, optionally not AFK) and flushes them on zone change and logout.
- Keeps per-session, per-zone and total buckets and bumps `Stats.GetVersion()` on every change.
- `Stats.PlaceName(mapID)` is the "Zone - Subzone" name both statistics tabs show.
- A cast that runs across a `/reload` is recognised by its channel start time (`charDB.countedCast`) and not
  counted twice.
- The item value is computed at read time through Prices.lua.

## Catch/Prices.lua

The value of an item is the higher of the vendor and the auction price. The auction price has two sources
(spec 019, [specs/019-auctionator-prices](../../specs/019-auctionator-prices/)): Auctionator's price when that addon
is in use, else the addon's own scanned price; an item Auctionator has no price for falls back to the own one.

- **The own price**: one based on fewer than 5 pieces or fewer than 3 result rows (price points; several sellers
  at one price share a row) is shown with a "few lots" mark and not used for values. The two limits are
  `Prices.FEW_PIECES` (5) and `Prices.FEW_LOTS` (3); the scan's paging rule reads them too.
- **Auctionator** (optional; `## OptionalDeps: Auctionator` in the TOC loads it first): only its public
  `Auctionator.API.v1`, every call in `pcall` with the caller name `"OneKeyFishing"`, nothing of its data kept (its
  database object can be replaced in a session). `Prices.HasAuctionator()`: both `GetAuctionPriceByItemID` and
  `RegisterForDBUpdate` are functions (read at each call, never at load) and no call failed this session.
  `Prices.UsesAuctionator()`: that, with `settings.auctionPrices` and `settings.auctionatorPrices` on.
  `Prices.GetSource()`: `"off"`, `"auctionator"` or `"own"`. Its price is the cheapest unit price of its last scan
  or search, used at any age and without the few-lots rule; a result that is not a number above 0 is no price.
- **The switches** are written only by `Prices.SetAuctionPrices(on)` and `Prices.SetAuctionator(on)`, which fire
  `SETTINGS_CHANGED` with the key when the value changed.
- **A failing call**: the first one in a session is logged once (`ns.Safe`), its message kept
  (`Prices.GetAuctionatorFailure()`), and Auctionator counts as not installed until the next login: the own scan
  and prices are back. One `PRICES_CHANGED` follows on the next frame (a price is often read in the middle of a
  redraw); no `SETTINGS_CHANGED`, since no setting changed.
- **The update notice**: one `RegisterForDBUpdate` at `PLAYER_LOGIN` (it cannot be removed). Its notices come after
  each of Auctionator's searches and at the end of its scan; while Auctionator is in use a burst of them gives one
  `PRICES_CHANGED` after 0.5 s, otherwise nothing. One more `PRICES_CHANGED` 1 s after the login covers what read
  a price before Auctionator's database was ready.
- `Prices.GetAuction(itemID)` returns the price, whether it rests on few lots, and its source (`"auctionator"` or
  `"own"`); `Prices.Get` and `Prices.FormatValue` keep their rule.
- `Prices.AddTooltipLine` adds the own price to a row's item tooltip under the addon's name ("Auction price
  (OneKeyFishing)"; grey with the mark when it rests on few lots), so it is told apart from another addon's
  cheapest-auction line. For an item priced by Auctionator it adds nothing: Auctionator's own line is on the
  tooltip (V59).
- `Prices.CanAuction(itemID)`: false for a loaded bound item (bind on pickup, quest); the scan's list and the
  counts share it. `Prices.CountSources()`: the character's own catches (`Stats.GetTotal().items`) that can be sold,
  counted by the source of their auction price: `auctionator`, `own` (also on few lots), `vendor` (no auction
  price, a vendor price), `none`; the settings page, the statistics line and the debug report show them.
- `Prices.Describe()`: the debug report's "Auction prices" section (the source, both switches, the two functions
  present or missing, a failure, the four counts, the oldest age among the catches Auctionator prices).

## Catch/Auction.lua

Rebuilt in spec 018 ([specs/018-auction-scan](../../specs/018-auction-scan/), the facts it rests on in
[forever-api.md](../forever-api.md), "The auction house's request system").

- **Not while the prices come from Auctionator** (spec 019): `Auction.WhyNot()` then answers "Prices come from
  Auctionator." first, `Auction.CanScan()` is false, and `Auction.Scan()` prints that line and sends nothing, so
  the addon sends no auction request at all.

- **The price** is unchanged: the average unit price of the cheapest 20% of all listed pieces (results sorted
  locally), stored in `prices[itemID] = { price, quantity, lots, time }`.
- **The list** (`BuildList`, at each press): the own catches (`fishedItems` and the statistics' items), then the
  bundled database's items, then the items known only from other players' records; each item once, in its first
  group. The last two come from an item source that `CatchDB/Views.lua` sets with `Auction.SetItemSource`
  (`CatchDB.ScanItems`), so the module names no layer 2 module. Left out: the items of `GameData.AuctionUnanswered` (a search for them
  jams the auction house), IDs the client does not know, bound
  items (`Prices.CanAuction`; V54, accepted; poor quality items can be listed and are searched), the remembered items and, after a remembered item of other players'
  records, that whole group. Inside a group: never scanned first, then the oldest scan time, then the ID.
- **Fresh prices**: an item answered less than 15 minutes ago (`priceScans[itemID]`, or the price's own time) is
  left out; when every item is fresh the press scans them all again. A scan stopped by a closed window therefore
  resumes with the items it did not reach.
- **The item key info first**: at the start the scan calls `C_AuctionHouse.GetItemKeyInfo` once per item
  (V56, measured) and searches an item only when it has the info; a missing one is read again only on its
  `ITEM_KEY_ITEM_INFO_RECEIVED` (a call asks the server again). Items whose info never comes end the scan after
  3 s without a scan time.
- **The turn** (`Pump`): one request at a time, only on a ready line (`IsThrottledMessageSystemReady`) and not
  sooner than 0.6 s after the scan's previous request (V57, measured; the documented 100 a minute). It runs on the
  line's events, the results, an item key info and its own timer; while the line reads busy it reads it again once
  a second (a READY event was missed once per measured scan).
- **Paging**: a further commodity page only while the price is open: the loaded pieces below the cheapest fifth of
  the listed ones, below 5 pieces or below 3 rows (V55, measured: later pages are never cheaper), up to 5 pages;
  the page request takes its turn like a search. An answered request without a result for 3 s: the loaded pages
  decide, else the item is skipped without a scan time.
- **The line and the stall**: the module follows the line while the window is open, scan or no scan. A ready
  reading counts only at `AUCTION_HOUSE_THROTTLED_SYSTEM_READY`, `..._RESPONSE_RECEIVED`, `..._DROPPED`, the
  window's opening and the reading at the end of the 10 s; `..._SENT`, `..._QUEUED` and the scan's own send mark it
  busy whatever it reads; the own send and every response restart the clock (a jam sends no response, while
  another addon's steady traffic may never let the line read ready). Busy for 10 s: the state is `"stalled"`, a
  running scan stops with one chat line and keeps its prices, `AUCTION_STATE` and `PRICES_CHANGED` fire; the next
  freeing reading ends the state. A ready line while the scan's request has no response counts as an answer without a
  result.
- **The guard**: the item of the scan's request that was unanswered when the line stalled is remembered in
  `scanGuard.items[itemID] = group`, also when the window was closed and opened again on a silent line; a late
  response forgets it. `scanGuard.version` is the addon version: another version empties the table.
- `Auction.GetState()` (`"closed"`, `"ready"`, `"scanning"`, `"stalled"`), `Auction.CanScan()` (the one "can scan
  now" rule of every entry), `Auction.WhyNot()` (the localized reason), `Auction.GetProgress()` (scanning, done,
  total), `Auction.Describe()` (the debug report's "Auction scan" lines). `AUCTION_STATE` fires on every change of
  the state and the progress.
- Never: `C_AuctionHouse.SearchForItemKeys` (never answered), `SendBrowseQuery`, `ReplicateItems`; no scan starts
  without a press.
