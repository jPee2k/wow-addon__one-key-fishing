# Quickstart: Auctionator Prices

**Feature**: [spec.md](spec.md) | **Contract**: [contracts/module-api.md](contracts/module-api.md)

## Automated

```
npm run check
npm test
```

What the tests prove (each fails without its change):

| Test | Proves |
|---|---|
| `tests/catch/prices_auctionator_test.lua` | Auctionator's price is used when it has one, the own price (with few lots) when not, the vendor floor; both functions needed; a switch off gives the own source or none; the first failing call is logged once and turns Auctionator off (FR-001 to FR-005, FR-007 to FR-009) |
| `tests/catch/prices_counts_test.lua` | the four counts over the own catches, bound items left out, the sum (FR-019, SC-005) |
| `tests/catch/prices_update_test.lua` | a burst of notices gives one `PRICES_CHANGED`; none with the switch off; one registration (FR-006) |
| `tests/ui/scan_buttons_test.lua` (extended) | the three entries hidden and the command's answer while Auctionator is in use, no request sent; back when the switch is off (FR-011, FR-012, SC-002, SC-003) |
| `tests/ui/auction_page_test.lua` | the page's switches, their inactive states, the note, the status line and the counts; `auctionPrices` gone from the main page (FR-015 to FR-018) |
| `tests/ui/stats_window_test.lua` (extended) | the values line and the advice with the missing count (FR-020) |
| `tests/ui/tooltips_test.lua` (extended) | no own line for an Auctionator price, the own line for the fallback (FR-014) |
| `tests/core/report_sections_test.lua` (extended) | the "Auction prices" section (FR-022) |
| `tests/core/migrations_test.lua` (extended) | the default of `auctionatorPrices` |

## In game

The checklist `docs/checklists/auctionator-prices.md` (made with the tasks), in short:

1. With Auctionator: run its full scan; the statistics values follow without a reload; the scan buttons are gone;
   `/okf scan` answers with one line.
2. A row tooltip in the statistics window: Auctionator's line, no addon line (V59); an item Auctionator never saw:
   the addon's line.
3. The "Auction prices" page: switches, the status line and the counts; turn the Auctionator switch off: the scan
   button over the auction house is back.
4. `/okf debug`: the "Auction prices" section.
5. A character with Auctionator disabled: the page says it is not installed, the scan works as in 1.3.2.
