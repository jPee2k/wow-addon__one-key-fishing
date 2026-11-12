-- CatchDB/Views.lua and Index.lua (specs/005-catch-catalog, data-model.md "Views", "Change stamps"):
-- QueryMap, QueryCells, Maps,
-- MapStamp and the own-cells index. The tests run in order and share one login.

local FISH, OTHER = 6291, 6303

player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
load_addon(function()
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = {
        ["1415:3:47"] = { c = 10, m = 2, t = 120, k = 2, px = 5160, py = 9360,
            i = { [FISH] = { 8, 8 }, [OTHER] = { 2, 2 } } },
        ["1415:1:47"] = { c = 5, m = 0, t = 50, k = 1, px = 2000, py = 3500, i = { [FISH] = { 5, 5 } } },
        ["1415:3:x"] = { c = 4, m = 0, t = 40, k = 1, i = { [OTHER] = { 4, 4 } } },
        ["1429:2:11"] = { c = 20, m = 0, t = 200, k = 3, i = { [FISH] = { 20, 20 } } },
    } }
end)

local CatchDB = ns.CatchDB
local ALL = { range = "all", source = "all" }
local MINE = { range = "all", source = "mine" }

local function stamps(...)
    local out = {}
    for i, mapID in ipairs({ ... }) do
        out[i] = CatchDB.MapStamp(mapID)
    end
    return out
end

test("QueryMap is the map view Query falls back to for a spot with few catches", function()
    local fallback = CatchDB.Query(1415, "55", ALL)
    local map = CatchDB.QueryMap(1415, ALL)
    eq(fallback.scope, "map", "Query fell back")
    eq(map.scope, "map", "scope")
    eq(map.catches, fallback.catches, "catches")
    eq(map.catches, 19, "10 + 5 + 4")
    eq(map.players, fallback.players, "players")
    eq(#map.items, #fallback.items, "items")
    for i, item in ipairs(map.items) do
        eq(item.itemID, fallback.items[i].itemID, "item " .. i)
        near(item.chance, fallback.items[i].chance, "chance " .. i)
    end
    eq(CatchDB.QueryMap(9999, ALL).scope, "none", "no catches")
end)

test("QueryCells gives one view per cell with catches, with its point and the item's skill span", function()
    local views = CatchDB.QueryCells(1415, ALL)
    eq(#views, 2, "cells 47 and x")
    local spot, nowhere = views[1], views[2]
    eq(spot.cell, "47", "the cell")
    eq(spot.scope, "spot", "a spot view")
    eq(spot.catches, 15, "both ranges of the cell")
    near(spot.point.x, 7160 / 17 / 1000, "x: px / casts / 1000")
    near(spot.point.y, 12860 / 17 / 1000, "y")
    eq(spot.items[1].itemID, FISH, "the most caught item")
    eq(spot.items[1].ranges.min, 1, "lowest range")
    eq(spot.items[1].ranges.max, 3, "highest range")
    eq(spot.items[2].ranges.min, 3, "the other item only in range 3")
    eq(nowhere.cell, "x", "no exact spot")
    eq(nowhere.point, nil, "no point")
    eq(#CatchDB.QueryCells(1415, { range = 1, source = "all" }), 1, "range 1: only cell 47")
end)

test("Maps lists the seed's, the own and, with sharing on, other players' maps; mine only its own", function()
    local list = CatchDB.Maps(ALL)
    eq(table.concat(list, ","), "1415,1429", "the seed's maps")
    eq(#CatchDB.Maps(MINE), 0, "nothing of mine yet")
    fish_cast({ { FISH, 1 } })
    player_map_id = 1500
    fish_cast({ { FISH, 1 } })
    player_map_id = 1415
    eq(table.concat(CatchDB.Maps(MINE), ","), "1415,1500", "own maps")
    eq(table.concat(CatchDB.Maps(ALL), ","), "1415,1429,1500", "with the own")
    local other = prove({ id = "qqqqqqqq", epoch = 0, seq = 2,
        builds = { ["1.60.1"] = { ["1600:3:11"] = catch_cell(30, 0, { [FISH] = { 30, 30 } }) } } })
    eq(ns.Share.Store.Accept(ns.db.shared, other), "new", "stored")
    eq(table.concat(CatchDB.Maps(ALL), ","), "1415,1429,1500,1600", "with the other player's")
    ns.Share.SetEnabled(false)
    eq(table.concat(CatchDB.Maps(ALL), ","), "1415,1429,1500", "sharing off")
    ns.Share.SetEnabled(true)
end)

test("a settled cast moves its map's stamp only", function()
    local before = stamps(1415, 1429)
    fish_cast(nil)
    local after = stamps(1415, 1429)
    assert(after[1] ~= before[1], "the map of the cast moved")
    eq(after[2], before[2], "another map did not")
end)

test("a changed record moves the stamps of its maps before and after the change", function()
    CatchDB.Maps(ALL) -- the index of other players' records is built
    local key = "qqqqqqqq@0"
    local before = stamps(1415, 1600, 1700)
    ns.db.shared.records[key].builds = { ["1.60.1"] = { ["1700:3:11"] = catch_cell(30, 0, { [FISH] = { 30, 30 } }) } }
    ns.Fire("SHARED_DATA_CHANGED", { key }, ns.db.shared)
    local after = stamps(1415, 1600, 1700)
    eq(after[1], before[1], "an unrelated map")
    assert(after[2] ~= before[2], "the map the record left")
    assert(after[3] ~= before[3], "the map the record came to")
end)

test("a change without keys, and switching sharing, move every stamp", function()
    local before = stamps(1415, 1429, 4242)
    ns.Fire("SHARED_DATA_CHANGED")
    local after = stamps(1415, 1429, 4242)
    for i = 1, 3 do
        assert(after[i] ~= before[i], "stamp " .. i)
    end
    ns.Share.SetEnabled(false)
    local off = stamps(1415, 1429, 4242)
    for i = 1, 3 do
        assert(off[i] ~= after[i], "sharing off: stamp " .. i)
    end
    ns.Share.SetEnabled(true)
end)

test("QueryMap and QueryCells keep their result until the map's stamp moves", function()
    local map, cells = CatchDB.QueryMap(1415, ALL), CatchDB.QueryCells(1415, ALL)
    assert(CatchDB.QueryMap(1415, ALL) == map, "the same map view")
    assert(CatchDB.QueryCells(1415, ALL) == cells, "the same cell views")
    local other = CatchDB.QueryMap(1429, ALL)
    fish_cast({ { FISH, 1 } })
    assert(CatchDB.QueryMap(1415, ALL) ~= map, "a new view after the catch")
    assert(CatchDB.QueryCells(1415, ALL) ~= cells, "new cell views")
    assert(CatchDB.QueryMap(1429, ALL) == other, "the other map kept its view")
end)

-- The own catch summed cell by cell, as every map sum did before the own-cells index.
local function walk(mapID, cells)
    local catches = 0
    for key, cell in pairs(cells) do
        if key:find("^" .. mapID .. ":") then
            catches = catches + cell.c
        end
    end
    return catches
end

test("the own-cells index gives the sums of a full walk, after catches on new and old keys", function()
    CatchDB.QueryMap(1415, MINE) -- the index exists from here
    for _, position in ipairs({ { 0.43, 0.78 }, { 0.91, 0.12 }, { 0.05, 0.95 } }) do
        player_map_position = position
        fish_cast({ { FISH, 1 } })
    end
    player_map_position = nil
    fish_cast({ { OTHER, 1 } })
    player_map_position = { 0.43, 0.78 }
    local mine = ns.db.shared.mine
    eq(CatchDB.QueryMap(1415, MINE).catches, walk(1415, mine), "Only mine")
    local own = ns.db.shared.records[ns.db.shared.myID].builds["1.60.1"]
    eq(CatchDB.QueryMap(1415, ALL).catches, 19 + walk(1415, own), "All: the seed and the own record")
    eq(#CatchDB.QueryCells(1415, MINE), 4, "every own cell of the map: 47, 91, 09 and x")
end)
