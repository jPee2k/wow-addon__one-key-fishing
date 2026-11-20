-- CatchDB views: a skill filter value r sums the ranges 0 to r; "all" sums every range (specs/021-cumulative-skill-
-- filter, research R1 and R2). The tests run in order and share one login.

local A, B, C, D = 6291, 6303, 6289, 6317 -- one item per range 0, 1, 2, 3

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

local function filter(range)
    return { range = range, source = "all", water = "all" }
end

local function items(view)
    local ids = {}
    for _, item in ipairs(view.items) do
        ids[item.itemID] = item
    end
    return ids
end

test("a range sums every range up to it", function()
    seed({
        ["1415:0:47"] = catch_cell(10, 0, { [A] = { 10, 10 } }),
        ["1415:1:47"] = catch_cell(20, 0, { [B] = { 20, 20 } }),
        ["1415:2:47"] = catch_cell(30, 0, { [C] = { 30, 30 } }),
        ["1415:3:47"] = catch_cell(40, 0, { [D] = { 40, 40 } }),
    })
    local view = CatchDB.Query(1415, "47", filter(2))
    local ids = items(view)
    assert(ids[A] and ids[B] and ids[C], "the items of ranges 0, 1 and 2")
    eq(ids[D], nil, "not the item of 225-299")
    eq(view.catches, 60, "10 + 20 + 30")
    near(ids[C].chance, 30 / 60, "a chance among the summed catches")
end)

test("each item keeps the ranges it was caught in", function()
    local ids = items(CatchDB.Query(1415, "47", filter(2)))
    eq(ids[A].ranges.min, 0, "0-74")
    eq(ids[A].ranges.max, 0, "only 0-74")
    eq(ids[C].ranges.min, 2, "150-224")
end)

test("\"all\" sums every range, as the four ranges together", function()
    local view = CatchDB.Query(1415, "47", filter("all"))
    eq(view.catches, 100, "10 + 20 + 30 + 40")
    local ids = items(view)
    assert(ids[A] and ids[B] and ids[C] and ids[D], "all four items")
end)

test("a stray 4 (300+) reads as \"all\"", function()
    local four, all = CatchDB.Query(1415, "47", filter(4)), CatchDB.Query(1415, "47", filter("all"))
    eq(four.catches, all.catches, "the same catches")
    eq(#four.items, #all.items, "the same items")
end)

test("data only below the own range is shown (the page is not empty)", function()
    seed({ ["1415:1:47"] = catch_cell(60, 0, { [B] = { 60, 60 } }) })
    local view = CatchDB.Query(1415, "47", filter(2))
    eq(view.scope, "spot", "the spot has 60 catches of 75-149")
    assert(items(view)[B], "the item caught with 75-149")
end)

test("data only above the chosen range stays out", function()
    seed({ ["1415:3:47"] = catch_cell(60, 0, { [D] = { 60, 60 } }) })
    eq(CatchDB.Query(1415, "47", filter(1)).scope, "none", "nothing caught up to 149")
end)

test("the spot or the map is chosen on the summed catches", function()
    seed({
        ["1415:0:47"] = catch_cell(30, 0, { [A] = { 30, 30 } }),
        ["1415:1:47"] = catch_cell(30, 0, { [B] = { 30, 30 } }),
        ["1415:0:11"] = catch_cell(5, 0, { [A] = { 5, 5 } }),
    })
    eq(CatchDB.Query(1415, "47", filter(1)).scope, "spot", "30 + 30 reach 50")
    eq(CatchDB.Query(1415, "47", filter(0)).scope, "map", "30 alone do not")
end)

test("the map and its spots sum the same ranges", function()
    seed({
        ["1415:0:47"] = catch_cell(10, 0, { [A] = { 10, 10 } }),
        ["1415:2:11"] = catch_cell(30, 0, { [C] = { 30, 30 } }),
        ["1415:3:11"] = catch_cell(40, 0, { [D] = { 40, 40 } }),
    })
    local map = CatchDB.QueryMap(1415, filter(2))
    eq(map.catches, 40, "10 + 30, not the 225-299 cell")
    local cells = {}
    for _, view in ipairs(CatchDB.QueryCells(1415, filter(2))) do
        cells[view.cell] = view.catches
    end
    eq(cells["47"], 10, "spot 47")
    eq(cells["11"], 30, "spot 11 without its 225-299 cell")
end)
