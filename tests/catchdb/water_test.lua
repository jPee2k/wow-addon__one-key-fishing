-- CatchDB.lua: the water filter and HasPoolData (specs/005-catch-catalog, research R5, data-model.md "Views"). The
-- tests run in order and share one login.

local FISH, OIL = 6291, 6358

player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
load_addon(function()
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = {} }
end)

local CatchDB = ns.CatchDB
local function filter(water, range)
    return { range = range or "all", source = "all", water = water }
end

test("without any pool part there is no pool data", function()
    fish_cast({ { FISH, 1 } })
    eq(CatchDB.HasPoolData(), false, "no pool")
    ns.Fire("SHARED_DATA_CHANGED", { "nothing@0" }, ns.db.shared)
    eq(CatchDB.HasPoolData(), false, "read again: still none")
end)

test("a seed cell with a pool part is pool data", function()
    local pooled = catch_cell(60, 10, { [FISH] = { 40, 40 }, [OIL] = { 20, 25 } })
    pooled.k, pooled.p = 2, { c = 25, i = { [FISH] = { 10, 10 }, [OIL] = { 15, 20 } } }
    local weighted = catch_cell(20, 0, { [FISH] = { 20, 20 } })
    weighted.k, weighted.r, weighted.x, weighted.p = 3, 60, 18, { c = 5, i = { [FISH] = { 5, 5 } } }
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = { ["1415:3:47"] = pooled,
        ["1415:3:11"] = weighted, ["1415:3:22"] = catch_cell(30, 5, { [FISH] = { 30, 30 } }) } }
    ns.Fire("SHARED_DATA_CHANGED")
    eq(CatchDB.HasPoolData(), true, "the seed has a pool")
end)

test("pool and open water add up to everywhere: catches, items, players (SC-007)", function()
    for _, view in ipairs({ { CatchDB.QueryMap(1415, filter("all")), CatchDB.QueryMap(1415, filter("pool")),
        CatchDB.QueryMap(1415, filter("open")) } }) do
        local all, pool, open = view[1], view[2], view[3]
        eq(pool.catches + open.catches, all.catches - 40, "catches (the weighted cell's raw 60 count as 20 + 40)")
        local function itemCatches(v, itemID)
            for _, item in ipairs(v.items) do
                if item.itemID == itemID then
                    return item.catches
                end
            end
            return 0
        end
        eq(itemCatches(pool, OIL) + itemCatches(open, OIL), itemCatches(all, OIL), "oil")
        eq(itemCatches(pool, FISH) + itemCatches(open, FISH), itemCatches(all, FISH), "fish")
        eq(pool.missRate, nil, "no miss rate for pools")
        eq(open.missRate, nil, "nor open water")
        assert(all.missRate, "everywhere has it")
    end
end)

test("the 50-catch rule counts the filtered catches; a weighted seed cell uses its filtered c", function()
    eq(CatchDB.Query(1415, "47", filter("all", 3)).scope, "spot", "60 catches at the spot")
    eq(CatchDB.Query(1415, "47", filter("pool", 3)).scope, "map", "25 of them from a pool: too few")
    eq(CatchDB.Query(1415, "47", filter("open", 3)).scope, "map", "35 in open water: too few")
    eq(CatchDB.Query(1415, "11", filter("all", 3)).scope, "spot", "the weighted cell's 60 raw catches")
    eq(CatchDB.Query(1415, "11", filter("pool", 3)).scope, "map", "its filtered c: 5")
    eq(CatchDB.QueryMap(1415, filter("pool")).players, 3, "players of the parts with filtered catches")
end)

test("every view takes the filter, and Query's cache tells the waters apart", function()
    local all = CatchDB.Query(1415, "11", filter("all", 3))
    local pool = CatchDB.Query(1415, "11", filter("pool", 3))
    assert(all ~= pool, "two cache entries")
    local cells = CatchDB.QueryCells(1415, filter("pool"))
    eq(#cells, 2, "only the cells with pool catches")
    for _, view in ipairs(cells) do
        assert(view.cell == "47" or view.cell == "11", view.cell)
    end
    eq(CatchDB.QueryMap(1415, filter("pool")).catches, 30, "25 + 5")
end)
