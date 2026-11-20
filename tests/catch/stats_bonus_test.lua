-- The camp bonus in the statistics (specs/020-camp-buffs FR-034, research R12): casts with a camp bonus and bonus
-- catches in the session, the current zone and the total; a saved bucket without the fields reads 0.

local FISH, BLOATED = 6291, 6643
local RACK = 1280341

player_map_id = 1415
fishing_rank = 100
load_addon()

local Stats = ns.Stats

local function buckets()
    return { session = Stats.GetSession(), zone = Stats.GetCurrentZone(), total = Stats.GetTotal() }
end

local function each(field, expected, what)
    for name, bucket in pairs(buckets()) do
        eq(bucket[field] or 0, expected, what .. " (" .. name .. ")")
    end
end

local function rack(on)
    auras[RACK] = on and { expirationTime = GetTime() + 3000, duration = 3600 } or nil
    fire("UNIT_AURA", "player")
end

test("a catch and a miss under the Rack: two casts with a camp bonus", function()
    rack(true)
    fish_cast({ { FISH, 1 } })
    fish_cast(nil)
    each("bonusCasts", 2, "bonus casts")
    each("bonusCatches", 0, "an ordinary fish is no bonus catch")
end)

test("a miss settled after the next cast started still counts", function()
    ns.Fire("FISHING_CAST_START", 7620)
    advance(10)
    ns.Fire("FISHING_CAST_STOP", 7620)
    ns.Fire("FISHING_CAST_START", 7620)
    advance(2)
    each("bonusCasts", 3, "the late miss")
    advance(10)
    ns.Fire("FISHING_CAST_STOP", 7620)
    advance(2)
    each("bonusCasts", 4, "the recast")
end)

test("a catch with a known item under the Rack is one bonus catch, also with two known items", function()
    fish_cast({ { BLOATED, 1 }, { FISH, 1 } })
    each("bonusCatches", 1, "one")
    fish_cast({ { BLOATED, 1 }, { 6644, 1 } })
    each("bonusCatches", 2, "two known items: still one catch")
end)

test("a known item with mask 0 adds nothing", function()
    rack(false)
    fish_cast({ { BLOATED, 1 } })
    each("bonusCatches", 2, "no buff")
    each("bonusCasts", 6, "no bonus cast")
end)

test("a saved bucket without the fields reads 0 and counts on", function()
    local total = Stats.GetTotal()
    total.bonusCasts, total.bonusCatches = nil, nil
    rack(true)
    fish_cast({ { BLOATED, 1 } })
    eq(total.bonusCasts, 1, "counted on from 0")
    eq(total.bonusCatches, 1, "counted on from 0")
    eq(#take_errors(), 0, "no error")
end)

test("a session reset zeroes them", function()
    Stats.ResetSession()
    eq(Stats.GetSession().bonusCasts, 0, "casts")
    eq(Stats.GetSession().bonusCatches, 0, "catches")
end)
