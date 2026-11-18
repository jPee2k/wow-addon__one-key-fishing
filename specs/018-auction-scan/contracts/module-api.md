# Contract: Auction Scan

**Feature**: [../spec.md](../spec.md) | **Data model**: [../data-model.md](../data-model.md) |
**Research**: [../research.md](../research.md)

## `Catch/Auction.lua` (layer 1)

| Function | Contract |
|---|---|
| `Auction.IsOpen()` | unchanged: the auction window is open |
| `Auction.GetState()` | new: `"closed"`, `"ready"` (a scan can start; the line may be busy for less than 10 s), `"scanning"` or `"stalled"` (data-model.md "States") |
| `Auction.CanScan()` | the one "can scan now" rule: `GetState() == "ready"` (today: open and no scan running) |
| `Auction.WhyNot()` | new: the localized reason a scan cannot start, looked up when called: closed -> `Open the auction house first.`; stalled -> text 2 below; `nil` when ready or scanning |
| `Auction.GetProgress()` | unchanged: scanning, items done, items in all (of this scan's list) |
| `Auction.Scan()` | starts a scan when `CanScan()`; otherwise prints `WhyNot()` (nothing while scanning); with an empty list prints `Nothing to scan yet: catch some fish first.`; prints the present start line with the number of items it will search |
| `Auction.SetItemSource(fn)` | new: `fn()` returns two sets (itemID -> true): the bundled database's items and the items of other players' records; called by the scan at its start, through `ns.Safe`; without a source the list is the own catches |
| `Auction.GetCoverage()` | unchanged: pieces loaded and listed of the last result |
| `Auction.Describe()` | new: the lines of the debug report (below), English, not localized |

Uses at runtime: `ns.Stats.GetTotal()` and `ns.Prices.FEW_PIECES` / `FEW_LOTS` (layer 1), `ns.Print`, `ns.Fire`,
`ns.RegisterEvent`, `ns.Safe`, `ns.version` (layer 0). Names no module of layer 2 or 3.

Guarantees:

- One request at a time; a request goes out only while `C_AuctionHouse.IsThrottledMessageSystemReady()` is true and
  not sooner than 0.6 s after the scan's previous one (search or next page).
- Never calls `C_AuctionHouse.SearchForItemKeys`, `SendBrowseQuery` or `ReplicateItems`.
- Searches an item only after `C_AuctionHouse.GetItemKeyInfo` returned its info; asks for an item's info once per
  scan and again only on that item's `ITEM_KEY_ITEM_INFO_RECEIVED`.
- Never waits on a ready line: a request the line took back without a response is skipped after 3 s.
- Starts only from `Auction.Scan()`: no event starts a scan.
- After a stall or a closed window it sends nothing until the next `Auction.Scan()`.
- A price is written exactly as today (`{ price, quantity, lots, time }`, the cheapest fifth of the listed pieces).

### Game API (new to the addon, all inside `C_AuctionHouse`, already in `.luacheckrc`)

| Call or event | Use |
|---|---|
| `GetItemKeyInfo(itemKey)` | item key info before a search; `nil` asks the server |
| `ITEM_KEY_ITEM_INFO_RECEIVED` (itemID) | the info arrived |
| `AUCTION_HOUSE_THROTTLED_SYSTEM_READY`, `AUCTION_HOUSE_THROTTLED_MESSAGE_SENT`, `..._RESPONSE_RECEIVED`, `..._QUEUED`, `..._DROPPED` | `SYSTEM_READY`, `RESPONSE_RECEIVED` and `DROPPED` re-read the ready state (a ready reading frees the line) and run the scan's turn; `SENT` and `QUEUED` only mark the line busy, whatever it reads; the response clears `outstanding` |
| `C_Item.GetItemInfo(itemID)` values 3 and 14 | quality and bind type for the unsellable filter (the call is in use for the vendor price) |

Already in use and kept: `SendSearchQuery`, `MakeItemKey`, `IsThrottledMessageSystemReady`,
`GetNumCommoditySearchResults`, `GetCommoditySearchResultInfo`, `GetCommoditySearchResultsQuantity`,
`HasFullCommoditySearchResults`, `RequestMoreCommoditySearchResults`, `GetNumItemSearchResults`,
`GetItemSearchResultInfo`, the three result events, `AUCTION_HOUSE_SHOW`, `AUCTION_HOUSE_CLOSED`.

### `Auction.Describe()`: the debug report's lines

```text
auction: <state>; last scan: <searched> item(s), <requests> request(s), <seconds> s, <found> price(s), <noInfo> without item info
auction list: <own> own, <bundled> bundled, <shared> shared, <unsellable> not sellable, <fresh> fresh
auction guard (<version>): <itemID>=<group>, ... | none; other players' items left out: yes | no
last price scan: <loaded> of <listed> listed pieces loaded        (the present line, moved here)
```

Item IDs and counts only, no item name.

## `Catch/Prices.lua` (layer 1)

- `Prices.FEW_PIECES = 5`, `Prices.FEW_LOTS = 3`: the present local values as fields, read by the paging rule.
- Every function unchanged. `Prices.GetLastScanTime()` keeps reading `prices` (the newest price found).

## `CatchDB/Views.lua` (layer 2)

| Function | Contract |
|---|---|
| `CatchDB.ScanItems()` | new: returns the seed's items and, while sharing is on (`ns.Share.IsEnabled()`), the items of the counted records of other players (the cells of `P.Others()`) that the catalog shows: one the own catch has, or one 3 other contributions report on one map; two sets itemID -> true, the caller does not write them; without sharing the second set is empty |

At file load: `ns.Auction.SetItemSource(CatchDB.ScanItems)` (`Catch/Auction.lua` is earlier in the TOC).

## `Core/Core.lua`, `Core/Debug.lua`, `Core/Commands.lua` (layer 0, entries)

- `DB_DEFAULTS`: `priceScans = {}`, `scanGuard = { version = "", items = {} }`; `DB_SCHEMA` unchanged.
- `Debug.lua`: the "Catch database" section's coverage line is replaced by the lines of `ns.Auction.Describe()` in a
  section "Auction scan".
- `Commands.lua`: `/okf scan` keeps calling `ns.Auction.Scan()`; its description becomes
  `scan auction prices of the catch catalog's items (auction house must be open)`.

## `UI/` (layer 3)

| File | Contract |
|---|---|
| `UI/Widgets.lua` `ns.UpdateScanButton(button, hint)` | enabled = `Auction.CanScan()`; the reason `Auction.WhyNot()` is shown as the button's tooltip on hover, also while disabled; the hint (settings page) shows `(open the auction house first)` while closed, text 2 while stalled, and is hidden otherwise |
| `UI/AuctionButton.lua` | text by state: `Scan fish prices` (ready, enabled), `Scanning %d/%d` (disabled), text 3 (stalled, disabled, tooltip text 2); wide enough for the longest of the three |
| `UI/StatsFrame.lua`, `UI/Settings.lua` | call `ns.UpdateScanButton` on `AUCTION_STATE` as today; their buttons keep the text `Scan auction prices` |
| `UI/Minimap.lua` | the menu entry: `Scan auction prices`, disabled unless `CanScan()`; while stalled it reads text 3 |

No frame is named by a lower layer; the UI reads `GetState`, `CanScan`, `WhyNot`, `GetProgress` and follows
`AUCTION_STATE`.

## Messages, commands, saved data

- No new message. `AUCTION_STATE` now also fires when the state becomes or stops being `"stalled"`;
  `PRICES_CHANGED` also when a scan stops because of a stall.
- No new slash command; `/okf scan` gets a new description (the manual's command table follows).
- Two new saved fields (data-model.md).

## Texts (`Locales/enUS.lua`, nine translations each)

| # | Key | Where |
|---|---|---|
| 1 | `Auction scan stopped: the auction house does not answer (%d of %d price(s) found). Log out and back in.` | chat, once, when a scan stops on a stall |
| 2 | `The auction house does not answer. Log out and back in to bring it back.` | `/okf scan`, the buttons' tooltip, the settings hint |
| 3 | `Auction house not answering` | the button above the auction window, the minimap entry |

Kept: the five present scan lines, `Scan fish prices`, `Scanning %d/%d`, `Scan auction prices`,
`(open the auction house first)`.
