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

1. [x] **Before the auction house**: `/okf debug`, section "Auction scan". Expected: `auction: closed`; the
   `auction guard` line says `none` and `left out: no`. Open the auction house: the button above it reads
   "Scan fish prices". Passed 2026-11-18.
2. [x] **The first scan after the login** (SC-001, V56): press "Scan fish prices"; note the time of the start line
   and of the finished line, the items and the prices. Expected: at most 1 second per item on average (before:
   4 s); `/okf debug` "Auction scan": `0 without item info`. Start 09:23:30, end 09:24:11, 68 items, 54 prices, 0 without item info (2026-11-18).
3. [x] **At once a second scan** (SC-002, V57): when step 2 answered every item, every price is fresh, so the press
   scans every item again. Expected: the same number of prices as step 2, the time close to step 2's, no "does not
   answer" line. (If step 2 left items without item info, this press scans only those: note the number.)
   68 items, 41 s, 54 prices; later 72 items in 47 s (2026-11-18).
4. [x] **The catalog by price** (SC-003): on the character with few catches, scan, open the statistics window,
   "Catch catalog", Sort: Price. Expected: items this character never caught, which are on sale, show an auction
   price (compare one with the auction house's list). Passed 2026-11-18 on a level 1 character without Fishing.
5. [x] **A stopped scan resumes** (SC-004): wait 15 minutes (or use another character's first visit), press the
   button and close the auction window halfway (the chat says "stopped"); open it and press again. Expected: the
   start line names only the items the first run did not reach. Numbers 72 / 35 (2026-11-18).
6. [x] **Fresh prices**: right after step 5 press once more: every price is fresh, so the whole list is scanned
   again (the start line names all items). 72 again (2026-11-18).
7. [x] **An item with many auctions** (V55): pick a fish with many price points in the auction window. Expected:
   the price the addon shows in its tooltip or the catalog is the average of the cheapest fifth of the pieces in the
   auction window's list (a few copper of rounding at most). Raw Spotted Yellowtail: addon 40c, window 857 at 40c and 93 at 42c of 4750 pieces: 40c (2026-11-18).
8. [x] **A grey item** (V54): with the auction house open and a grey item in the bags, paste (without a leading
   slash in Claude Code; in game it starts with `/run`):
   `/run for b=0,4 do for s=1,C_Container.GetContainerNumSlots(b)do local i=C_Container.GetContainerItemInfo(b,s)if i and i.quality==0 then print(i.hyperlink,C_AuctionHouse.IsSellItemValid(ItemLocation:CreateFromBagAndSlot(b,s),false))return end end end`
   It sends nothing to the server. Expected: the item and `false`. Output: `[Snapped Spider Limb] true`
   (2026-11-18): a grey item can be listed, the scan searches poor quality items since.
9. [x] **The buttons agree** (FR-014): with the auction house closed, the statistics window's scan button and the
   minimap menu's entry are disabled; open the auction house: all enabled; during a scan: disabled. Passed
   2026-11-18; the settings page's button was removed after it (the settings close the auction house window).
10. [ ] **Only if the auction house stops answering by itself**: note the chat line, the text of the button above
    the auction window and its tooltip, then log out and in and note the `auction guard` line of `/okf debug`.
    Expected: "Auction scan stopped: the auction house does not answer ..." once; the button reads "Auction house
    not answering"; after the relog the guard names the item that was being searched. ____

11. [ ] **Plated Armorfish** (V58, accepted without this check, to confirm in play; Winter Squid passed on 2026-11-18: 68 items in 41 s, 54 prices, no jam): a scan
    whose list holds Plated Armorfish (13890; not in the bundled database, so an own catch or other players'
    records). Expected: the scan finishes, no "does not answer" line. If it stops instead: the item named by
    `/okf debug` "Auction scan" (after a relog) goes back into `GameData/AuctionUnanswered.lua`. ____

## Results

- Date, build, client language: ____
- Problems found: ____

What happens next is in [release-plan.md](../release-plan.md).
