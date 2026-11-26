-- GameData/ZoneFactions: the faction whose territory a zone map is, for the best places' Safe for me
-- (specs/026-safe-faction). No client API gives an arbitrary zone's territory (C_PvP.GetZonePVPInfo answers only for
-- the zone the player stands in), so the table holds the game's own data: AreaTable.FactionGroupMask (2 Alliance,
-- 4 Horde, 0 contested) of each map's area through UiMapAssignment, wago.tools product wowf, build 1.60.1.71037. A map
-- not listed takes the faction of its first listed parent map (a cave inside a zone); one under no listed map is
-- contested (Forever's new zones too). The values are UnitFactionGroup's untranslated tags. Data only: no logic and no
-- L lookup.
local _, ns = ...
local GameData = ns.GameData or {}
ns.GameData = GameData

GameData.ZoneFactions = {
    -- UiMap ID = "Alliance" | "Horde"
    -- Alliance
    [1429] = "Alliance", -- Elwynn Forest
    [1436] = "Alliance", -- Westfall
    [1426] = "Alliance", -- Dun Morogh
    [1432] = "Alliance", -- Loch Modan
    [1438] = "Alliance", -- Teldrassil
    [1439] = "Alliance", -- Darkshore
    [1453] = "Alliance", -- Stormwind City
    [1455] = "Alliance", -- Ironforge
    [1457] = "Alliance", -- Darnassus
    -- Horde
    [1411] = "Horde", -- Durotar
    [1412] = "Horde", -- Mulgore
    [1413] = "Horde", -- The Barrens
    [1420] = "Horde", -- Tirisfal Glades
    [1421] = "Horde", -- Silverpine Forest
    [1454] = "Horde", -- Orgrimmar
    [1456] = "Horde", -- Thunder Bluff
    [1458] = "Horde", -- Undercity
}
