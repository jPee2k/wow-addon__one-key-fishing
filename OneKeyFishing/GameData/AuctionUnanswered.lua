-- GameData/AuctionUnanswered: items the auction house never answers a search for, which jams it until the
-- character logs out and in (docs/forever-api.md, "The auction house's request system"). The auction scan never
-- searches them (Catch/Auction.lua, specs/018-auction-scan). Empty today: Winter Squid (13755), measured unanswered
-- on 2026-11-17, was answered with a price by the rebuilt scan on 2026-11-18. Data only: no logic and no L lookup.
local _, ns = ...
local GameData = ns.GameData or {}
ns.GameData = GameData

-- Plated Armorfish (13890), measured unanswered on 2026-11-17 like Winter Squid, was answered too (V58, 2026-11-18,
-- the release build's scan with the bundled data of epoch 5). An item the auction house jams on goes in here.
GameData.AuctionUnanswered = {}
