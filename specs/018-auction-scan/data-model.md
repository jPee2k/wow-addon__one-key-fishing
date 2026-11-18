# Data Model: Auction Scan

**Feature**: [spec.md](spec.md) | **Research**: [research.md](research.md)

## Saved data (`OneKeyFishingDB`, account-wide)

| Field | Shape | Written by | Read by |
|---|---|---|---|
| `prices` (unchanged) | itemID -> `{ price, quantity, lots, time }` | `Auction.lua`, when a search finds a price | `Prices.lua`, `Auction.lua` (the scan time) |
| `priceScans` (new) | itemID -> `time()` of the last answered search, with a price or not on sale | `Auction.lua` | `Auction.lua` |
| `scanGuard` (new) | `{ version = <ns.version or "">, items = { itemID -> "own", "bundled" or "shared" } }` | `Auction.lua` | `Auction.lua`, the debug report through `Auction.Describe()` |

- Both new fields are filled by `ApplyDefaults` (`priceScans = {}`, `scanGuard = { version = "", items = {} }`);
  `DB_SCHEMA` stays 1, no migration (research R9).
- `prices` keeps its shape and meaning: an entry exists only for an item a scan found on sale; a later scan that finds
  it not on sale leaves the entry (research R7).
- `scanGuard` is read through one accessor: when `version ~= ns.version`, `items` is emptied and `version` set.
- Nothing is stored per character and nothing about the auction house's state is stored (it is read from the game).

## Derived values

| Value | Rule |
|---|---|
| Scan time of an item | the later of `priceScans[itemID]` and `prices[itemID].time`; none: never scanned |
| Fresh | scan time less than `FRESH_SECONDS = 900` ago |
| Remembered item | a key of `scanGuard.items` |
| Left-out mark | some value of `scanGuard.items` is `"shared"` |
| Group of an item | `"own"`: in `db.fishedItems` or the statistics' items; else `"bundled"`: in the first set of the item source; else `"shared"`: in its second set |

## The scan list

Built at each `Auction.Scan()`:

1. Candidates: the three groups, each ID once in its first group.
2. Kept: positive whole numbers with `C_Item.GetItemInfoInstant(itemID) ~= nil`; not remembered; not unsellable
   (quality 0, bind type 1 or 4, when the game has the item's data; unknown stays); the `"shared"` group only without
   the left-out mark.
3. To search: the kept items that are not fresh; when there is none, all kept items.
4. Order: group (`own`, `bundled`, `shared`), then scan time from the oldest (never scanned first), then item ID.

## The scan in memory (one at a time, lost at a reload)

| Field | Meaning |
|---|---|
| `queue` | the ordered items not searched yet |
| `info` | itemID -> the item key info, asked once at the start and read again only on the item's event |
| `current` | the item whose request is in flight or whose result is awaited; `nil` between items |
| `wantsMore` | `current` needs its next result page, to be asked at the next turn |
| `total`, `found` | the items to search, the prices found (the chat lines and the progress) |
| `requests`, `startedAt`, `noInfo` | for the debug report: requests sent, start, items ended without item key info |
| `lastSendAt` | `GetTime()` of the scan's last request (the 0.6 s floor) |

Kept outside a scan, while the session lasts:

| Field | Meaning |
|---|---|
| `isOpen` | the auction window is open |
| `busySince` | `GetTime()` when the line was first marked busy (a not-ready reading, a SENT or QUEUED event, the scan's own send); set again by the scan's own send and by every response; `nil` after a ready reading at READY, RESPONSE_RECEIVED, DROPPED, `AUCTION_HOUSE_SHOW` or the end of the 10 s, and when closed |
| `stalled` | not ready for `ANSWER_TIMEOUT = 10` s without a break |
| `outstanding` | `{ itemID, group }` of the scan's own request without an answer; survives the scan's stop |

## States

`Auction.GetState()`:

```text
closed   --AUCTION_HOUSE_SHOW-->                      ready (or stalled after 10 s not ready); stalled again at once
                                                      when a stall was seen and the line still reads busy
ready    --Scan(), list not empty-->                  scanning
scanning --last item settled-->                       ready     chat: finished, PRICES_CHANGED
scanning --AUCTION_HOUSE_CLOSED-->                    closed    chat: stopped, PRICES_CHANGED
scanning --not ready for 10 s-->                      stalled   chat: does not answer, PRICES_CHANGED,
                                                                outstanding item remembered
ready    --not ready for 10 s (no scan)-->            stalled   no chat line
stalled  --a ready reading-->                         ready     outstanding item forgotten if its answer came
any open --AUCTION_HOUSE_CLOSED-->                    closed    busySince cleared, outstanding and stalled kept
```

`AUCTION_STATE` fires on every transition and on every step of the progress.

`"ready"` means "a scan can start", not "the line is free": it includes a line that has been busy for less than
10 s (the spec's "open and busy"); a scan started then waits for its turn.

One item inside a scan:

```text
queued --has item key info, system ready, 0.6 s since the last request--> sent (outstanding)
sent   --response event or result event-->            answered (outstanding cleared)
sent   --ready reading at READY or DROPPED, no response event--> answered without a result (outstanding cleared)
answered --result: price decided or last page-->      settled: price stored if any, priceScans set
answered --result: price open, pages left-->          wantsMore --next turn--> sent (next page)
answered --no result for RESULT_WAIT = 3 s-->         skipped: nothing stored, tried by the next scan
queued --no item key info INFO_WAIT = 3 s after the rest is done--> skipped the same way
```

## Constants (`Catch/Auction.lua`, addon tuning)

| Name | Value | From |
|---|---|---|
| `FRESH_SECONDS` | 900 | the author's decision |
| `ANSWER_TIMEOUT` | 10 | the author's decision |
| `MIN_INTERVAL` | 0.6 | the documented 100 search calls a minute (research R2) |
| `INFO_WAIT`, `RESULT_WAIT` | 3, 3 | fallbacks; the measured times are 0.01 s and 0.2 s |
| `RECHECK` | 1 | a busy line read again while a scan waits (a missed READY event) |
| `CHEAPEST_SHARE`, `MAX_MORE_REQUESTS` | 0.2, 5 | unchanged |
| `Prices.FEW_PIECES`, `Prices.FEW_LOTS` | 5, 3 | unchanged values, now fields of `ns.Prices` for the paging rule |
