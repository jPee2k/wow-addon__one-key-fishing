-- CatchDB.lua and Share.lua: the own record's version chain, checking newer versions, the casting limit
-- (specs/004-public-channel-sync, research R9, data-model.md "The version chain"). Runs with the fast stand-in for
-- ns.ProofStep (tests/wow.lua); tests/core/proof_test.lua checks the real SHA-256. The tests share one login, in order.

local FISH = 6291
player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
load_addon()

local CatchDB, Store = ns.CatchDB, ns.Share.Store
local shared = ns.db.shared

local function own()
    return shared.records[shared.myID]
end

-- `count` link steps down from `link`.
local function walk(link, count)
    for _ = 1, count do
        link = ns.ProofStep(link)
    end
    return link
end

-- Counts the ProofStep calls fn makes.
local function steps(fn)
    local step, count = ns.ProofStep, 0
    ns.ProofStep = function(link)
        count = count + 1
        return step(link)
    end
    fn()
    ns.ProofStep = step
    return count
end

-- Runs the one timer that is due first: one frame step (advance(0) would run every step due at once).
local function frameStep()
    local index
    for i, timer in ipairs(timers) do
        if timer.at <= GetTime() and (not index or timer.at < timers[index].at) then
            index = i
        end
    end
    assert(index, "a frame step is due")
    table.remove(timers, index).fn()
end

-- Another player's record at `seq` with `catches` catches (10 s each), its proof from `secret`.
local function other(seq, catches, secret)
    return prove({ id = "oooooooo", epoch = 0, seq = seq,
        builds = { ["1.60.1"] = { ["1415:3:47"] = catch_cell(catches, 0, { [FISH] = { catches, catches } }) } } },
        secret or "the owner", 512)
end

---------------------------------------------------------------------------
-- The own chain
---------------------------------------------------------------------------
test("a new account gets a chain for its record; the marks are built in frame steps", function()
    local chain = shared.chain
    eq(chain.epoch, own().epoch, "the live record's epoch")
    eq(chain.top, CatchDB.CHAIN_LENGTH, "top")
    assert(chain.secret:find("^[a-z2-7]+$") and #chain.secret == 26, "26 base32 characters: " .. chain.secret)
    eq(CatchDB.private.OwnProofReady(), false, "not ready before the marks")
    eq(CatchDB.ChainState(), "0 of 4096, marks building", "debug line")
    advance(0)
    local marks = 0
    for position in pairs(chain.marks) do
        assert(position % 64 == 0, "a mark at a multiple of 64: " .. position)
        marks = marks + 1
    end
    eq(marks, 64, "every 64th link from the top down")
    eq(chain.marks[4096], ns.ProofStep(chain.secret), "the top link is the step of the secret")
    eq(CatchDB.private.OwnProofReady(), true, "ready")
    eq(own().proof, walk(chain.marks[64], 64), "seq 0 carries link 0")
end)

test("a seq bump sets the new link with at most 63 steps; consecutive links chain", function()
    local before = own().proof
    local count = steps(function() fish_cast({ { FISH, 1 } }) end)
    eq(own().seq, 1, "bumped")
    assert(count <= 63, "steps for the bump: " .. count)
    eq(ns.ProofStep(own().proof), before, "link 1 steps down to link 0")
    eq(own().proof, walk(shared.chain.marks[64], 63), "from the next mark")
end)

test("the own record is offered only with its proof", function()
    local node = ns.Share.NewNode(shared, { now = GetTime, time = GetTime, after = C_Timer.After,
        send = function() end, broadcast = function() end, forEachFriend = function() end,
        canSend = function() return true end, absorbed = function() return {} end,
        seedEpoch = function() return 0 end, encode = ns.Share.Encode, decode = ns.Share.Decode })
    assert(node:OwnData(own()), "offered")
    local proof = own().proof
    own().proof = nil
    local data, problem = node:OwnData(own())
    eq(data, false, "not offered")
    eq(problem, "proof not ready", "why")
    own().proof = proof
end)

test("a seq at the chain's top rolls the record: a new chain, a new secret; the old record keeps its proof", function()
    local old, secret, epoch = own(), shared.chain.secret, own().epoch
    old.seq, old.proof = 4096, shared.chain.marks[4096]
    fish_cast({ { FISH, 1 } })
    assert(own() ~= old, "a new record")
    eq(shared.records[shared.myID .. "@" .. epoch], old, "the old one is kept under <myID>@<epoch>")
    eq(old.proof, shared.chain.marks[4096] and old.proof, "its last proof stays")
    assert(shared.chain.secret ~= secret, "a new secret")
    eq(shared.chain.epoch, own().epoch, "for the new epoch")
    advance(0)
end)

---------------------------------------------------------------------------
-- Newer versions and the casting limit
---------------------------------------------------------------------------
test("the owner's next version continues the chain; a made-up one claiming to be newer does not", function()
    eq(CatchDB.CheckVersion(other(3, 15), other(4, 16)), "ok", "the owner's next version")
    local result, reason = CatchDB.CheckVersion(other(3, 15), other(4, 16, "a forger"))
    eq(result, "invalid", "a made-up chain")
    assert(reason:find("does not continue", 1, true), reason)
    eq(CatchDB.CheckVersion(other(4, 16), other(4, 16)), "invalid", "not newer")
    eq(CatchDB.CheckVersion({ seq = 0, proof = ("a"):rep(16) }, { seq = 4097, proof = ("a"):rep(16) }), "invalid",
        "a jump over a whole chain")
end)

test("a long jump is walked PROOF_STEPS links at a time", function()
    local held, incoming = other(3, 15), other(303, 400)
    local results, state = {}, nil
    repeat
        local result
        result, state = CatchDB.CheckVersion(held, incoming, 32, state)
        table.insert(results, result)
    until result ~= "more"
    eq(#results, 10, "nine steps of 32 links, then the last 12")
    eq(results[10], "ok", "the end of the chain is the held proof")
end)

test("the owner's next version replaces a made-up copy at a seq it published, whatever the copy holds", function()
    local copy = other(4, 16)
    copy.builds["1.60.1"]["9999:0:x"] = catch_cell(1, 0, { [12345] = { 1, 1 } }) -- made-up content, real link 4
    copy.builds["1.60.1"]["1415:3:47"] = catch_cell(3, 0)
    eq((CatchDB.CheckRecord(copy)), true, "the copy passes the check (within the limit)")
    eq(CatchDB.CheckVersion(copy, other(5, 17)), "ok", "the real version 5 continues link 4")
end)

test("the seed's proof anchors a unit the seed holds in part", function()
    local held = { seq = 3, proof = other(3, 15).proof }
    eq(CatchDB.CheckVersion(held, other(5, 20)), "ok", "the owner's version")
    eq(CatchDB.CheckVersion(held, other(5, 20, "a forger")), "invalid", "a made-up one")
end)

test("no record holds more than STEP_SECONDS of casting per step of its seq", function()
    local limit = CatchDB.private.STEP_SECONDS
    eq(limit, 180, "180 s per step")
    local record = other(2, 36) -- 36 casts of 10 s: exactly 2 x 180
    eq((CatchDB.CheckRecord(record)), true, "at the limit")
    record.builds["1.60.1"]["1415:3:47"].t = 361
    local ok, reason = CatchDB.CheckRecord(record)
    eq(ok, false, "one second over")
    assert(reason:find("version steps", 1, true), reason)
end)

---------------------------------------------------------------------------
-- The store
---------------------------------------------------------------------------
test("the store refuses a newer version that does not continue the stored one", function()
    eq(Store.Accept(shared, other(3, 15), 100), "new", "stored")
    local result, reason = Store.Accept(shared, other(4, 16, "a forger"), 101)
    eq(result, "refused", "refused")
    assert(reason:find("^invalid: "), reason)
    eq(Store.Accept(shared, other(4, 16), 102), "newer", "the owner's version")
    eq(Store.Accept(shared, other(6, 18, "a forger"), 103, nil, true), "newer", "verified skips the check")
    shared.records["oooooooo@0"] = nil
end)

test("a merge walks a long chain over several frame steps, PROOF_STEPS links each, and keeps its place", function()
    local sent = {}
    local node = ns.Share.NewNode(shared, { now = GetTime, time = GetTime, after = C_Timer.After,
        send = function(_, text) table.insert(sent, text) end, broadcast = function() end,
        forEachFriend = function() end, canSend = function() return true end, absorbed = function() return {} end,
        seedEpoch = function() return 0 end, encode = ns.Share.Encode, decode = ns.Share.Decode })
    eq(Store.Accept(shared, other(3, 15), 100), "new", "held")
    node:Receive("w:X", "group", sum_text("xx"))
    node:Receive("w:X", "group", "Dxx " .. ns.BASE32 .. " oooooooo.0.203")
    node:Receive("w:X", "group", "Wxx")
    node:Receive("w:X", "group", "Rxx " .. ns.Share.Encode(other(203, 300)))
    local most, rounds = 0, 0
    while #node.merges > 0 do
        rounds = rounds + 1
        local count = steps(frameStep)
        most = math.max(most, count)
        assert(rounds < 20, "the merge ends")
    end
    assert(most <= 32, "at most PROOF_STEPS links per step: " .. most)
    assert(rounds >= 7, "200 links over several steps: " .. rounds)
    eq(shared.records["oooooooo@0"].seq, 203, "stored once checked")
    eq(node.peers["w:X"].ignored, nil, "an honest sender")
end)

test("a version that fails the chain is refused; its sender is ignored only when the seed's proof shows it wrong",
    function()
    local absorbed = {}
    local node = ns.Share.NewNode(shared, { now = GetTime, time = GetTime, after = C_Timer.After,
        send = function() end, broadcast = function() end, forEachFriend = function() end,
        canSend = function() return true end, absorbed = function() return absorbed end,
        seedEpoch = function() return 0 end, encode = ns.Share.Encode, decode = ns.Share.Decode })
    local function relay(address, sid, record)
        node:Receive(address, "group", sum_text(sid))
        node:Receive(address, "group", ("D%s %s oooooooo.0.%d"):format(sid, ns.BASE32, record.seq))
        node:Receive(address, "group", "W" .. sid)
        node:Receive(address, "group", "R" .. sid .. " " .. ns.Share.Encode(record))
        while #node.merges > 0 do
            frameStep()
        end
    end
    -- A made-up copy at seq 3, taken first: the owner's real version 10 does not continue it.
    shared.records["oooooooo@0"] = other(3, 15, "a forger")
    relay("w:Honest", "hh", other(10, 20))
    eq(shared.records["oooooooo@0"].seq, 3, "refused: the stored copy stays")
    eq(node.peers["w:Honest"].ignored, nil, "the relay is not blamed")
    eq(node:Wanted("oooooooo@0", 10), false, "that version is not wanted again while the copy is held")
    eq(node:Wanted("oooooooo@0", 11), true, "another one still is: the forgery may be the version, not the copy")
    shared.records["oooooooo@0"] = nil
    eq(node:Wanted("oooooooo@0", 10), true, "wanted again once the copy is gone")
    -- Against the seed's proof, a version that does not continue it is made up.
    absorbed.oooooooo = { [0] = 3 }
    ns.SeedData = { epoch = 1, absorbed = absorbed, resets = {}, cells = {},
        proofs = { oooooooo = { [0] = other(3, 15).proof } } }
    advance(200) -- the next session may start
    relay("w:Forger", "ff", other(10, 20, "a forger"))
    eq(shared.records["oooooooo@0"], nil, "refused")
    eq(node.peers["w:Forger"].ignored, true, "the sender is ignored")
    ns.SeedData = nil
end)

test("cleanup deletes other records without a valid proof, and copies that do not continue the seed's proof",
    function()
    shared.records["nnnnnnnn@0"] = { id = "nnnnnnnn", epoch = 0, seq = 1, seen = 1,
        builds = { ["1.60.1"] = { ["1415:3:47"] = catch_cell(2, 0) } } }
    eq(Store.CleanUp(shared), 1, "no proof: deleted")
    shared.records["oooooooo@0"] = other(6, 30, "a forger")
    shared.records["pppppppp@0"] = prove({ id = "pppppppp", epoch = 0, seq = 6,
        builds = { ["1.60.1"] = { ["1415:3:47"] = catch_cell(30, 0) } } }, "the owner", 512)
    ns.SeedData = { epoch = 1, absorbed = { oooooooo = { [0] = 3 }, pppppppp = { [0] = 3 } }, resets = {}, cells = {},
        proofs = { oooooooo = { [0] = other(3, 15).proof }, pppppppp = { [0] = proof_for("the owner", 3, 512) } } }
    local work = Store.SeedChainWork(shared)
    eq(#work, 2, "two copies to walk")
    eq(Store.CheckSeedChains(shared, work), true, "done")
    eq(shared.records["oooooooo@0"], nil, "the made-up copy went")
    eq(shared.records["pppppppp@0"].seq, 6, "the real one stays")
    ns.SeedData = nil
end)

test("until the walk reaches it, a copy the seed holds in part is not sent, nor what a newer version continues",
    function()
    shared.records["oooooooo@0"] = other(6, 30, "a forger")
    local absorbed = { oooooooo = { [0] = 3 } }
    ns.SeedData = { epoch = 1, absorbed = absorbed, resets = {}, cells = {},
        proofs = { oooooooo = { [0] = other(3, 15).proof } } }
    local sent = {}
    local node = ns.Share.NewNode(shared, { now = GetTime, time = GetTime, after = C_Timer.After,
        send = function(_, text) table.insert(sent, text) end, broadcast = function() end,
        forEachFriend = function() end, canSend = function() return true end, absorbed = function() return absorbed end,
        seedEpoch = function() return 1 end, encode = ns.Share.Encode, decode = ns.Share.Decode })
    local work = Store.SeedChainWork(shared)
    eq(#work, 1, "one copy to walk")
    advance(200) -- the next session may start
    node:Receive("w:Y", "group", sum_text("yy"))
    node:Receive("w:Y", "group", "Dyy " .. ns.BASE32)
    node:Receive("w:Y", "group", "Wyy oooooooo@0")
    local records = 0
    for _, text in ipairs(sent) do
        if text:find("^Ryy") then
            records = records + 1
        end
    end
    assert(#sent > 0, "the session ran")
    eq(records, 0, "the unchecked copy is not sent")
    eq(Store.Accept(shared, other(8, 40, "a forger"), 200), "refused", "a newer made-up version meets the seed's proof")
    eq(shared.records["oooooooo@0"].seq, 6, "the copy is still there until the walk")
    eq(Store.CheckSeedChains(shared, work), true, "done")
    eq(shared.records["oooooooo@0"], nil, "the made-up copy went")
    eq(Store.Accept(shared, other(8, 40), 201), "new", "the owner's version continues the seed's proof")
    shared.records["oooooooo@0"] = nil
    ns.SeedData = nil
end)
