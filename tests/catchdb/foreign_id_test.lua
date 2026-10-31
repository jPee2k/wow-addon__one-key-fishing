-- CatchDB.lua: a saved own record under this account's ID that carries another ID (a file copied from another
-- account, or damaged) starts over like any other damaged record: it cannot be told whose catches these are.

local ID = "qqqqqqqq"
OneKeyFishingDB = { shared = { myID = ID, mine = {}, records = {
    [ID] = { id = "rrrrrrrr", epoch = 0, seq = 1,
        builds = { ["1.60.1"] = { ["1415:3:47"] = catch_cell(1, 0) } } },
} } }
load_addon()

test("an own record with another ID starts over", function()
    local record = ns.db.shared.records[ID]
    eq(record.id, ID, "a fresh record with the account's ID")
    eq(record.seq, 0, "started over")
    eq(next(record.builds), nil, "empty")
    eq(next(ns.Share.Store.Units(ns.db.shared, {})), nil, "nothing offered")
    eq(ns.db.shared.records[ID .. "@0"], nil, "nothing frozen under the own ID")
    eq(ns.db.shared.records["rrrrrrrr@0"], nil, "nothing kept under the other ID")
end)
