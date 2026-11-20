-- CatchDB.Query: the miss rate comes from the chosen skill range alone, at the scope of the list, while the list sums
-- the ranges up to it (specs/021-cumulative-skill-filter FR-005 to FR-008, research R3). The tests run in order and
-- share one login.

local FISH = 6291

player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 180
load_addon(function()
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = {} }
end)

local CatchDB = ns.CatchDB

local function seed(cells)
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = cells }
    ns.Fire("SHARED_DATA_CHANGED")
end

local function cell(c, m, q)
    local made = catch_cell(c, m, { [FISH] = { c, c } })
    made.q = q
    return made
end

local function filter(range, water, bonus)
    return { range = range, source = "all", water = water or "all", bonus = bonus }
end

test("the miss rate of the chosen range, not of the ranges below it", function()
    seed({ ["1415:0:47"] = cell(65, 35), ["1415:2:47"] = cell(85, 15) })
    local view = CatchDB.Query(1415, "47", filter(2))
    eq(view.scope, "spot", "the spot")
    eq(view.catches, 150, "the list sums 0-74 and 150-224")
    near(view.missRate, 15 / 100, "15 %, not the 25 % of both ranges")
    eq(view.missLittleData, false, "100 casts in 150-224")
end)

test("below 50 casts in the chosen range the miss rate is little data, the list is not", function()
    seed({ ["1415:0:47"] = cell(65, 35), ["1415:1:47"] = cell(20, 10), ["1415:2:47"] = cell(85, 15) })
    local view = CatchDB.Query(1415, "47", filter(1))
    eq(view.missLittleData, true, "30 casts in 75-149")
    eq(view.littleData, false, "85 catches in the list")
    assert(#view.items > 0, "the items are listed")
end)

test("range 0-74: the list's own sum gives the miss rate", function()
    local view = CatchDB.Query(1415, "47", filter(0))
    near(view.missRate, 35 / 100, "35 %")
    eq(view.missLittleData, false, "100 casts")
end)

test("after the fallback to the map, the chosen range's misses on the whole map", function()
    seed({ ["1416:0:11"] = cell(40, 0), ["1416:2:22"] = cell(60, 40) })
    local view = CatchDB.Query(1416, "11", filter(2))
    eq(view.scope, "map", "40 catches at the spot: the map")
    eq(view.catches, 100, "the map's catches up to 224")
    near(view.missRate, 40 / 100, "the misses of 150-224 in the other cell")
end)

test("\"all\" takes the misses of 300+ alone", function()
    seed({ ["1415:0:47"] = cell(65, 35), ["1415:2:47"] = cell(85, 15) })
    eq(CatchDB.Query(1415, "47", filter("all")).missLittleData, true, "no cast at 300+")
    seed({ ["1415:0:47"] = cell(65, 35), ["1415:2:47"] = cell(85, 15), ["1415:4:47"] = cell(54, 6) })
    local view = CatchDB.Query(1415, "47", filter("all"))
    eq(view.catches, 204, "the list sums every range")
    near(view.missRate, 6 / 60, "10 % at 300+")
    eq(view.missLittleData, false, "60 casts at 300+")
end)

test("no miss rate under a water filter", function()
    local view = CatchDB.Query(1415, "47", filter(2, "pool"))
    eq(view.missRate, nil, "a miss has no loot source")
end)

test("under a camp bonus filter, that bonus's part of the chosen range", function()
    seed({
        ["1415:0:47"] = cell(65, 35, { ["1"] = { c = 30, m = 30, i = { [FISH] = { 30, 30 } } } }),
        ["1415:2:47"] = cell(85, 15, { ["1"] = { c = 40, m = 10, i = { [FISH] = { 40, 40 } } } }),
    })
    local view = CatchDB.Query(1415, "47", filter(2, "all", "rack"))
    eq(view.catches, 70, "the Rack's catches up to 224")
    near(view.missRate, 10 / 50, "the Rack's misses at 150-224")
    eq(view.missLittleData, false, "50 casts under the Rack at 150-224")
end)

test("the catalog's map and spot views carry no miss rate", function()
    eq(CatchDB.QueryMap(1415, filter(2)).missRate, nil, "QueryMap")
    for _, view in ipairs(CatchDB.QueryCells(1415, filter(2))) do
        eq(view.missRate, nil, "QueryCells " .. view.cell)
    end
end)
