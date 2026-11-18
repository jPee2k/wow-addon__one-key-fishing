# Quickstart: Auction Scan

**Feature**: [spec.md](spec.md) | **Contracts**: [contracts/module-api.md](contracts/module-api.md) |
**Data model**: [data-model.md](data-model.md)

What the automated checks prove, and what the author looks at in game.

## Prerequisites

- Node.js 18+, `npm install` once.
- Branch `018-auction-scan`.

## Automated

```text
npm run check
npm test
```

The tests drive a stand-in auction house in `tests/wow.lua`: a request line that is ready or not, requests that are
answered by a helper (response, result, ready) or left unanswered, item key info that is there or arrives by event,
and the clock (`advance`).

| Test file | Proves |
|---|---|
| `tests/catch/auction_price_test.lua` (kept, the paging cases rewritten) | FR-005: the price rule and "few lots" are unchanged; a price of 1.0.0 still reads |
| `tests/catch/auction_pace_test.lua` (new) | FR-001: no search before the item key info, a late info is searched when it arrives, a missing one ends the scan after the wait without a scan time. FR-002, FR-015: no request while the line is not ready, none sooner than 0.6 s after the last, one at a time. FR-003: no further page once the price is decided, the next page through the turn, price and mark equal to every page loaded (cases: many pieces, fewer than 5 pieces, fewer than 3 rows, the page limit). FR-004: poor and bound items are not searched, an item without loaded data is. US1 scenario 5: the progress. FR-021: opening the auction house sends nothing |
| `tests/catch/auction_list_test.lua` (new) | FR-006 to FR-008: the three groups in order, each item once in its first group, unknown IDs and non-numbers left out, no item source. FR-007: never scanned first, then the oldest. FR-010, FR-011: fresh items skipped, all fresh scans all, an item not on sale is fresh and keeps its earlier price. FR-012: the numbers in the chat lines. SC-004: a scan stopped by closing the window resumes with the rest |
| `tests/catch/auction_stall_test.lua` (new) | FR-013: 10 s without an answer stops the scan, one chat line, no further request, the prices kept, `PRICES_CHANGED`. FR-014: `GetState`, `CanScan`, `WhyNot` while stalled and after the line is ready again; a stall without a scan. FR-016: closing the window is not a stall; an unanswered request across a close is remembered when the reopened house stays not ready. FR-017 to FR-019: the item remembered and not asked again, forgotten by a late answer, the shared group left out after a shared item, own and bundled keep their group, a new version empties the memory. FR-020: `Auction.Describe()` |
| `tests/catchdb/scan_items_test.lua` (new) | `CatchDB.ScanItems()`: the seed's items; other players' items only with sharing on; the own frozen records are not "other" |
| `tests/ui/scan_buttons_test.lua` (new) | FR-014: the button above the auction window by state, `ns.UpdateScanButton` (enabled, hint, tooltip), the minimap entry, `/okf scan` printing the reason |
| `tests/core/migrations_test.lua` (extended) | the two new fields appear by default, `prices` of earlier versions is untouched, the schema stays 1 |
| `tests/core/` locale tests (present) | FR-022, SC-008: the three new keys in all nine translations |

Each new test fails when its change is taken out.

## In game

`docs/checklists/auction-scan.md` (one character at an auction house; every step one action, items from catches
only):

1. Right after a login: `/okf debug` shows the auction state "closed"; open the auction house, the button reads
   "Scan fish prices".
2. The first scan: note the seconds, the items and the prices from the two chat lines (SC-001: at most 1 s per item;
   V56: the debug report's "without item info" is 0).
3. Scan again at once (every price is fresh, so everything is scanned again): the same number of prices (SC-002);
   every item answered, no stall (V57).
4. Open the catalog ordered by price: items never caught by this character show auction prices (SC-003).
5. Start a scan and close the auction window halfway; open it and scan: the start line names only the rest (SC-004).
6. Wait 15 minutes without a scan, then scan: the start line names the whole list again.
7. An item with many auctions: its scanned price against the cheapest rows of the auction window (V55).
8. A grey item in the bags: the `/run` line of `verification.md` (V54).
9. The buttons: the statistics window and the minimap menu follow the same state as the button above the auction
   window; with the window closed the reason is "Open the auction house first."
10. Only if the auction house stops answering by itself: note the chat line, the buttons' text, and after the relog
    the "auction guard" line of `/okf debug`.
