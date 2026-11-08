-- Share.lua and ShareProtocol.lua: the proof step budget (specs/010-exchange-forever-fixes US3, contracts P1-P3). A
-- version chain is walked in chunks of PROOF_CHUNK links until PROOF_BUDGET_MS have passed in a frame step, at least
-- one chunk, and exactly one without a clock; the login check of the seed's copies follows the same rule.

local FISH = 6291
player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
load_addon()

local Store, P = ns.Share.Store, ns.Share.private
local shared = ns.db.shared
local CHUNK = P.PROOF_CHUNK

-- Another player's record at `seq` with `catches` catches (10 s each), its proof from `secret`.
local function other(seq, catches, secret)
    return prove({ id = "oooooooo", epoch = 0, seq = seq,
        builds = { ["1.60.1"] = { ["1415:3:47"] = catch_cell(catches, 0, { [FISH] = { catches, catches } }) } } },
        secret or "the owner", 512)
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

-- A clock whose every read is 1 ms later.
local function TickingClock()
    local ms = 0
    return function()
        ms = ms + 1
        return ms
    end
end

-- A node with a 40-link walk queued: the held seq 3, a record at seq 43 received from w:X.
local function NodeWithWalk(clock)
    shared.records["oooooooo@0"] = nil
    local node = ns.Share.NewNode(shared, { now = GetTime, time = GetTime, after = C_Timer.After,
        send = function() end, broadcast = function() end, clock = clock,
        forEachFriend = function() end, canSend = function() return true end, absorbed = function() return {} end,
        seedEpoch = function() return 0 end, encode = ns.Share.Encode, decode = ns.Share.Decode })
    eq(Store.Accept(shared, other(3, 15), 100), "new", "held")
    node:Receive("w:X", "group", sum_text("xx"))
    node:Receive("w:X", "group", "Dxx " .. ns.BASE32 .. " oooooooo.0.43")
    node:Receive("w:X", "group", "Wxx")
    node:Receive("w:X", "group", "Rxx " .. ns.Share.Encode(other(43, 100)))
    eq(#node.merges, 1, "one record queued")
    node:MergeOne() -- the decode and the first check: starts the walk
    return node
end

-- Runs MergeOne until the queue is empty; returns the calls and the most links one call walked.
local function Finish(node)
    local calls, most = 0, 0
    while #node.merges > 0 do
        calls = calls + 1
        most = math.max(most, steps(function() node:MergeOne() end))
        assert(calls < 100, "the walk ends")
    end
    return calls, most
end

test("a chunk is 4 links and the budget 4 ms", function()
    eq(CHUNK, 4, "PROOF_CHUNK")
    eq(P.PROOF_BUDGET_MS, 4, "PROOF_BUDGET_MS")
    eq(P.PROOF_STEPS, nil, "the old fixed step is gone")
end)

test("with a clock, a frame step walks chunks until the budget is spent, and the walk ends stored", function()
    local node = NodeWithWalk(TickingClock())
    local links = steps(function() node:MergeOne() end)
    assert(links >= CHUNK and links <= 4 * CHUNK, "4 to 16 links in one step: " .. links)
    Finish(node)
    eq(shared.records["oooooooo@0"].seq, 43, "stored once checked, as without the budget")
    eq(node.peers["w:X"].ignored, nil, "an honest sender")
end)

test("a frame step stops before a chunk that would pass the budget, judged by the last chunk's time", function()
    local ms = 0
    local node = NodeWithWalk(function() ms = ms + 1.5 return ms end) -- each chunk takes 1.5 ms
    -- 1.5 ms, then 3 ms: a third chunk (to 4.5 ms) would pass the 4 ms budget
    eq(steps(function() node:MergeOne() end), 2 * CHUNK, "two chunks, not three")
end)

test("without a clock, exactly one chunk per frame step", function()
    local node = NodeWithWalk(nil)
    local calls, most = Finish(node)
    eq(most, CHUNK, "one chunk per step")
    eq(calls, 10, "40 links in 10 steps (4096 links: 1024)")
    eq(shared.records["oooooooo@0"].seq, 43, "stored")
end)

test("a slow clock still walks one chunk per frame step", function()
    local ms = 0
    local node = NodeWithWalk(function() ms = ms + 100 return ms end)
    eq(steps(function() node:MergeOne() end), CHUNK, "one chunk although the budget is spent at once")
end)

test("the login check of the seed's copies walks in chunks within the budget", function()
    shared.records["oooooooo@0"] = other(43, 100)
    ns.SeedData = { epoch = 1, absorbed = { oooooooo = { [0] = 3 } }, resets = {}, cells = {},
        proofs = { oooooooo = { [0] = other(3, 15).proof } } }
    local work = Store.SeedChainWork(shared)
    eq(#work, 1, "one copy to walk")
    local done
    eq(steps(function() done = Store.CheckSeedStep(shared, work, nil) end), CHUNK, "one chunk without a clock")
    eq(done, false, "more to walk")
    local clock = TickingClock()
    local links = steps(function() done = Store.CheckSeedStep(shared, work, clock) end)
    assert(links > CHUNK and links <= 4 * CHUNK, "several chunks within the budget: " .. links)
    local calls = 0
    while not done do
        calls = calls + 1
        done = Store.CheckSeedStep(shared, work, nil)
        assert(calls < 20, "the check ends")
    end
    eq(shared.records["oooooooo@0"].seq, 43, "the real copy stays")
    ns.SeedData = nil
end)
