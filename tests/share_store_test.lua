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

-- A record with one cell (`places` cells on map 3000 + i when given).
local function rec(id, epoch, seq, places)
    local cells = { ["1415:3:47"] = catch_cell(2, 1, { [FISH] = { 2, 2 } }) }
    for i = 2, places or 1 do
        cells[(3000 + i) .. ":0:x"] = catch_cell(1, 0)
    end
    return { id = id, epoch = epoch, seq = seq, builds = { ["1.60.1"] = cells } }
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

test("a unit the seed absorbed is refused and deleted at cleanup", function()
    local absorbed = { [A] = 1 }
    eq(Store.Accept(shared, rec(A, 1, 9), 5700, absorbed), "refused", "absorbed epoch")
    changes = 0
    eq(Store.CleanUp(shared, absorbed), 1, "one unit removed")
    eq(shared.records[A .. "@1"], nil, "A@1 gone")
    assert(shared.records[A .. "@2"], "A@2 is newer than the seed: kept")
    eq(changes, 1, "one change message")
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
    eq(Store.Units(shared, { [C] = 1 })[C .. "@1"], nil, "absorbed units are left out")
end)

test("eviction deletes the oldest seen first until 20000 places fit, never the own record", function()
    local own = shared.records[shared.myID]
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
    eq(changes, 1, "one change message")
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
    eq(Share.Base32(0, 7), "aaaaaaa", "zero")
    eq(Share.Base32(33, 2), "bb", "33 = 1 * 32 + 1")
    eq(#Share.Base32(4294967290, 7), 7, "the largest hash fits 7 characters")
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
