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

test("CatchDB.OwnRecord, for the database and the exchange alike: nil for a missing or damaged own record", function()
    local store = { myID = "abcdefgh", records = {} }
    eq(ns.CatchDB.OwnRecord(store), nil, "missing")
    store.records.abcdefgh = { id = "abcdefgh", epoch = 1, seq = "x", builds = {} }
    eq(ns.CatchDB.OwnRecord(store), nil, "a seq that is no count")
    store.records.abcdefgh.seq, store.records.abcdefgh.epoch = 3, -1
    eq(ns.CatchDB.OwnRecord(store), nil, "an epoch that is no count")
    store.records.abcdefgh.epoch = 1
    eq(ns.CatchDB.OwnRecord(store), store.records.abcdefgh, "a sound record")
    eq(ns.CatchDB.OwnRecord(), ns.db.shared.records[ns.db.shared.myID], "the account's own by default")
end)
