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
