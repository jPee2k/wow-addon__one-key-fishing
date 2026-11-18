# Contract: Auctionator Prices

**Feature**: [../spec.md](../spec.md) | **Data model**: [../data-model.md](../data-model.md) |
**Research**: [../research.md](../research.md)

## `Catch/Prices.lua` (layer 1)

| Function | Contract |
|---|---|
| `Prices.HasAuctionator()` | new: Auctionator's two functions are there and no call failed this session (R2, R5) |
| `Prices.GetAuctionatorFailure()` | new: the message of the first failing Auctionator call this session, or nil |
| `Prices.UsesAuctionator()` | new: `auctionPrices` and `auctionatorPrices` on and `HasAuctionator()` |
| `Prices.GetSource()` | new: `"off"`, `"auctionator"` or `"own"` (data-model.md) |
| `Prices.GetAuction(itemID)` | `price, fewLots, source` (third value new; data-model.md table); the first two as today |
| `Prices.Get(itemID)` | unchanged rule: `max(price, vendor)` unless `fewLots`, else vendor |
| `Prices.FormatValue(itemID, count)` | unchanged |
| `Prices.AddTooltipLine(tooltip, itemID)` | no line when the source of the item's price is `"auctionator"`; else as today |
| `Prices.GetLastScanTime()` | unchanged (the own scan's time) |
| `Prices.CanAuction(itemID)` | new (moved from `Auction`): false for a loaded bound item |
| `Prices.CountSources()` | new: `{ auctionator, own, vendor, none }` over the own sellable catches |
| `Prices.SetAuctionPrices(on)` | new: the one writer of `settings.auctionPrices`; fires `SETTINGS_CHANGED("auctionPrices")` when it changed |
| `Prices.SetAuctionator(on)` | new: the one writer of `settings.auctionatorPrices`; fires `SETTINGS_CHANGED("auctionatorPrices")` when it changed |
| `Prices.Describe()` | new: the debug report's lines, English (R12) |

Guarantees:

- Every call to `Auctionator.API.v1` is inside `pcall` and passes `"OneKeyFishing"` and a number; the first failure
  is logged once and turns Auctionator off for the session (R5).
- Nothing of Auctionator's is kept between calls; no Auctionator call while the files load.
- `RegisterForDBUpdate` is called at most once per session. Its notices give at most one `PRICES_CHANGED` per 0.5 s
  and none while `UsesAuctionator()` is false.
- No auction request is sent by `Prices`.

Uses at runtime: `ns.Stats.GetTotal()` (layer 1), `ns.Fire`, `ns.RegisterEvent`, `ns.Safe`, `ns.db` (layer 0),
`C_Item.GetItemInfo`, `C_Timer.After`, the global `Auctionator`.

## `Catch/Auction.lua` (layer 1)

| Function | Change |
|---|---|
| `Auction.WhyNot()` | first: `L["Prices come from Auctionator."]` while `Prices.UsesAuctionator()` |
| `Auction.CanScan()` | false while `Prices.UsesAuctionator()` (through `WhyNot`) |
| `Auction.Scan()` | prints `WhyNot()` and sends nothing while Auctionator is in use (unchanged code path) |
| the list | uses `Prices.CanAuction` instead of its local `Unsellable` |

`GetState()` keeps `closed` / `ready` / `scanning` / `stalled`.

## Messages

No new message. `PRICES_CHANGED` also comes from Auctionator's notices (R4) and, on the next frame, after the first failing call (which
fires no `SETTINGS_CHANGED`);
`SETTINGS_CHANGED` with the keys `"auctionPrices"` and `"auctionatorPrices"`.

## UI (layer 3)

| File | Change |
|---|---|
| `UI/AuctionButton.lua` | hidden while `Prices.UsesAuctionator()`; follows `SETTINGS_CHANGED` and `PRICES_CHANGED` as well |
| `UI/StatsFrame.lua` | `frame.scan` hidden while Auctionator is in use; the values line of R11 |
| `UI/Minimap.lua` | no scan entry while Auctionator is in use |
| `UI/Settings.lua` | the "Auction prices" page (R10); `auctionPrices` leaves the main page |
| `UI/Widgets.lua` | unchanged (`ShowItemTooltip` calls `Prices.AddTooltipLine`) |

## Core

| File | Change |
|---|---|
| `Core/Core.lua` | default `auctionatorPrices = true` |
| `Core/Debug.lua` | the section "Auction prices" from `Prices.Describe()`, before "Auction scan" |
| `Core/Commands.lua` | the description of `scan` mentions Auctionator ("...; not while prices come from Auctionator") |
| `OneKeyFishing.toc` | `## OptionalDeps: Auctionator` |
| `.luacheckrc` | `Auctionator` in `read_globals` |

## Auctionator's public API used (`Auctionator.API.v1`)

| Call | Use |
|---|---|
| `GetAuctionPriceByItemID(callerID, itemID)` | the price (R3) |
| `GetAuctionAgeByItemID(callerID, itemID)` | the oldest age in the debug report (R12) |
| `RegisterForDBUpdate(callerID, callback)` | the update notice (R4) |
