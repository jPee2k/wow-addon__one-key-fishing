# Verification debt: Auction Scan

Claude cannot run the game. Most of what this feature rests on was measured by the author on 2026-11-17
([docs/forever-api.md](../../docs/forever-api.md), "The auction house's request system"). This file holds the four
assumptions that were not: the IDs continue the V series (V53 was spec 016's). The code will carry
`-- VERIFY(V54): ...` to `-- VERIFY(V57): ...`; `npm run check` lists them, and `npm run build` refuses to package
while one is open (unless the author releases with `--force`, `docs/publishing.md`).

To close an item:
1. Run its step in game (`docs/checklists/auction-scan.md`), one auction request at a time, with items from catches.
2. Record the answer in `docs/forever-api.md`.
3. Adjust the code if the game differs.
4. Remove the marker and tick the item here.

| ID | Assumption we build on | Evidence before the change | If it turns out wrong | How to verify | Status |
| --- | --- | --- | --- | --- | --- |
| V54 | An item of poor quality or a bound one (bind on pickup, quest) cannot be listed at auction, so the scan leaves it out (research R5) | The retail rule; the measured scan asked for such items and found no price | A sellable item lacks its auction price and shows the vendor price: the filter is removed for that kind | `C_AuctionHouse.IsSellItemValid` on a grey item in the bags with the auction house open (the `/run` line of 2026-11-17, sends nothing to the server); a bound item the same way | Open |
| V55 | With the price sort, the commodity results come cheapest first and a later page holds no cheaper row, so the price from the first pages equals the price from all pages (research R4) | The result order was seen sorted in one page (V4); the search is sent with `Enum.AuctionHouseSortOrder.Price` | A price slightly too high for an item with many price points: paging goes back to "every page" | Checklist: an item with many auctions, the price of the scan against the auction window's list | Open |
| V56 | `C_AuctionHouse.GetItemKeyInfo` may be called for the whole list (about 100 items) when a scan starts, and each missing info arrives by `ITEM_KEY_ITEM_INFO_RECEIVED` without a throttled message (research R1) | 25 infos arrived during one measured scan, 0.01 s after a single call; 53 sent messages = 40 searches + 13 pages | Items end the scan "without item info" (the debug report counts them) or the house throttles: the infos are then asked in batches | Checklist: the first scan after a login; the debug report's "without item info" is 0 and the time is under 1 s per item | Open |
| V57 | A request every 0.6 s (the documented 100 a minute) is answered like one every 0.7 s (the measured pace) for a list of about 100 items (research R2) | 40 requests at 0.7 s were all answered; the client is ready 0.5 s after a send | The house slows or stops answering late in a long scan: `MIN_INTERVAL` goes back to 0.7 | Checklist: a full scan of the whole list right after another one; every item answered, no stall | Open |
| V58 | Winter Squid (13755) and Plated Armorfish (13890) are answered by the rebuilt scan, which waits for the item key info and sends one request at a time; their lines in `GameData/AuctionUnanswered.lua` are commented out for the check | Measured 2026-11-17 unanswered, the auction house jammed; but the bundled database holds 85 real catches of Winter Squid | The auction house jams once for that player (the guard remembers the item until the next version): the line comes back | Checklist step 11: a full scan with both fish in the list; the debug report's guard line after a relog | Open |

Not assumptions, measured: the response and ready events and their times, the jam and what causes it, that an item
which exists and is not on sale is answered, that the item key info cache survives a relog.

Cannot be checked on purpose: the stall itself (it costs a relog and the known ways to cause one are forbidden to the
scan). The tests cover it with a stand-in auction house; if one happens in game, the checklist says what to note.
