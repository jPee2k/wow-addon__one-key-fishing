-- CatchDB.lua at login: an own record whose proofs were published but whose chain is gone (a damaged saved file)
-- cannot go on under that chain: it rolls (specs/004-public-channel-sync, data-model.md "The version chain").

local ID = "k7f2q6xa"
OneKeyFishingDB = { shareNotice = true, shared = { myID = ID, mine = {}, records = {
    [ID] = { id = ID, epoch = 2, seq = 7, proof = ("a"):rep(16),
        builds = { ["1.60.1"] = { ["1415:3:47"] = catch_cell(8, 0, { [6291] = { 8, 8 } }) } } },
} } }
load_addon()

test("the record rolls: the old one is kept with its proof, a new one starts with a new chain", function()
    local shared = ns.db.shared
    eq(shared.records[ID].epoch, 3, "a new epoch")
    eq(shared.records[ID].seq, 0, "from zero")
    eq(shared.records[ID .. "@2"].proof, ("a"):rep(16), "the old one kept as it was")
    eq(shared.chain.epoch, 3, "the chain of the new record")
end)
