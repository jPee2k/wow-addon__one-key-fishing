-- The camp bonus state (specs/020-camp-buffs FR-001 to FR-003, FR-006, FR-008, research R2): a bonus is active, not
-- active or unknown from the player's aura, read by spell ID only while auras are not restricted; a buff that runs
-- out in a fight ends by the clock.

local RACK, HUT = 1280341, 1280342

local Camp

local function reset()
    auras, auras_restricted, in_combat = {}, false, false
end

local function enter()
    fire("PLAYER_ENTERING_WORLD", false, false)
end

test("no aura: not active, mask 0", function()
    load_addon()
    Camp = ns.Camp
    reset()
    enter()
    eq(Camp.IsActive("rack"), false, "Rack")
    eq(Camp.IsActive("hut"), false, "Hut")
    eq(Camp.Mask(), 0, "mask")
    eq(Camp.TimeLeft("rack"), nil, "no time left")
end)

test("the Rack's aura: active with its time left, mask 1", function()
    reset()
    auras[RACK] = { expirationTime = GetTime() + 600, duration = 3600 }
    enter()
    eq(Camp.IsActive("rack"), true, "Rack")
    near(Camp.TimeLeft("rack"), 600, "time left")
    eq(Camp.Mask(), 1, "mask")
end)

test("both auras give mask 3, the Hut's alone 2; the bits and the known items", function()
    reset()
    auras[RACK] = { expirationTime = GetTime() + 600, duration = 3600 }
    auras[HUT] = { expirationTime = GetTime() + 900, duration = 3600 }
    enter()
    eq(Camp.Mask(), 3, "both")
    auras[RACK] = nil
    enter()
    eq(Camp.Mask(), 2, "the Hut alone")
    eq(Camp.HasBit(3, "rack"), true, "3 holds the Rack")
    eq(Camp.HasBit(3, "hut"), true, "3 holds the Hut")
    eq(Camp.HasBit(2, "rack"), false, "2 does not hold the Rack")
    eq(Camp.HasBit(0, "rack"), false, "0 holds nothing")
    local known = Camp.KnownBonuses(6643)
    eq(#known, 2, "a Bloated fish: both bonuses")
    eq(known[1], "rack", "the Rack first (rank order)")
    eq(known[2], "hut", "then the Hut")
    eq(Camp.KnownBonuses(6291), nil, "an ordinary fish")
end)

test("restricted from the start: unknown, no mask", function()
    load_addon(function()
        auras_restricted = true
        auras[RACK] = { expirationTime = GetTime() + 600, duration = 3600 }
    end)
    Camp = ns.Camp
    eq(Camp.Read(), false, "no read while restricted")
    eq(Camp.IsActive("rack"), nil, "Rack unknown")
    eq(Camp.Mask(), nil, "mask unknown")
    eq(Camp.TimeLeft("rack"), nil, "no time left")
end)

test("a fight keeps the state read before it; the clock ends the buff", function()
    reset()
    auras[RACK] = { expirationTime = GetTime() + 100, duration = 3600 }
    enter()
    eq(Camp.IsActive("rack"), true, "active before the fight")
    in_combat, auras_restricted = true, true
    auras[RACK] = nil
    fire("UNIT_AURA", "player")
    eq(Camp.IsActive("rack"), true, "still active: no read in the fight")
    advance(101)
    eq(Camp.IsActive("rack"), false, "ended by the clock")
    eq(Camp.Mask(), 0, "mask 0")
end)

test("the fight's first moment, before the lockdown: the player's combat flag keeps the state", function()
    reset()
    auras[RACK] = { expirationTime = GetTime() + 600, duration = 3600 }
    enter()
    UnitAffectingCombat = function(unit) return unit == "player" end
    auras[RACK] = nil -- the aura call answers nothing already, the lockdown is not on yet
    fire("UNIT_AURA", "player")
    UnitAffectingCombat = nil
    eq(Camp.IsActive("rack"), true, "still active: no read with the combat flag set")
    eq(Camp.Mask(), 1, "mask 1")
end)

test("the fight's end reads again", function()
    reset()
    auras[RACK] = { expirationTime = GetTime() + 600, duration = 3600 }
    enter()
    in_combat, auras_restricted = true, true
    auras[RACK] = nil
    in_combat, auras_restricted = false, false
    eq(Camp.IsActive("rack"), true, "not read yet")
    fire("PLAYER_REGEN_ENABLED")
    eq(Camp.IsActive("rack"), false, "read at the fight's end")
end)

test("UNIT_AURA reads only for the player and never touches its payload", function()
    reset()
    enter()
    auras[RACK] = { expirationTime = GetTime() + 600, duration = 3600 }
    fire("UNIT_AURA", "target")
    eq(Camp.IsActive("rack"), false, "another unit: no read")
    local payload = setmetatable({}, { __index = function() error("the payload was read") end,
        __pairs = function() error("the payload was walked") end })
    fire("UNIT_AURA", "player", payload)
    eq(Camp.IsActive("rack"), true, "the player: read")
    eq(#take_errors(), 0, "no error")
end)

test("a secret expiration time is a failed read: the state stays", function()
    reset()
    enter()
    eq(Camp.IsActive("rack"), false, "not active")
    local secret = GetTime() + 600
    secret_values[secret] = true
    auras[RACK] = { expirationTime = secret, duration = 3600 }
    fire("UNIT_AURA", "player")
    eq(Camp.IsActive("rack"), false, "unchanged")
    secret_values[secret] = nil
end)

test("the module casts, uses and creates nothing (FR-008)", function()
    local source = assert(read_addon_file("Fishing/Camp.lua"), "Fishing/Camp.lua")
    for _, word in ipairs({ "CastSpell", "UseItem", "UseContainerItem", "SecureActionButton", "CreateFrame" }) do
        eq(source:find(word, 1, true), nil, word)
    end
end)

-- ns.RegisterUnitEvent (Core/Core.lua): UNIT_AURA fires for every unit around, so the event frame hears it for the
-- player only; a client without RegisterUnitEvent registers it for every unit and the handler keeps to the player.
local function UnitAuraRegistration()
    local registration
    for _, frame in ipairs(frames) do
        registration = frame.events.UNIT_AURA or registration -- the newest load's frame comes last
    end
    return registration
end

test("UNIT_AURA is registered for the player only", function()
    load_addon()
    Camp = ns.Camp
    local registration = UnitAuraRegistration()
    assert(type(registration) == "table", "a unit event, not one for every unit")
    eq(registration.player, true, "the player")
    eq(ns.CountKeys(registration), 1, "no other unit")
end)

test("without RegisterUnitEvent: registered for every unit, and another unit's aura change reads nothing", function()
    no_unit_events = true
    load_addon()
    no_unit_events = nil
    Camp = ns.Camp
    eq(UnitAuraRegistration(), true, "the plain registration")
    reset()
    enter()
    auras[RACK] = { expirationTime = GetTime() + 600, duration = 3600 }
    fire("UNIT_AURA", "target")
    eq(Camp.IsActive("rack"), false, "another unit: no read")
    fire("UNIT_AURA", "player")
    eq(Camp.IsActive("rack"), true, "the player: read")
end)

test("UNIT_AURA cannot also be registered for every unit or another unit", function()
    load_addon()
    local ok = pcall(ns.RegisterEvent, "UNIT_AURA", function() end)
    eq(ok, false, "RegisterEvent refuses it")
    ok = pcall(ns.RegisterUnitEvent, "UNIT_AURA", "target", function() end)
    eq(ok, false, "another unit is refused")
    ok = pcall(ns.RegisterUnitEvent, "UNIT_AURA", "player", function() end)
    eq(ok, true, "the same unit is fine")
end)
