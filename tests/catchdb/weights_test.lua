-- CatchDB.lua: contribution weights in the views (specs/004-public-channel-sync, FR-013, SC-006, research R7).
-- The tests share one login; each uses a map of its own.

local FISH, RARE = 6291, 6303
OneKeyFishingDB = { shareNotice = true }
-- Every item of these tests is known from the seed (map 9999), so the new-item rule (FR-014) does not hide any.
load_addon(function()
    local items = { [FISH] = { 1, 1 }, [RARE] = { 1, 1 } }
    for itemID = 7001, 7005 do
        items[itemID] = { 1, 1 }
    end
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {},
        cells = { ["9999:0:x"] = { c = 7, m = 0, t = 70, k = 1, i = items } } }
end)

local CatchDB = ns.CatchDB
local shared = ns.db.shared
local SPOT = { range = 3, source = "all" }

-- Another player's contribution: `catches` catches (`withRare` of them with RARE, the rest with FISH) and `misses`
-- misses at <map>:3:11.
local function contribution(id, map, catches, withRare, misses)
    local items = { [RARE] = withRare > 0 and { withRare, withRare } or nil,
        [FISH] = catches > withRare and { catches - withRare, catches - withRare } or nil }
    shared.records[id .. "@0"] = { id = id, epoch = 0, seq = 1, seen = 1, proof = ("a"):rep(16),
        builds = { ["1.60.1"] = { [map .. ":3:11"] = catch_cell(catches, misses or 0, items) } } }
end

local function chance(view, itemID)
    for _, item in ipairs(view.items) do
        if item.itemID == itemID then
            return item.chance
        end
    end
    return 0
end

test("one made-up contribution moves a chance by at most 20 points at a spot with five or more (SC-006)", function()
    for i = 1, 6 do
        contribution(("b%07d"):format(i), 3100, 100, 5)
    end
    ns.Fire("SHARED_DATA_CHANGED")
    local before = CatchDB.Query(3100, "11", SPOT)
    near(chance(before, RARE), 0.05, "5% before")
    contribution("zzzzzzzz", 3100, 10000, 10000, 10000)
    ns.Fire("SHARED_DATA_CHANGED")
    local after = CatchDB.Query(3100, "11", SPOT)
    eq(after.players, 7, "seven contributions")
    assert(chance(after, RARE) - chance(before, RARE) <= 0.20 + 1e-9, "rise: " .. chance(after, RARE))
    near(chance(after, RARE), 180 / 750, "capped at a fifth: (30 + 150) / (600 + 150)")
    eq(after.catches, 10600, "the real number of catches")
    eq(after.misses, 10000, "the real number of misses")
    -- The miss rate is weighted by casts: the 20,000 casts are capped at a fifth, (600 + T) / 5 = T = 150.
    near(after.missRate, (10000 * 150 / 20000) / 750, "the miss rate from the sums weighted by casts")
end)

test("a contribution of few catches and many misses holds at most a fifth of the miss rate (FR-013)", function()
    for i = 1, 5 do
        contribution(("m%07d"):format(i), 3170, 100, 0, 20)
    end
    contribution("mzzzzzzz", 3170, 1, 0, 3000)
    ns.Fire("SHARED_DATA_CHANGED")
    local view = CatchDB.Query(3170, "11", SPOT)
    eq(view.players, 6, "six contributions")
    -- Casts: 5 x 120 and 3001. Capped at a fifth, (600 + T) / 5 = T = 150.
    near(view.missRate, (100 + 3000 * 150 / 3001) / 750, "a third, not 86%")
    eq(view.misses, 3100, "the real number of misses")
end)

test("a weighted seed cell's miss rate comes from its catches weighted by casts (x), its chances from c", function()
    ns.SeedData.cells["3180:3:11"] = { c = 500, m = 8600, x = 1400, t = 100000, k = 5, i = { [FISH] = { 500, 500 } } }
    ns.Fire("SHARED_DATA_CHANGED")
    local view = CatchDB.Query(3180, "11", SPOT)
    near(view.missRate, 8600 / 10000, "m / (x + m)")
    near(chance(view, FISH), 1, "the chance from c")
    ns.SeedData.cells["3180:3:11"] = nil
    ns.Fire("SHARED_DATA_CHANGED")
end)

test("a seed cell the harvest weighted counts its raw catches (r): no little data at a busy spot", function()
    -- 1020 real catches, one player capped: the weighted cell holds 25.
    ns.SeedData.cells["3190:3:11"] = { c = 25, m = 0, r = 1020, t = 10200, k = 5, i = { [FISH] = { 25, 25 } } }
    ns.Fire("SHARED_DATA_CHANGED")
    local view = CatchDB.Query(3190, "11", SPOT)
    eq(view.scope, "spot", "the spot, not the map")
    eq(view.littleData, false, "enough data")
    eq(view.catches, 1020, "the real number of catches")
    near(chance(view, FISH), 1, "the chance from c")
    ns.SeedData.cells["3190:3:11"] = nil
    ns.Fire("SHARED_DATA_CHANGED")
end)

test("under five contributions nothing is weighted", function()
    for i = 1, 3 do
        contribution(("c%07d"):format(i), 3110, 100, 5)
    end
    contribution("yyyyyyyy", 3110, 1000, 1000)
    ns.Fire("SHARED_DATA_CHANGED")
    local view = CatchDB.Query(3110, "11", SPOT)
    eq(view.players, 4, "four contributions")
    near(chance(view, RARE), 1015 / 1300, "plain sums")
end)

test("the own catch is never weighted, even when it is most of the spot", function()
    shared.records[shared.myID].builds["1.60.1"] = { ["3120:3:11"] = catch_cell(1000, 0, { [FISH] = { 1000, 1000 } }) }
    for i = 1, 5 do
        contribution(("d%07d"):format(i), 3120, 10, 10)
    end
    ns.Fire("SHARED_DATA_CHANGED")
    local view = CatchDB.Query(3120, "11", SPOT)
    eq(view.players, 6, "own and five others")
    near(chance(view, FISH), 1000 / 1050, "the own catch counts in full")
end)

test("the seed block is not weighted", function()
    ns.SeedData.cells["3130:3:11"] = { c = 10000, m = 0, t = 100000, k = 9, i = { [FISH] = { 10000, 10000 } } }
    contribution("eeeeeeee", 3130, 100, 100)
    ns.Fire("SHARED_DATA_CHANGED")
    local view = CatchDB.Query(3130, "11", SPOT)
    near(chance(view, FISH), 10000 / 10100, "the seed's sums count in full")
    ns.SeedData.cells["3130:3:11"] = nil
    ns.Fire("SHARED_DATA_CHANGED")
end)

test("five contributions that all hit the cap share the weight equally", function()
    local items = { 7001, 7002, 7003, 7004, 7005 }
    for i, catches in ipairs({ 1000, 2000, 3000, 4000, 5000 }) do
        local id = ("f%07d"):format(i)
        shared.records[id .. "@0"] = { id = id, epoch = 0, seq = 1, seen = 1, proof = ("a"):rep(16),
            builds = { ["1.60.1"] = { ["3140:3:11"] = catch_cell(catches, 0,
                { [items[i]] = { catches, catches } }) } } }
    end
    ns.Fire("SHARED_DATA_CHANGED")
    local view = CatchDB.Query(3140, "11", SPOT)
    for _, itemID in ipairs(items) do
        near(chance(view, itemID), 0.2, "a fifth each: " .. itemID)
    end
end)

test("the whole-map view weights the map's contributions the same way", function()
    for i = 1, 5 do
        local id = ("g%07d"):format(i)
        shared.records[id .. "@0"] = { id = id, epoch = 0, seq = 1, seen = 1, proof = ("a"):rep(16),
            builds = { ["1.60.1"] = { ["3150:3:" .. (10 + i)] = catch_cell(5, 0, { [FISH] = { 5, 5 } }) } } }
    end
    contribution("hhhhhhhh", 3150, 1000, 1000)
    ns.Fire("SHARED_DATA_CHANGED")
    local view = CatchDB.Query(3150, "99", SPOT)
    eq(view.scope, "map", "nothing at the spot")
    near(chance(view, RARE), (25 / 4) / (25 + 25 / 4), "the big one capped at a fifth of the map")
end)
