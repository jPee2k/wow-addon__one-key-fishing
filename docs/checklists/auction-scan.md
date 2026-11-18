# In-game checklist: the auction scan

**Feature**: the rebuilt price scan: the item key info first, the request line's pace, paging only while the price is
open, the catch catalog's items, fresh prices, the auction house that does not answer, the remembered items
(`specs/018-auction-scan`).
**Closes**: `V54` to `V58` of [verification.md](../../specs/018-auction-scan/verification.md); SC-001 to SC-004 of
the spec, which only the game can measure.
**Needs**: one character at an auction house; for step 4 a character with few catches; for step 8 a grey (poor
quality) item in the bags.

**Rules for every step** (the auction house jams until a relog when a request gets no answer, see
`docs/forever-api.md`): one action at a time; type nothing else into the auction house while a scan runs; no `/run`
line other than the one written below.

## Setup

1. Install the build (`npm run install-addon`), or link the working folder once (`npm run link`). The TOC gained
   `GameData/AuctionUnanswered.lua`: restart the game once after installing (a `/reload` does not load a new file).
2. Log the character out and in (not `/reload`), so the first scan meets a cold item cache.

## Steps

1. [ ] **Before the auction house**: `/okf debug`, section "Auction scan". Expected: `auction: closed`; the
   `auction guard` line says `none` and `left out: no`. Open the auction house: the button above it reads
   "Scan fish prices". ____
2. [ ] **The first scan after the login** (SC-001, V56): press "Scan fish prices"; note the time of the start line
   and of the finished line, the items and the prices. Expected: at most 1 second per item on average (before:
   4 s); `/okf debug` "Auction scan": `0 without item info`. Start ____ end ____ items ____ prices ____
3. [ ] **At once a second scan** (SC-002, V57): when step 2 answered every item, every price is fresh, so the press
   scans every item again. Expected: the same number of prices as step 2, the time close to step 2's, no "does not
   answer" line. (If step 2 left items without item info, this press scans only those: note the number.)
   Time ____ prices ____
4. [ ] **The catalog by price** (SC-003): on the character with few catches, scan, open the statistics window,
   "Catch catalog", Sort: Price. Expected: items this character never caught, which are on sale, show an auction
   price (compare one with the auction house's list). ____
5. [ ] **A stopped scan resumes** (SC-004): wait 15 minutes (or use another character's first visit), press the
   button and close the auction window halfway (the chat says "stopped"); open it and press again. Expected: the
   start line names only the items the first run did not reach. Numbers ____ / ____
6. [ ] **Fresh prices**: right after step 5 press once more: every price is fresh, so the whole list is scanned
   again (the start line names all items). ____
7. [ ] **An item with many auctions** (V55): pick a fish with many price points in the auction window. Expected:
   the price the addon shows in its tooltip or the catalog is the average of the cheapest fifth of the pieces in the
   auction window's list (a few copper of rounding at most). Item ____ addon ____ window ____
8. [ ] **A grey item** (V54): with the auction house open and a grey item in the bags, paste (without a leading
   slash in Claude Code; in game it starts with `/run`):
   `/run for b=0,4 do for s=1,C_Container.GetContainerNumSlots(b)do local i=C_Container.GetContainerItemInfo(b,s)if i and i.quality==0 then print(i.hyperlink,C_AuctionHouse.IsSellItemValid(ItemLocation:CreateFromBagAndSlot(b,s),false))return end end end`
   It sends nothing to the server. Expected: the item and `false`. Output ____
9. [ ] **The buttons agree** (FR-014): with the auction house closed, the statistics window's and the settings
   page's scan buttons are disabled, the settings page says "(open the auction house first)", the minimap menu's
   entry is disabled; open the auction house: all enabled; during a scan: disabled. ____
10. [ ] **Only if the auction house stops answering by itself**: note the chat line, the text of the button above
    the auction window and its tooltip, then log out and in and note the `auction guard` line of `/okf debug`.
    Expected: "Auction scan stopped: the auction house does not answer ..." once; the button reads "Auction house
    not answering"; after the relog the guard names the item that was being searched. ____

11. [ ] **The two unanswered fish** (V58): after the build with both lines of `GameData/AuctionUnanswered.lua`
    commented out, step 2's scan includes Winter Squid (13755) and Plated Armorfish (13890) when the list holds them.
    Expected: the scan finishes, no "does not answer" line; note whether each got a price. If it stops instead: the
    item named by `/okf debug` "Auction scan" (after a relog) goes back into the file. ____

## Results

- Date, build, client language: ____
- Problems found: ____

What happens next is in [release-plan.md](../release-plan.md).
