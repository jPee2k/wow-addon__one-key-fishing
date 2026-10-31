-- CatchDB.lua: a saved own record without its ID (a damaged file) gets the ID back, since everything else in it is
-- sound, so no catch is lost and the exchange's summary (Share.lua) does not break on it at every HELLO.

local ID = "qqqqqqqq"
OneKeyFishingDB = { shared = { myID = ID, mine = {}, records = {
    [ID] = { epoch = 0, seq = 1, builds = { ["1.60.1"] = { ["1415:3:47"] = catch_cell(1, 0) } } },
} } }
load_addon()

test("an own record without its ID gets it back, keeps its catches, and the exchange's summary does not error",
    function()
    local record = ns.db.shared.records[ID]
    eq(record.id, ID, "the ID is back")
    eq(record.seq, 1, "the seq is kept")
    eq(record.builds["1.60.1"]["1415:3:47"].c, 1, "the catch is kept")
    eq(ns.Share.Store.Units(ns.db.shared, {})[ID .. "@0"], 1, "offered, no error")
    eq(ns.db.shared.records[ID .. "@0"], nil, "nothing frozen under the own ID")
end)
