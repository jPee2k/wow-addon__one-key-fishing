-- The camp bonus of a cast (specs/020-camp-buffs FR-004, research R3): the mask read at the cast's start counts when
-- the same mask is known at its settle; a buff that began or ended in the cast, or an unknown state, gives 0. A miss
-- settled a second after its cast stopped keeps its mask though the next cast started.

local RACK, HUT = 1280341, 1280342
player_map_id = 1415
fishing_rank = 100

load_addon()
local Camp = ns.Camp

local function start()
    ns.Fire("FISHING_CAST_START", 7620)
    return ns.GetFishingCastID()
end

local function stop()
    ns.Fire("FISHING_CAST_STOP", 7620)
end

local function rack(seconds)
    auras[RACK] = { expirationTime = GetTime() + seconds, duration = 3600 }
end

local function reset()
    auras, auras_restricted, in_combat = {}, false, false
    fire("UNIT_AURA", "player")
end

test("the Rack at the start and at the settle: mask 1, also when asked twice", function()
    reset()
    rack(600)
    fire("UNIT_AURA", "player")
    local id = start()
    advance(10)
    stop()
    eq(Camp.CastMask(id), 1, "first ask")
    eq(Camp.CastMask(id), 1, "second ask (another module)")
    advance(2)
end)

test("no buff: 0; both: 3", function()
    reset()
    local id = start()
    eq(Camp.CastMask(id), 0, "no buff")
    rack(600)
    auras[HUT] = { expirationTime = GetTime() + 600, duration = 3600 }
    fire("UNIT_AURA", "player")
    id = start()
    eq(Camp.CastMask(id), 3, "both")
end)

test("the buff ends between the start and the settle: 0", function()
    reset()
    rack(5)
    fire("UNIT_AURA", "player")
    local id = start()
    advance(10)
    eq(Camp.CastMask(id), 0, "ended in the cast")
end)

test("the buff is granted after the start: 0", function()
    reset()
    local id = start()
    rack(600)
    fire("UNIT_AURA", "player")
    eq(Camp.CastMask(id), 0, "granted in the cast")
end)

test("the state unknown at the start: 0, also when known at the settle", function()
    load_addon(function()
        auras_restricted = true
    end)
    Camp = ns.Camp
    rack(600)
    local id = start()
    eq(Camp.Mask(), nil, "unknown")
    auras_restricted = false
    fire("UNIT_AURA", "player")
    eq(Camp.Mask(), 1, "known now")
    eq(Camp.CastMask(id), 0, "unknown at the start")
end)

test("a cast ID that never started: 0", function()
    eq(Camp.CastMask(99999), 0, "never started")
end)

test("a miss after a quick recast keeps its mask", function()
    reset()
    rack(600)
    fire("UNIT_AURA", "player")
    local n = start()
    advance(10)
    stop()
    local next = start()
    eq(Camp.CastMask(n), 1, "cast N after N+1 started")
    eq(Camp.CastMask(next), 1, "cast N+1")
    eq(Camp.CastMask(n), 0, "N dropped once N+1 settled")
end)

test("masks older than eight casts are dropped", function()
    reset()
    rack(600)
    fire("UNIT_AURA", "player")
    local first = start()
    for _ = 1, 10 do
        start()
    end
    eq(Camp.CastMask(first), 0, "ten casts later")
    eq(Camp.CastMask(first + 3), 1, "a kept mask of eight casts back")
end)

test("IsBonusCatch: a known item of one of the mask's bonuses", function()
    eq(Camp.IsBonusCatch(1, { { itemID = 6643, quantity = 1 } }), true, "a Bloated fish under the Rack")
    eq(Camp.IsBonusCatch(3, { { itemID = 6291, quantity = 1 }, { itemID = 6643, quantity = 1 } }), true, "mask 3")
    eq(Camp.IsBonusCatch(2, { { itemID = 6643, quantity = 1 } }), false, "under the Hut only")
    eq(Camp.IsBonusCatch(0, { { itemID = 6643, quantity = 1 } }), false, "no bonus")
    eq(Camp.IsBonusCatch(1, { { itemID = 6291, quantity = 1 } }), false, "an ordinary fish")
end)
