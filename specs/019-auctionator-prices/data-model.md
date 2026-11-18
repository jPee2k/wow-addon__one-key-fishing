# Data Model: Auctionator Prices

**Feature**: [spec.md](spec.md) | **Research**: [research.md](research.md)

## Saved data

| Field | Scope | Change | Notes |
|---|---|---|---|
| `OneKeyFishingDB.settings.auctionPrices` | account | unchanged key and value; written only by `Prices.SetAuctionPrices` | moves to the "Auction prices" page |
| `OneKeyFishingDB.settings.auctionatorPrices` | account | new, `true` by default (`ApplyDefaults`) | written only by `Prices.SetAuctionator`; an effect only with `auctionPrices` on and Auctionator usable |
| `OneKeyFishingDB.prices`, `priceScans`, `scanGuard` | account | unchanged | the own scan's data; never touched while Auctionator is in use (FR-005) |

No `DB_SCHEMA` bump, no migration: nothing is renamed, moved or reshaped. Nothing of Auctionator's is stored.

## Session state (`Catch/Prices.lua`, not saved)

| Name | Meaning |
|---|---|
| `registered` | `RegisterForDBUpdate` was called this session (once, at `PLAYER_LOGIN`) |
| `failure` | the message of the first failing Auctionator call, or nil; while set, `HasAuctionator()` is false |
| `pending` | a `PRICES_CHANGED` timer of R4 is running |

## Derived values

### Price source

```
off          settings.auctionPrices is false
auctionator  auctionPrices and auctionatorPrices and HasAuctionator()
own          otherwise (the addon's scan)
```

Changes: a setter (`SETTINGS_CHANGED`), the first failing call (`failure` set; one `PRICES_CHANGED` on the next frame, which the
windows, the scan button and the settings page follow; no `SETTINGS_CHANGED`, since no setting changed).
Auctionator cannot appear or go away in
a session (an addon loads at login).

### Auction price of an item (`Prices.GetAuction`)

| Source | Auctionator has a price > 0 | Own stored price | Result `price, fewLots, source` |
|---|---|---|---|
| off | any | any | nil |
| auctionator | yes | any | Auctionator's, false, `"auctionator"` |
| auctionator | no | yes | own, its few-lots flag, `"own"` |
| own | any | yes | own, its few-lots flag, `"own"` |
| any but off | no | no | nil |

Value (`Prices.Get`): `max(price, vendor)` when a price is there and not `fewLots`, else the vendor price (0 when
none, shown as "No price").

### Price counts (`Prices.CountSources`)

Over the distinct items of `Stats.GetTotal().items` with `Prices.CanAuction(itemID)` true:

| Count | Item |
|---|---|
| `auctionator` | `GetAuction` source `"auctionator"` |
| `own` | source `"own"`, also when that price rests on few lots (its value is then the vendor price) |
| `vendor` | no auction price, vendor price > 0 |
| `none` | neither |

`auctionator + own + vendor + none` = the number of those items (SC-005). `missing`, the number of the statistics
advice: `own + vendor + none` without the poor quality (grey) items, which nobody lists; shown only while the source
is `auctionator`.

### Item that can be sold at auction (`Prices.CanAuction`, moved from `Auction`)

False for a bind type 1 (on pickup) or 4 (quest) of a loaded item; true otherwise, also for an item the client has
not loaded yet.
