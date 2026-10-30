-- Share.lua: the store of other players' records (accept, replace, absorbed, eviction) and the bucket hashes.
-- The tests run in order and share one login.

local FISH = 6291
local A, B, C = "aaaaaaaa", "baaaaaab", "caaaaaac"

OneKeyFishingDB = { shareNotice = true }
load_addon()

local Store = ns.Share.Store
local shared = ns.db.shared

local changes = 0
ns.On("SHARED_DATA_CHANGED", function() changes = changes + 1 end)

-- A record with one cell (`places` cells on map 3000 + i when given), with at least as many casts as its seq; a big
-- one gets the seq its casting needs (never more than CatchDB.STEP_SECONDS per step).
local function rec(id, epoch, seq, places)
    local cells = { ["1415:3:47"] = catch_cell(math.max(2, seq), 1, { [FISH] = { 2, 2 } }) }
    local seconds = cells["1415:3:47"].t
    for i = 2, places or 1 do
        cells[(3000 + i) .. ":0:x"] = catch_cell(1, 0)
        seconds = seconds + cells[(3000 + i) .. ":0:x"].t
    end
    seq = math.max(seq, math.ceil(seconds / ns.CatchDB.STEP_SECONDS))
    return prove({ id = id, epoch = epoch, seq = seq, builds = { ["1.60.1"] = cells } }, nil, 4096)
end

---------------------------------------------------------------------------
-- Store
---------------------------------------------------------------------------
test("a valid record is stored under <id>@<epoch> with the time it was seen", function()
    changes = 0
    eq(Store.Accept(shared, rec(A, 1, 3), 5000), "new", "result")
    local stored = shared.records[A .. "@1"]
    eq(stored.seq, 3, "seq")
    eq(stored.seen, 5000, "seen")
    eq(changes, 1, "one change message")
end)

test("a higher seq replaces, an equal one refreshes seen, a lower one is ignored", function()
    changes = 0
    eq(Store.Accept(shared, rec(A, 1, 5), 5100), "newer", "higher")
    eq(shared.records[A .. "@1"].seq, 5, "replaced")
    eq(Store.Accept(shared, rec(A, 1, 5), 5200), "same", "equal")
    eq(shared.records[A .. "@1"].seen, 5200, "seen refreshed")
    eq(Store.Accept(shared, rec(A, 1, 4), 5300), "older", "lower")
    eq(shared.records[A .. "@1"].seq, 5, "kept")
    eq(shared.records[A .. "@1"].seen, 5200, "seen unchanged by an older copy")
    eq(changes, 1, "only the replacement changed the data")
end)

test("another epoch of the same ID is stored next to it", function()
    eq(Store.Accept(shared, rec(A, 2, 1), 5400), "new", "result")
    assert(shared.records[A .. "@1"] and shared.records[A .. "@2"], "both epochs")
end)

test("the own ID and a failing record are refused", function()
    changes = 0
    eq(Store.Accept(shared, rec(shared.myID, 9, 1), 5500), "refused", "own ID")
    local bad = rec(B, 1, 1)
    bad.builds["1.60.1"]["1415:3:47"].c = 999
    eq(Store.Accept(shared, bad, 5500), "refused", "impossible cell")
    eq(shared.records[B .. "@1"], nil, "not stored")
    eq(changes, 0, "no change")
end)

test("only part 1 fields are kept: nothing a peer adds reaches the saved data", function()
    local extra = rec(C, 1, 1)
    extra.name = "Someone"
    extra.builds["1.60.1"]["1415:3:47"].note = "junk"
    eq(Store.Accept(shared, extra, 5600), "new", "accepted")
    local stored = shared.records[C .. "@1"]
    eq(stored.name, nil, "no extra record field")
    eq(stored.builds["1.60.1"]["1415:3:47"].note, nil, "no extra cell field")
    eq(Store.ForSending(stored).seen, nil, "seen is not sent")
end)

test("a unit the seed holds whole is refused and deleted at cleanup", function()
    local absorbed = { [A] = { [1] = 9 } }
    eq(Store.Accept(shared, rec(A, 1, 9), 5700, absorbed), "refused", "seq 9 is in the seed")
    changes = 0
    eq(Store.CleanUp(shared, absorbed), 1, "one unit removed")
    eq(shared.records[A .. "@1"], nil, "A@1 (seq 5) gone")
    assert(shared.records[A .. "@2"], "A@2 is not in the seed: kept")
    eq(changes, 1, "one change message")
end)

test("a newer seq of a unit the seed holds in part is kept, offered and kept at cleanup", function()
    local absorbed = { [A] = { [1] = 9 } }
    eq(Store.Accept(shared, rec(A, 1, 12), 5750, absorbed), "new", "seq 12: the seed has only up to 9")
    eq(Store.CleanUp(shared, absorbed), 0, "kept: the rest goes to the next harvest")
    eq(Store.Units(shared, absorbed)[A .. "@1"], 12, "offered")
    shared.records[A .. "@1"] = nil
    ns.Fire("SHARED_DATA_CHANGED", { A .. "@1" })
end)

test("Units lists every held unit with its seq, the own one included when it has data", function()
    local units = Store.Units(shared, {})
    eq(units[A .. "@2"], 1, "A@2")
    eq(units[C .. "@1"], 1, "C@1")
    local own = shared.records[shared.myID]
    eq(units[shared.myID .. "@" .. own.epoch], nil, "an empty own record is not offered")
    own.builds["1.60.1"] = { ["1415:3:47"] = catch_cell(1, 0) }
    units = Store.Units(shared, {})
    eq(units[shared.myID .. "@" .. own.epoch], own.seq, "own record")
    eq(Store.Get(shared, shared.myID .. "@" .. own.epoch), own, "Get finds the own record")
    eq(Store.Get(shared, C .. "@1"), shared.records[C .. "@1"], "Get finds another record")
    eq(Store.Units(shared, { [C] = { [1] = 1 } })[C .. "@1"], nil, "units the seed holds whole are left out")
end)

test("eviction deletes the oldest seen first until 20000 places fit, never a record of the own ID", function()
    local own = shared.records[shared.myID]
    local kept = { id = shared.myID, epoch = 7, seq = 1, seen = 1, -- frozen by a roll, seen longest ago
        builds = { ["1.60.1"] = { ["1415:3:47"] = catch_cell(1, 0) } } }
    shared.records[shared.myID .. "@7"] = kept
    for i = 1, 30 do
        own.builds["1.60.1"][(5000 + i) .. ":0:x"] = catch_cell(1, 0)
    end
    for i, id in ipairs({ "daaaaaaa", "eaaaaaaa", "faaaaaaa" }) do
        local big = rec(id, 1, 1, 1000)
        eq(Store.Accept(shared, big, 1000 + i), "new", id)
        -- Make them big without going through CheckRecord's 1000-place limit.
        for j = 1, 6000 do
            shared.records[id .. "@1"].builds["1.60.1"][(10000 + j) .. ":1:x"] = catch_cell(1, 0)
        end
    end
    changes = 0
    local removed = Store.Evict(shared)
    eq(removed, 1, "one record is enough")
    eq(shared.records["daaaaaaa@1"], nil, "the oldest seen went")
    assert(shared.records["eaaaaaaa@1"] and shared.records["faaaaaaa@1"], "the others stay")
    assert(shared.records[shared.myID], "own record stays")
    eq(shared.records[shared.myID .. "@7"], kept, "the own frozen record stays though it was seen first")
    eq(changes, 1, "one change message")
end)

test("eviction by new information: well-known places first, then stale, then the rest, rare places last", function()
    for key, record in pairs(shared.records) do
        if key:find("@", 1, true) and record.id ~= shared.myID then
            shared.records[key] = nil -- the records of the tests above
        end
    end
    -- 500 places per map: map 20 well known in the seed, 21 neither, 22 with little data.
    local function key(map, j)
        return ("%d:%d:%02d"):format(map, math.floor((j - 1) / 100) % 5, (j - 1) % 100)
    end
    local cells = {}
    for j = 1, 500 do
        cells[key(20, j)] = { c = 2000, m = 0, t = 20000, k = 9, i = {} }
        cells[key(21, j)] = { c = 200, m = 0, t = 2000, k = 3, i = {} }
        cells[key(22, j)] = { c = 10, m = 0, t = 100, k = 1, i = {} }
    end
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = cells }
    local function big(id, map, seen)
        local record = { id = id, epoch = 1, seq = 30, seen = seen, proof = ("a"):rep(16),
            builds = { ["1.60.1"] = {} } }
        for j = 1, 500 do
            record.builds["1.60.1"][key(map, j)] = catch_cell(1, 0)
        end
        shared.records[id .. "@1"] = record
    end
    local now = time()
    big("gaaaaaaa", 22, 10) -- D: rare places, though seen longest ago
    big("haaaaaaa", 21, now - 61 * 86400) -- B: stale
    big("iaaaaaaa", 21, now - 3600) -- C
    big("jaaaaaaa", 20, now) -- A: well-known places, though seen last
    local fillers = 0
    local function filler() -- class D, the newest: goes after all four
        fillers = fillers + 1
        big("y" .. ns.Base32(fillers, 7), 22, now + fillers)
    end
    for _ = 1, 35 do
        filler()
    end
    eq(Store.Evict(shared), 0, "19,500 places and the own frozen record: nothing to do")
    local order = {}
    for _ = 1, 4 do
        filler()
        eq(Store.Evict(shared), 1, "500 places over: one record")
        for _, id in ipairs({ "jaaaaaaa", "haaaaaaa", "iaaaaaaa", "gaaaaaaa" }) do
            if not shared.records[id .. "@1"] and not order[id] then
                order[id] = true
                table.insert(order, id)
            end
        end
    end
    eq(table.concat(order, " "), "jaaaaaaa haaaaaaa iaaaaaaa gaaaaaaa", "A, B, C, then D")
    ns.SeedData = nil
end)

---------------------------------------------------------------------------
-- Hashes
---------------------------------------------------------------------------
local Share = ns.Share

test("the hash is the polynomial rule modulo 4294967291, computed by hand", function()
    eq(Share.Hash(""), 5381, "empty")
    eq(Share.Hash("abc"), 160401725, "abc")
    eq(Share.Hash("abcde"), 3822205741, "abcde: the modulo applies")
    eq(Share.Hash("the quick brown fox"), 961733640, "longer text")
end)

test("Base32 pads to the width with the ID alphabet", function()
    eq(ns.Base32(0, 7), "aaaaaaa", "zero")
    eq(ns.Base32(33, 2), "bb", "33 = 1 * 32 + 1")
    eq(#ns.Base32(4294967290, 7), 7, "the largest hash fits 7 characters")
end)

test("a unit goes into the bucket of its ID's first character, lines sorted", function()
    local buckets = Share.Buckets({ ["baaaaaaa@1"] = 3, ["aaaaaaab@2"] = 1, ["aaaaaaaa@1"] = 4 })
    eq(#buckets, 32, "32 buckets")
    eq(table.concat(buckets[1], " "), "aaaaaaaa.1.4 aaaaaaab.2.1", "bucket a")
    eq(table.concat(buckets[2], " "), "baaaaaaa.1.3", "bucket b")
    eq(#buckets[32], 0, "bucket 7 empty")
end)

test("bucket hashes do not depend on order; one seq change changes one bucket and the whole hash", function()
    local one, two = {}, {}
    local ids = { "aaaaaaaa@1", "baaaaaaa@1", "qaaaaaaa@3", "7aaaaaaa@1" }
    for i, unit in ipairs(ids) do
        one[unit] = i
    end
    for i = #ids, 1, -1 do
        two[ids[i]] = i
    end
    local h1, h2 = Share.BucketHashes(Share.Buckets(one)), Share.BucketHashes(Share.Buckets(two))
    for i = 1, 32 do
        eq(h1[i], h2[i], "bucket " .. i)
    end
    eq(Share.WholeHash(h1), Share.WholeHash(h2), "whole hash")
    two["qaaaaaaa@3"] = 9
    local h3 = Share.BucketHashes(Share.Buckets(two))
    local changed = 0
    for i = 1, 32 do
        if h1[i] ~= h3[i] then
            changed = changed + 1
        end
    end
    eq(changed, 1, "one bucket")
    assert(Share.WholeHash(h3) ~= Share.WholeHash(h1), "whole hash changed")
end)

---------------------------------------------------------------------------
-- The block list (specs/004-public-channel-sync, FR-019, FR-020)
---------------------------------------------------------------------------
test("a blocked ID is refused without blame, cleaned up, not wanted, not offered; unblocked it comes back", function()
    local X = "xaaaaaa2"
    eq(Store.Accept(shared, rec(X, 1, 2), 9000), "new", "stored before the release")
    ns.SeedData = { epoch = 2, absorbed = {}, resets = {}, cells = {}, blocked = { [X] = true } }
    local result, reason = Store.Accept(shared, rec(X, 1, 3), 9001)
    eq(result, "refused", "refused")
    eq(reason, "blocked", "as blocked: the merge does not blame the sender")
    eq(Store.Units(shared)[X .. "@1"], nil, "not offered")
    local node = ns.Share.NewNode(shared, { now = GetTime, time = GetTime, after = C_Timer.After,
        send = function() end, broadcast = function() end, forEachFriend = function() end,
        canSend = function() return true end, absorbed = function() return {} end,
        seedEpoch = function() return 0 end, encode = ns.Share.Encode, decode = ns.Share.Decode })
    eq(node:Wanted(X .. "@1", 5), false, "not wanted")
    eq(Store.CleanUp(shared), 1, "deleted at login")
    eq(shared.records[X .. "@1"], nil, "gone")
    ns.SeedData = { epoch = 3, absorbed = {}, resets = {}, cells = {}, blocked = {} }
    eq(Store.Accept(shared, rec(X, 1, 3), 9002), "new", "a later release unblocks it")
    ns.SeedData = nil
end)

test("an own blocked ID still counts for the player but is not offered", function()
    local node = ns.Share.NewNode(shared, { now = GetTime, time = GetTime, after = C_Timer.After,
        send = function() end, broadcast = function() end, forEachFriend = function() end,
        canSend = function() return true end, absorbed = function() return {} end,
        seedEpoch = function() return 0 end, encode = ns.Share.Encode, decode = ns.Share.Decode })
    ns.SeedData = { epoch = 3, absorbed = {}, resets = {}, cells = {}, blocked = { [shared.myID] = true } }
    local data, problem = node:OwnData(shared.records[shared.myID])
    eq(data, false, "not offered")
    eq(problem, "blocked by the bundled data", "why")
    ns.SeedData = nil
end)
