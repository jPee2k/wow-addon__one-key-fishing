-- GameData/AuctionUnanswered: items the auction house never answers a search for, which jams it until the
-- character logs out and in (docs/forever-api.md, "The auction house's request system", measured 2026-11-17). The
-- auction scan never searches them (Catch/Auction.lua, specs/018-auction-scan). Data only: no logic and no L lookup.
local _, ns = ...
local GameData = ns.GameData or {}
ns.GameData = GameData

-- VERIFY(V58): the two fish measured on 2026-11-17 are searched again by the rebuilt scan; if the auction house
-- jams on one (checklist step 11), its line comes back.
GameData.AuctionUnanswered = {
    -- [13755] = true, -- Winter Squid (in the bundled catch database)
    -- [13890] = true, -- Plated Armorfish
}
