# In-game checklist: Auctionator prices

**Feature**: Auctionator as the source of auction prices: catch values from its prices, the addon's scan entries
hidden, the "Auction prices" settings page, the statistics line, the debug report's section
(`specs/019-auctionator-prices`).
**Closes**: `V59` of [verification.md](../../specs/019-auctionator-prices/verification.md); SC-001 to SC-003 of the
spec, which only the game can show.
**Needs**: Auctionator 347 or later, enabled; one character at an auction house with a few caught fish in its
statistics; for step 9 a second character with Auctionator disabled (the addon list of the character screen), or
Auctionator disabled for the same character and a relog.

**Rules for every step**: the addon sends no auction request in this checklist while Auctionator's prices are in
use; the scans here are Auctionator's own. No `/run` line is needed. In step 8, where the addon's own scan is back,
the rules of [auction-scan.md](auction-scan.md) hold: one action at a time, nothing else typed into the auction
house while the scan runs.

## Setup

1. Install the build (`npm run install-addon`), or link the working folder once (`npm run link`). The TOC gained
   `## OptionalDeps: Auctionator`: restart the game once after installing (a `/reload` does not read a TOC change).
2. Log in on the character with catches; Auctionator enabled.

## Steps

1. [ ] **Before any scan**: `/okf debug`, section "Auction prices". Expected: `source auctionator`,
   `auctionPrices on, auctionatorPrices on`, `GetAuctionPriceByItemID present`, `RegisterForDBUpdate present`, a
   line `own catches: ...` (FR-022). Paste the section: ____
2. [ ] **The scan entries are gone** (FR-011, SC-002): open the auction house. Expected: no "Scan fish prices"
   button above it; the statistics window has no "Scan auction prices" button; the minimap button's right-click
   menu has no scan entry.
3. [ ] **The command** (FR-012): type `/okf scan`. Expected: one chat line "Prices come from Auctionator." and
   nothing else; the auction house keeps working.
4. [ ] **Values after Auctionator's scan** (SC-001): open the statistics window next to the auction house, note
   the value of one caught fish (____), run Auctionator's full scan (its Scan button). Expected: within about a
   second of the scan's end the values in the statistics window change to Auctionator's prices, without a press in
   OneKeyFishing and without a reload; a fish cheaper at auction than at a vendor shows the vendor price (FR-002).
   Value after: ____
5. [ ] **The statistics line** (FR-020): under the skill line. Expected: "Values: higher of vendor and Auctionator
   price"; when some catches have no Auctionator price, their number and the advice to run its scan; nothing about
   it in chat; the line stays inside the window (two lines at most) and does not run under the **Pin** button.
   The line: ____
6. [ ] **The row tooltip** (V59, FR-014): in the statistics window hover a caught fish Auctionator has a price for
   (Auctionator's tooltips on, as it ships). Expected: Auctionator's own auction line is in the tooltip and there
   is no "Auction price (OneKeyFishing)" line. Hover a catch Auctionator never saw that the addon scanned before
   (if there is one): the "Auction price (OneKeyFishing)" line is there. Seen: ____
7. [ ] **The settings page** (FR-015 to FR-018): Options, AddOns, OneKeyFishing, "Auction prices". Expected: "Use
   scanned auction prices for catch value" is here and no longer on the main page; under it, indented, "Take prices
   from Auctionator", ticked and usable; the line "Prices come from Auctionator."; the counts line "Your catches:
   ..." with the numbers of step 1; no scan button. Untick the first checkbox: the second turns grey and the line
   says auction prices are off; tick it again. The counts line: ____
8. [ ] **Back to the addon's own scan** (SC-003): untick "Take prices from Auctionator", close the settings.
   Expected: the statistics window's scan button and the minimap menu's scan entry are back at once and the values
   are the addon's own stored prices again; open the auction house: "Scan fish prices" is above it and a press
   scans as in 1.3.2. Tick the checkbox again afterwards: the entries go away again.
9. [ ] **Without Auctionator** (SC-006): log in on a character with Auctionator disabled. Expected: the "Auction
   prices" page shows "Take prices from Auctionator" grey with the note "Auctionator is not installed." and names
   the addon's own scan as the source; the scan buttons and `/okf scan` work as in 1.3.2; `/okf debug` "Auction
   prices": `source own scan`, both functions `missing`.

## Results

- Date, build, client language, Auctionator's version: ____
- Problems found: ____

What the checklist confirms goes into `docs/forever-api.md`; V59 is closed in
[verification.md](../../specs/019-auctionator-prices/verification.md) and its marker removed from
`Catch/Prices.lua`.
