# Verification debt: Auction Scan

Claude cannot run the game. Most of what this feature rests on was measured by the author on 2026-11-17
([docs/forever-api.md](../../docs/forever-api.md), "The auction house's request system"). This file holds the
assumptions that were not, V54 to V58 (the IDs continue the V series; V53 was spec 016's). While open, each carried a
`-- VERIFY(<id>)` marker in the code, which `npm run check` lists and `npm run build` refuses.

All five were closed on 2026-11-18 (the Status column): three confirmed in game, one found wrong and fixed in
part, two accepted by the author without a check (listed in `docs/release-plan.md`). No marker is left in the code.

To close an item:
1. Run its step in game (`docs/checklists/auction-scan.md`), one auction request at a time, with items from catches.
2. Record the answer in `docs/forever-api.md`.
3. Adjust the code if the game differs.
4. Remove the marker and tick the item here.

| ID | Assumption we build on | Evidence before the change | If it turns out wrong | How to verify | Status |
| --- | --- | --- | --- | --- | --- |
| V54 | An item of poor quality or a bound one (bind on pickup, quest) cannot be listed at auction, so the scan leaves it out (research R5) | The retail rule; the measured scan asked for such items and found no price | A sellable item lacks its auction price and shows the vendor price: the filter is removed for that kind | `C_AuctionHouse.IsSellItemValid` on a grey item in the bags with the auction house open (the `/run` line of 2026-11-17, sends nothing to the server); a bound item the same way | Poor quality: **found wrong 2026-11-18** (`IsSellItemValid` true for the grey Snapped Spider Limb), the scan searches such items since. Bound items: **Accepted 2026-11-18** by the author without an in-game check (the game's own rule), marker removed. If wrong: a sellable bound item lacks its auction price and shows the vendor price |
| V55 | With the price sort, the commodity results come cheapest first and a later page holds no cheaper row, so the price from the first pages equals the price from all pages (research R4) | The result order was seen sorted in one page (V4); the search is sent with `Enum.AuctionHouseSortOrder.Price` | A price slightly too high for an item with many price points: paging goes back to "every page" | Checklist: an item with many auctions, the price of the scan against the auction window's list | **Confirmed 2026-11-18**: Raw Spotted Yellowtail, 4750 pieces in 48 rows, ascending from 40c to 3s 12c to the end of the list; the addon's price 40c equals the cheapest fifth of the whole list (857 at 40c, 93 at 42c). Marker removed |
| V56 | `C_AuctionHouse.GetItemKeyInfo` may be called for the whole list (about 100 items) when a scan starts, and each missing info arrives by `ITEM_KEY_ITEM_INFO_RECEIVED` without a throttled message (research R1) | 25 infos arrived during one measured scan, 0.01 s after a single call; 53 sent messages = 40 searches + 13 pages | Items end the scan "without item info" (the debug report counts them) or the house throttles: the infos are then asked in batches | Checklist: the first scan after a login; the debug report's "without item info" is 0 and the time is under 1 s per item | **Confirmed 2026-11-18**: four scans of 68 to 72 items, one request per item, "0 without item info", 0.6 to 0.65 s per item. (The item key cache survives a relog, so the first scan may have met a warm cache.) Marker removed |
| V57 | A request every 0.6 s (the documented 100 a minute) is answered like one every 0.7 s (the measured pace) for a list of about 100 items (research R2) | 40 requests at 0.7 s were all answered; the client is ready 0.5 s after a send | The house slows or stops answering late in a long scan: `MIN_INTERVAL` goes back to 0.7 | Checklist: a full scan of the whole list right after another one; every item answered, no stall | **Confirmed 2026-11-18**: scans of 68 and 72 items one after another (41 s and 47 s), every request answered, the guard empty. Marker removed |
| V58 | Plated Armorfish (13890) is answered by the rebuilt scan, like Winter Squid (13755); its line in `GameData/AuctionUnanswered.lua` is commented out for the check | Both measured unanswered 2026-11-17, the auction house jammed. Winter Squid passed on 2026-11-18: a scan of 68 items in 41 s, 54 prices, its price found, no jam; its line is removed | The auction house jams once for that player (the guard remembers the item until the next version): the line comes back | Checklist step 11: a scan whose list holds Plated Armorfish (it is not in the bundled database: an own catch or other players' records); the debug report's guard line after a relog | Winter Squid: **confirmed 2026-11-18**. Plated Armorfish: **Accepted 2026-11-18** by the author without an in-game check (it was in no scan list), marker and its commented line removed. If wrong: the auction house jams once for a player whose list holds it, the guard remembers it until the next version, and the item goes into `GameData/AuctionUnanswered.lua` |

Not assumptions, measured: the response and ready events and their times, the jam and what causes it, that an item
which exists and is not on sale is answered, that the item key info cache survives a relog.

Cannot be checked on purpose: the stall itself (it costs a relog and the known ways to cause one are forbidden to the
scan). The tests cover it with a stand-in auction house; if one happens in game, the checklist says what to note.
