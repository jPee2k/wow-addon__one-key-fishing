-- A cast under a camp bonus is written into its place's part (specs/020-camp-buffs FR-005, FR-006, FR-009, research
-- R4): the totals grow as before, and the part of the cast's mask, keyed by the mask as a string, grows too.

local FISH, BLOATED = 6291, 6643
local RACK, HUT = 1280341, 1280342

player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
load_addon()

local KEY = "1415:3:47"

local function mine()
    return ns.db.shared.mine[KEY]
end

local function own()
    local shared = ns.db.shared
    return shared.records[shared.myID].builds["1.60.1"][KEY]
end

local function buffs(rack, hut)
    auras = {}
    if rack then
        auras[RACK] = { expirationTime = GetTime() + 3000, duration = 3600 }
    end
    if hut then
        auras[HUT] = { expirationTime = GetTime() + 3000, duration = 3600 }
    end
    fire("UNIT_AURA", "player")
end

test("a catch under the Rack: the totals and the part \"1\"", function()
    buffs(true)
    fish_cast({ { BLOATED, 1 }, { FISH, 2 } })
    for name, cell in pairs({ mine = mine(), record = own() }) do
        eq(cell.c, 1, name .. " catches")
        eq(cell.i[BLOATED][1], 1, name .. " item")
        local part = cell.q and cell.q["1"]
        assert(part, name .. " has the part")
        eq(part.c, 1, name .. " part catches")
        eq(part.m, 0, name .. " part misses")
        eq(part.i[BLOATED][1], 1, name .. " part item catches")
        eq(part.i[FISH][2], 2, name .. " part item pieces")
        eq(cell.q[1], nil, name .. " no number key")
    end
end)

test("a miss under the Rack: m and the part's m", function()
    fish_cast(nil)
    eq(own().m, 1, "misses")
    eq(own().q["1"].m, 1, "part misses")
    eq(mine().q["1"].m, 1, "mine part misses")
end)

test("a miss settled after the next cast started stays in the part", function()
    ns.Fire("FISHING_CAST_START", 7620)
    advance(10)
    ns.Fire("FISHING_CAST_STOP", 7620)
    ns.Fire("FISHING_CAST_START", 7620) -- a quick recast before the miss settles
    advance(2)
    eq(own().m, 2, "misses")
    eq(own().q["1"].m, 2, "part misses")
    advance(10)
    ns.Fire("FISHING_CAST_STOP", 7620)
    advance(2)
    eq(own().q["1"].m, 3, "the recast's miss too")
end)

test("two catches of one item under the Rack", function()
    fish_cast({ { BLOATED, 1 } })
    eq(own().q["1"].i[BLOATED][1], 2, "catches")
    eq(own().q["1"].i[BLOATED][2], 2, "pieces")
end)

test("a catch without a buff: the totals only, the part unchanged", function()
    buffs(false)
    local before = own().q["1"].c
    fish_cast({ { FISH, 1 } })
    eq(own().c, 3, "catches")
    eq(own().q["1"].c, before, "part unchanged")
end)

test("a fresh cell without a buff has no q", function()
    player_map_position = { 0.11, 0.11 }
    fish_cast({ { FISH, 1 } })
    local cell = ns.db.shared.mine["1415:3:11"]
    eq(cell.c, 1, "catch")
    eq(cell.q, nil, "no q")
    player_map_position = { 0.43, 0.78 }
end)

test("both buffs: only the part \"3\" grows", function()
    buffs(true, true)
    local rack = own().q["1"].c
    fish_cast({ { FISH, 1 } })
    eq(own().q["3"].c, 1, "part 3")
    eq(own().q["1"].c, rack, "part 1 unchanged")
    eq(own().q["2"], nil, "no part 2")
end)

test("a buff that ends in the cast writes the totals only", function()
    auras = { [RACK] = { expirationTime = GetTime() + 5, duration = 3600 } }
    fire("UNIT_AURA", "player")
    local c, q1, q3 = own().c, own().q["1"].c, own().q["3"].c
    fish_cast({ { FISH, 1 } })
    eq(own().c, c + 1, "catches")
    eq(own().q["1"].c, q1, "part 1")
    eq(own().q["3"].c, q3, "part 3")
end)
