-- GameData/CampBonuses: the camp bonuses, the fishing buffs of a camp feature placed by a campfire
-- (docs/architecture/game-data.md, specs/020-camp-buffs data-model.md). Data only: no logic and no L lookup.
-- In rank order (a later entry is the higher bonus). key: the bonus's name in filters and code; bit: its bit in a
-- cast's mask (the next bonus takes 4); aura: the player aura's spell ID; item: the camp feature's item ID (the tag's
-- icon); items: the known bonus items (item ID -> true). Source: the client's game data and the in-game session of
-- 2026-11-19 (docs/fishing-investigation.md).
local _, ns = ...
local GameData = ns.GameData or {}
ns.GameData = GameData

GameData.CampBonuses = {
    {
        key = "rack", bit = 1, aura = 1280341, item = 279965, -- Fishing Rack, aura "Uncommon Fishing"
        -- VERIFY(V61): Bloated fish come only under a camp buff
        items = {
            [6643] = true, -- Bloated Brilliant Smallfish
            [6644] = true, -- Bloated Mackerel
            [6645] = true, -- Bloated Mud Snapper
            [6646] = true, -- Bloated Albacore
            [6647] = true, -- Bloated Bristle Whisker Catfish
            [8366] = true, -- Bloated Mithril Head Trout
            [13881] = true, -- Bloated Redgill
            [13891] = true, -- Bloated Whitescale Salmon
            [21162] = true, -- Bloated Oily Blackmouth
            [21163] = true, -- Bloated Firefin Snapper
            [21164] = true, -- Bloated Rockscale Cod
            [21243] = true, -- Bloated Glossy Mightfish
        },
    },
    { key = "hut", bit = 2, aura = 1280342, item = 279966, items = {} }, -- Fishing Hut, aura "Rare Fishing"
}
