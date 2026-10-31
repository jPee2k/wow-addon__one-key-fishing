-- CatchDB.lua at login: an own record from before part 3 (no proof yet) gets a version chain at its seq
-- (specs/004-public-channel-sync, data-model.md "The version chain").

local ID = "k7f2q6xa"
OneKeyFishingDB = { shareNotice = true, shared = { myID = ID, mine = {}, records = {
    [ID] = { id = ID, epoch = 2, seq = 7,
        builds = { ["1.60.1"] = { ["1415:3:47"] = catch_cell(8, 0, { [6291] = { 8, 8 } }) } } },
} } }
load_addon()

test("the record keeps its epoch and seq and gets a chain; its proof comes with the marks", function()
    local record, chain = ns.db.shared.records[ID], ns.db.shared.chain
    eq(record.epoch, 2, "not rolled")
    eq(record.seq, 7, "seq kept")
    eq(chain.epoch, 2, "a chain for its epoch")
    eq(record.proof, nil, "no proof before the marks")
    advance(0)
    assert(record.proof and #record.proof == 16, "a proof once the marks are there")
    eq(ns.CatchDB.OwnProofReady(), true, "offered from now on")
end)
