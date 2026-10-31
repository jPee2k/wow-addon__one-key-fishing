# Architecture: catches, statistics and prices

How casts become catch messages, how they are counted, and how items are valued.

## Catch/Catch.lua

- Turns casts and loot into `FISH_CAUGHT` / `FISH_MISSED` messages.
- `FISH_CAUGHT` also says whether the loot came from a fishing pool: `ns.IsPoolLoot()`, a loot source GUID of a
  game object other than the bobber 35591.
- A cast without loot is settled as a miss 1 s after it ends, also when the next cast already started.
- The messages are consumed by Stats.lua, UI/Toast.lua and CatchDB.lua ([catch-db.md](catch-db.md)).

## Catch/Stats.lua

- Counts time in segments (fishing mode on, optionally not AFK) and flushes them on zone change and logout.
- Keeps per-session, per-zone and total buckets and bumps `Stats.GetVersion()` on every change.
- `Stats.PlaceName(mapID)` is the "Zone - Subzone" name both statistics tabs show.
- A cast that runs across a `/reload` is recognised by its channel start time (`charDB.countedCast`) and not
  counted twice.
- The item value is computed at read time through Prices.lua.

## Catch/Prices.lua

The value of an item is the higher of the vendor and the scanned auction price. An auction price based on fewer
than 5 pieces or fewer than 3 result rows (price points; several sellers at one price share a row) is shown with a
"few lots" mark and not used for values.

## Catch/Auction.lua

- Runs one `C_AuctionHouse.SendSearchQuery` at a time and stores the average unit price of the cheapest 20% of
  all listed pieces (results sorted locally).
- While the game reports more commodity results it asks for the next page, up to 5, each with its own wait and
  only when the server takes requests; later pages arrive as `COMMODITY_SEARCH_RESULTS_ADDED`; at a timeout the
  pages that came decide.
- Throttle retry and timeout.
- `Auction.CanScan()` is the one "can scan now" rule for every scan button; `Auction.GetProgress()` (scanning,
  done, total) and `AUCTION_STATE` feed the button above the auction house window (`UI/AuctionButton.lua`).
