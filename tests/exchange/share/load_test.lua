-- Share.lua and CatchDB.lua with a full store: 200 other records, 20,000 places together. The times are printed
-- for information only; the real check is V16 in game (specs/003-guild-group-sync/verification.md).

local FISH, OTHER = 6291, 6303

-- An 8-character base32 ID for a number (Data.lua is loaded by then).
local function ID(n)
    return ns.Base32(n, 8)
end

local started, loadTime
load_addon(function()
    local records = {}
    for r = 1, 200 do
        local cells = {}
        for p = 1, 100 do
            -- 100 distinct places per record: 100 maps, the record number in the cell
            cells[(6000 + p) .. ":" .. (r % 5) .. ":" .. ("%02d"):format(r % 100)] =
                catch_cell(5, 1, { [FISH] = { 3, 3 }, [OTHER] = { 2, 4 } })
        end
        local id = ID(1000 + r)
        records[id .. "@0"] = { id = id, epoch = 0, seq = 1, seen = r, proof = ("a"):rep(16),
            builds = { ["1.60.1"] = cells } }
    end
    OneKeyFishingDB = { shareNotice = true, shared = { mine = {}, records = records } }
    started = os.clock()
end)
loadTime = os.clock() - started

local Share, Store = ns.Share, ns.Share.Store
local ALL = { range = "all", source = "all" }

test("login with 20,000 stored places: cleanup and eviction finish and keep everything", function()
    print(("    login with 20,000 places: %.3f s"):format(loadTime))
    local count = 0
    for key in pairs(ns.db.shared.records) do
        count = count + (key:find("@", 1, true) and 1 or 0)
    end
    eq(count, 200, "at the limit, nothing evicted")
end)

test("a query for a busy map and for an empty map returns", function()
    started = os.clock()
    local busy = ns.CatchDB.Query(6010, "11", ALL)
    local busyTime = os.clock() - started
    started = os.clock()
    local empty = ns.CatchDB.Query(7000, "11", ALL)
    print(("    busy map query: %.3f s, empty map query: %.3f s"):format(busyTime, os.clock() - started))
    assert(busy.catches > 0, "the busy map has catches")
    assert(busy.players > 1, "from several players")
    eq(empty.scope, "none", "the empty map")
end)

test("a full session's records merge one per frame step", function()
    advance(0) -- the own record's version chain is built in frame steps after the login: done before counting
    local node = Share.NewNode(ns.db.shared, {
        now = GetTime, time = GetTime, after = function(delay, fn) C_Timer.After(delay, fn) end,
        send = function() end, broadcast = function() end, forEachFriend = function() end,
        canSend = function() return true end, absorbed = function() return {} end,
        seedEpoch = function() return 0 end, encode = Share.Encode, decode = Share.Decode,
    })
    node:Receive("w:X", "group", sum_text("xx"))
    local units, entries, data = {}, {}, {}
    for r = 1, 8 do
        local id = ID(5000 + r)
        local cells = {}
        for p = 1, 10 do
            cells[(6100 + p) .. ":2:x"] = catch_cell(4, 0, { [FISH] = { 4, 4 } })
        end
        table.insert(units, id)
        table.insert(entries, id .. ".0.3")
        table.insert(data, Share.Encode({ id = id, epoch = 0, seq = 3, proof = ("b"):rep(16),
            builds = { ["1.60.1"] = cells } }))
    end
    node:Receive("w:X", "group", "Dxx " .. ns.BASE32 .. " " .. table.concat(entries, " "))
    node:Receive("w:X", "group", "Wxx")
    for _, text in ipairs(data) do
        node:Receive("w:X", "group", "Rxx " .. text)
    end
    eq(#node.merges, 8, "queued")
    local longest = 0
    for step = 1, 8 do
        local index
        for i, timer in ipairs(timers) do
            if timer.at <= GetTime() then
                index = i
                break
            end
        end
        assert(index, "a frame step is due")
        started = os.clock()
        table.remove(timers, index).fn()
        longest = math.max(longest, os.clock() - started)
        eq(#node.merges, 8 - step, "one record per step")
    end
    print(("    longest merge step with 20,000 stored places: %.4f s"):format(longest))
    for _, id in ipairs(units) do
        assert(ns.db.shared.records[id .. "@0"], id)
    end
    local count = 0
    for key in pairs(ns.db.shared.records) do
        count = count + (key:find("@", 1, true) and 1 or 0)
    end
    assert(count < 208, "the oldest records made room: " .. count)
end)
