-- CatchDB.lua: a saved own record without its ID (a damaged file) starts over like one with any other damage, so
-- the exchange's summary (Share.lua) does not break on it at every HELLO.

local ID = "qqqqqqqq"
OneKeyFishingDB = { shared = { myID = ID, mine = {}, records = {
    [ID] = { epoch = 0, seq = 1, builds = { ["1.60.1"] = { ["1415:3:47"] = catch_cell(1, 0) } } },
} } }
load_addon()

test("an own record without its ID starts over, and the exchange's summary does not error", function()
    local record = ns.db.shared.records[ID]
    eq(record.id, ID, "a fresh record with the ID")
    eq(record.seq, 0, "started over")
    eq(next(record.builds), nil, "empty")
    eq(next(ns.Share.Store.Units(ns.db.shared, {})), nil, "nothing offered, no error")
    eq(ns.db.shared.records[ID .. "@0"], nil, "nothing frozen under the own ID")
end)
