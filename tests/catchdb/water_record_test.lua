-- CatchDB.HasPoolData from a received record (specs/005-catch-catalog, research R5).

load_addon(function()
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = {} }
end)

test("a received record with a pool part is pool data, read again after the change", function()
    eq(ns.CatchDB.HasPoolData(), false, "nothing yet")
    local cell = catch_cell(10, 0, { [6291] = { 10, 10 } })
    cell.p = { c = 4, i = { [6291] = { 4, 4 } } }
    eq(ns.Share.Store.Accept(ns.db.shared, prove({ id = "qqqqqqqq", epoch = 0, seq = 1,
        builds = { ["1.60.1"] = { ["1415:3:47"] = cell } } })), "new", "stored")
    eq(ns.CatchDB.HasPoolData(), true, "from the record")
end)

-- A record of one cell at 1415:3:47 with the items and the pool part.
local function pooled(id, c, items, pool)
    local cell = catch_cell(c, 0, items)
    cell.p = pool
    return prove({ id = id, epoch = 0, seq = 1, builds = { ["1.60.1"] = { ["1415:3:47"] = cell } } })
end

test("the pool part of a cell must fit the cell, item by item", function()
    local ok, reason = ns.CatchDB.CheckRecord(pooled("rrrrrrrr", 15, { [6291] = { 1, 1 } },
        { c = 15, i = { [6291] = { 15, 300 } } }))
    eq(ok, false, "more pool catches of an item than the cell has")
    eq(reason, "1415:3:47: pool item 6291 is more than the cell has", "the reason")
    eq((ns.CatchDB.CheckRecord(pooled("rrrrrrrr", 5, { [6291] = { 5, 5 } }, { c = 5, i = { [6291] = { 5, 9 } } }))),
        false, "more pool pieces than the cell has")
    eq((ns.CatchDB.CheckRecord(pooled("rrrrrrrr", 5, { [6291] = { 5, 5 } }, { c = 2, i = { [6303] = { 2, 2 } } }))),
        false, "a pool item the cell never counted")
    eq((ns.CatchDB.CheckRecord(pooled("rrrrrrrr", 5, { [6291] = { 5, 5 } }, { c = 5, i = { [6291] = { 5, 5 } } }))),
        true, "a pool part equal to the cell")
end)

test("a forged pool part is refused, so open water keeps an honest player's catches", function()
    eq(ns.Share.Store.Accept(ns.db.shared, pooled("ssssssss", 15, { [6291] = { 1, 1 }, [6303] = { 15, 15 } },
        { c = 15, i = { [6291] = { 15, 300 } } })), "refused", "the forged record")
    -- With the first test's record, three honest reporters: enough to list an item the seed does not have (FR-014).
    eq(ns.Share.Store.Accept(ns.db.shared, pooled("tttttttt", 10, { [6291] = { 10, 10 } })), "new", "an honest one")
    eq(ns.Share.Store.Accept(ns.db.shared, pooled("uuuuuuuu", 10, { [6291] = { 10, 10 } })), "new", "and another")
    local view = ns.CatchDB.QueryMap(1415, { range = "all", source = "all", water = "open" })
    local fish
    for _, item in ipairs(view.items) do
        assert(item.chance <= 1, "chance of " .. item.itemID .. " above 1")
        if item.itemID == 6291 then
            fish = item
        end
    end
    assert(fish, "6291 is listed in open water")
    eq(fish.catches, 26, "the honest 10 and 10 plus the first record's 6 open catches")
end)
