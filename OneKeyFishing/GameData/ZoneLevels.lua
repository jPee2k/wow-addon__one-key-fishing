-- GameData/ZoneLevels: the level range of each zone map, for the best places' Safe for me and Level column
-- (specs/024-best-places). Forever's client has none: C_Map.GetMapLevels gives 0 for every zone (seen 2026-11-23),
-- UiMap.ContentTuningID and AreaTable.ExplorationLevel are 0 too. The ranges are those of LibTouristClassicEra (as
-- bundled with the FishingForever addon), which match the 35-45 the game's map showed for Riverglades. The capitals
-- and Moonglade, safe at any level, read 1-60. Data only: no logic and no L lookup.
local _, ns = ...
local GameData = ns.GameData or {}
ns.GameData = GameData

GameData.ZoneLevels = {
    -- UiMap ID = { lowest, highest }
    -- Kalimdor
    [1411] = { 1, 12 }, -- Durotar
    [1412] = { 1, 12 }, -- Mulgore
    [1413] = { 10, 25 }, -- The Barrens
    [1438] = { 1, 12 }, -- Teldrassil
    [1439] = { 10, 20 }, -- Darkshore
    [1440] = { 15, 30 }, -- Ashenvale
    [1441] = { 25, 35 }, -- Thousand Needles
    [1442] = { 15, 27 }, -- Stonetalon Mountains
    [1443] = { 30, 40 }, -- Desolace
    [1444] = { 40, 50 }, -- Feralas
    [1445] = { 35, 45 }, -- Dustwallow Marsh
    [1446] = { 40, 50 }, -- Tanaris
    [1447] = { 48, 55 }, -- Azshara
    [1448] = { 48, 55 }, -- Felwood
    [1449] = { 48, 55 }, -- Un'Goro Crater
    [1451] = { 55, 60 }, -- Silithus
    [1450] = { 1, 60 }, -- Moonglade (a sanctuary)
    [1452] = { 55, 60 }, -- Winterspring
    [1454] = { 1, 60 }, -- Orgrimmar
    [1456] = { 1, 60 }, -- Thunder Bluff
    [1457] = { 1, 60 }, -- Darnassus
    [2482] = { 58, 60 }, -- Mount Hyjal (Forever)
    [2652] = { 35, 45 }, -- Shen'dralas (Forever)
    [2521] = { 1, 12 }, -- Zephras Isle (Forever: the Skyborne's starting isle)
    [2665] = { 1, 12 }, -- Zephras Isle, its second map
    -- Eastern Kingdoms
    [1416] = { 30, 40 }, -- Alterac Mountains
    [1417] = { 30, 40 }, -- Arathi Highlands
    [1418] = { 35, 45 }, -- Badlands
    [1419] = { 47, 55 }, -- Blasted Lands
    [1420] = { 1, 12 }, -- Tirisfal Glades
    [1421] = { 10, 20 }, -- Silverpine Forest
    [1422] = { 50, 60 }, -- Western Plaguelands
    [1423] = { 55, 60 }, -- Eastern Plaguelands
    [1424] = { 20, 30 }, -- Hillsbrad Foothills
    [1425] = { 40, 50 }, -- The Hinterlands
    [1426] = { 1, 12 }, -- Dun Morogh
    [1427] = { 43, 50 }, -- Searing Gorge
    [1428] = { 50, 60 }, -- Burning Steppes
    [1429] = { 1, 12 }, -- Elwynn Forest
    [1430] = { 55, 60 }, -- Deadwind Pass
    [1431] = { 20, 30 }, -- Duskwood
    [1432] = { 10, 20 }, -- Loch Modan
    [1433] = { 15, 25 }, -- Redridge Mountains
    [1434] = { 30, 45 }, -- Stranglethorn Vale
    [1435] = { 35, 45 }, -- Swamp of Sorrows
    [1436] = { 10, 20 }, -- Westfall
    [1437] = { 20, 30 }, -- Wetlands
    [2548] = { 35, 45 }, -- Riverglades (Forever)
    [1453] = { 1, 60 }, -- Stormwind City
    [1455] = { 1, 60 }, -- Ironforge
    [1458] = { 1, 60 }, -- Undercity
}
