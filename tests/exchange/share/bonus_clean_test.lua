-- A received record keeps its camp bonus parts through the store and a relay (specs/020-camp-buffs FR-010): the
-- stored cell carries q in fresh tables, and the record offered on holds the parts under their string keys.

local FISH, BLOATED = 6291, 6643
OneKeyFishingDB = { shareNotice = true }
load_addon()

local Store = ns.Share.Store
local shared = ns.db.shared

local function received()
    local cell = catch_cell(10, 4, { [FISH] = { 8, 8 }, [BLOATED] = { 2, 2 } })
    cell.q = {
        ["1"] = { c = 3, m = 1, i = { [BLOATED] = { 2, 2 }, [FISH] = { 1, 1 } }, extra = 7 },
        ["3"] = { c = 1, m = 1, i = { [FISH] = { 1, 1 } } },
    }
    return prove({ id = "qqqqqqqq", epoch = 0, seq = 1, builds = { ["1.60.1"] = { ["1415:3:47"] = cell } } })
end

test("a stored record keeps its parts in fresh tables, without foreign fields", function()
    local record = received()
    eq(Store.Accept(shared, record), "new", "stored")
    local stored = shared.records["qqqqqqqq@0"].builds["1.60.1"]["1415:3:47"]
    assert(stored.q, "q kept")
    eq(stored.q["1"].c, 3, "part 1 catches")
    eq(stored.q["1"].m, 1, "part 1 misses")
    eq(stored.q["1"].i[BLOATED][1], 2, "part 1 item")
    eq(stored.q["3"].c, 1, "part 3 catches")
    eq(stored.q["1"].extra, nil, "a foreign field is dropped")
    local sent = record.builds["1.60.1"]["1415:3:47"]
    sent.q["1"].c = 99
    sent.q["1"].i[BLOATED][1] = 99
    eq(stored.q["1"].c, 3, "the sender's table is not the stored one")
    eq(stored.q["1"].i[BLOATED][1], 2, "nor its items")
end)

test("the record offered on holds its parts under their string keys", function()
    local stored = shared.records["qqqqqqqq@0"]
    local decoded = ns.Share.Decode(ns.Share.Encode(Store.ForSending(stored)))
    local q = decoded.builds["1.60.1"]["1415:3:47"].q
    assert(q, "q relayed")
    eq(q["1"].c, 3, "part 1")
    eq(q["3"].m, 1, "part 3")
    eq(q[1], nil, "no number key")
    eq((ns.CatchDB.CheckRecord(decoded)), true, "the relayed record passes the check")
end)
