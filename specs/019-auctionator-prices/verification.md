# Verification: Auctionator Prices

The code built on assumptions only the game can confirm carries `-- VERIFY(<id>): <what>`; the IDs continue the V
series (V58 was spec 018's). A marker is removed after the author confirms the behaviour in game, or when the author
accepts the assumption without a check (the row then says "Accepted" and what happens if it is wrong).

Already measured in game (2026-11-17, [docs/forever-api.md](../../docs/forever-api.md)), no marker: the API is there
in WoW Forever, `GetAuctionPriceByItemID` gives the cheapest unit price, `GetAuctionAgeByItemID` the days,
`RegisterForDBUpdate` calls back after a search and at the end of a scan.

| ID | Assumption | Basis | If wrong | Check | Status |
|---|---|---|---|---|---|
| V59 | Auctionator's price line shows on the addon's row tooltips (`GameTooltip:SetItemByID`), so the addon's own line may be left out for an item Auctionator prices (research R7) | Auctionator 347 hooks `SetItemByID` (`Source/Tooltips/Hooks.lua`) | An item priced by Auctionator shows no auction line in the addon's rows: the addon's line comes back with "(Auctionator)" | Checklist step 2: hover a caught item in the statistics window with Auctionator's tooltips on | Open |
