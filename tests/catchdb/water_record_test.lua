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

test("open water, the cell without its pool part, must hold the cell rules", function()
    local function check(c, items, pool)
        return ns.CatchDB.CheckRecord(pooled("rrrrrrrr", c, items, pool))
    end
    local ok, reason = check(15, { [6291] = { 1, 1 } }, { c = 15, i = { [6291] = { 15, 300 } } })
    eq(ok, false, "more pool catches of an item than the cell has")
    eq(reason, "1415:3:47: open water: item 6291 has impossible counts", "the reason")
    eq((check(5, { [6291] = { 5, 5 } }, { c = 5, i = { [6291] = { 5, 9 } } })), false, "more pool pieces")
    eq((check(5, { [6291] = { 5, 5 } }, { c = 2, i = { [6303] = { 2, 2 } } })), false, "a pool item the cell lacks")
    eq((check(10, { [6291] = { 10, 10 } }, { c = 9, i = { [6291] = { 1, 1 } } })), false,
        "9 open catches of an item out of 1 open catch")
    eq((check(2, { [6291] = { 2, 40 } }, { c = 1, i = { [6291] = { 1, 1 } } })), false,
        "39 open pieces from 1 open catch")
    eq((check(1, { [6291] = { 1, 5 } }, { c = 1, i = { [6291] = { 1, 1 } } })), false, "open pieces with no catch")
    eq((check(5, { [6291] = { 5, 5 } }, { c = 5, i = { [6291] = { 5, 5 } } })), true, "a pool part equal to the cell")
    eq((check(10, { [6291] = { 6, 9 }, [6303] = { 4, 4 } }, { c = 4, i = { [6291] = { 2, 3 }, [6303] = { 4, 4 } } })),
        true, "an honest split")
end)

test("a forged pool part is refused, so open water keeps the honest players' catches", function()
    local OIL = 6358
    eq(ns.Share.Store.Accept(ns.db.shared, pooled("ssssssss", 15, { [OIL] = { 1, 1 }, [6303] = { 15, 15 } },
        { c = 15, i = { [OIL] = { 15, 300 } } })), "refused", "the forged record")
    -- Three honest reporters: enough to list an item the seed does not have (FR-014).
    for _, id in ipairs({ "tttttttt", "uuuuuuuu", "vvvvvvvv" }) do
        eq(ns.Share.Store.Accept(ns.db.shared, pooled(id, 10, { [OIL] = { 10, 10 } })), "new", id)
    end
    local view = ns.CatchDB.QueryMap(1415, { range = "all", source = "all", water = "open" })
    local oil
    for _, item in ipairs(view.items) do
        assert(item.chance <= 1, "chance of " .. item.itemID .. " above 1")
        if item.itemID == OIL then
            oil = item
        end
    end
    assert(oil, "the oil is listed in open water")
    eq(oil.catches, 30, "the honest players' 30 catches")
end)
