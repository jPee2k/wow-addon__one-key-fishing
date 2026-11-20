-- The camp bonus notices (specs/020-camp-buffs FR-031 to FR-033, research R10): one at five minutes left and one at
-- the end, decided by a check after an allowed read or a timer, never by the clock alone in a fight; only with
-- fishing mode and the setting on at the crossing; a crossing passed silently is not shown later. The tests run in
-- order and share one login; each starts without a buff and with no notice pending.

local RACK, HUT = 1280341, 1280342

load_addon()
local L = ns.L

local notices = {}
ns.On("CAMP_BONUS_WARNING", function(text) table.insert(notices, text) end)

local realIsActive = ns.Mode.IsActive
local modeOn = true
ns.Mode.IsActive = function() return modeOn end

local WARN = { [RACK] = L["The Fishing Rack bonus ends in 5 minutes."],
    [HUT] = L["The Fishing Hut bonus ends in 5 minutes."] }
local ENDED = { [RACK] = L["The Fishing Rack bonus has ended."], [HUT] = L["The Fishing Hut bonus has ended."] }

-- A clean start: no buff, out of a fight, mode and setting on, no notice, every old timer run.
local function reset()
    auras, auras_restricted, in_combat = {}, false, false
    modeOn = true
    ns.db.settings.campBonusWarning = true
    fire("UNIT_AURA", "player")
    flush_timers()
    notices = {}
end

local function grant(spell, seconds)
    auras[spell] = { expirationTime = GetTime() + seconds, duration = 3600 }
    fire("UNIT_AURA", "player")
end

local function fight(on)
    in_combat, auras_restricted = on, on
    if not on then
        fire("PLAYER_REGEN_ENABLED")
    end
end

local function list()
    return table.concat(notices, " | ")
end

test("fishing: one notice at five minutes left and one at the end, each once", function()
    reset()
    grant(RACK, 3600)
    advance(3301) -- the timer a second past the threshold
    eq(list(), WARN[RACK], "five minutes left")
    advance(300)
    eq(list(), WARN[RACK] .. " | " .. ENDED[RACK], "ended")
    fire("UNIT_AURA", "player")
    advance(100)
    eq(#notices, 2, "never a second one")
end)

test("the Hut's texts for the Hut", function()
    reset()
    grant(HUT, 3600)
    advance(3601)
    eq(list(), WARN[HUT] .. " | " .. ENDED[HUT], "the Hut")
end)

test("mode off at the crossing, on at 200 s left: no five-minute notice, the end notice", function()
    reset()
    modeOn = false
    grant(RACK, 3600)
    advance(3400)
    modeOn = true
    fire("UNIT_AURA", "player")
    eq(#notices, 0, "nothing at 200 s left")
    advance(201)
    eq(list(), ENDED[RACK], "only the end")
end)

test("mode off at the end, on after it: none; the setting off at a crossing, on after it: none for it", function()
    reset()
    modeOn = false
    grant(RACK, 250)
    advance(251)
    modeOn = true
    fire("UNIT_AURA", "player")
    eq(#notices, 0, "none")
    reset()
    ns.db.settings.campBonusWarning = false
    grant(RACK, 3600)
    advance(3301)
    ns.db.settings.campBonusWarning = true
    fire("UNIT_AURA", "player")
    eq(#notices, 0, "the crossing passed while off")
end)

test("first seen with 200 s left: only the end notice", function()
    reset()
    grant(RACK, 200)
    advance(201)
    eq(list(), ENDED[RACK], "the end only")
end)

test("a renewed buff: no end notice for the old one, five minutes again for the new", function()
    reset()
    grant(RACK, 3600)
    advance(3400) -- the old one's five minutes
    notices = {}
    grant(RACK, 3600) -- renewed with 200 s left
    advance(3600 - 300 + 1)
    eq(list(), WARN[RACK], "the new one's five minutes, no end of the old")
    advance(300)
    eq(list(), WARN[RACK] .. " | " .. ENDED[RACK], "the new one's end")
end)

test("a fight over the five-minute crossing: none at all, the end notice at the end", function()
    reset()
    grant(RACK, 3600)
    advance(3280)
    fight(true)
    advance(120)
    fight(false)
    eq(#notices, 0, "found 100 s late: silent")
    advance(201)
    eq(list(), ENDED[RACK], "the end")
end)

test("the 30 s window: a fight ending 20 s after the crossing shows it, 40 s after does not", function()
    reset()
    grant(RACK, 3600)
    advance(3290)
    fight(true)
    advance(30)
    fight(false)
    eq(list(), WARN[RACK], "20 s late")
    reset()
    grant(RACK, 3600)
    advance(3290)
    fight(true)
    advance(50)
    fight(false)
    eq(#notices, 0, "40 s late")
end)

test("the five-minute timer one frame short of the threshold still finds the crossing", function()
    reset()
    local clock = GetTime
    grant(RACK, 3600)
    GetTime = function() return clock() - 0.02 end
    advance(3301)
    GetTime = clock
    eq(list(), WARN[RACK], "found")
end)

test("a fight over the end: nothing in it; after it the end once, or nothing when the buff was renewed", function()
    reset()
    grant(RACK, 250)
    fight(true)
    auras[RACK] = nil
    advance(260)
    eq(#notices, 0, "nothing in the fight")
    fight(false)
    eq(list(), ENDED[RACK], "the end after it")
    fire("UNIT_AURA", "player")
    eq(#notices, 1, "once")
    reset()
    grant(RACK, 250)
    fight(true)
    auras[RACK] = { expirationTime = GetTime() + 3600, duration = 3600 } -- a party member's new Rack
    advance(260)
    fight(false)
    eq(#notices, 0, "renewed in the fight: no end")
end)

test("a death out of a fight: the end notice once", function()
    reset()
    grant(RACK, 250)
    auras[RACK] = nil
    fire("UNIT_AURA", "player")
    eq(list(), ENDED[RACK], "the end")
    advance(260)
    eq(#notices, 1, "once")
end)

test("\"Leave fishing mode when attacked\" on: the mode leaves before the read, no notice now or later", function()
    reset()
    ns.Mode.IsActive = realIsActive
    grant(RACK, 250)
    enter_fishing_mode()
    ns.db.settings.exitOnCombat = true
    in_combat, auras_restricted = true, true
    fire("PLAYER_REGEN_DISABLED")
    auras[RACK] = nil
    advance(260)
    fight(false)
    assert(not ns.Mode.IsActive(), "the mode left")
    eq(#notices, 0, "no notice")
    enter_fishing_mode()
    fire("UNIT_AURA", "player")
    eq(#notices, 0, "none when the mode is on again")
    ns.Mode.Exit()
end)
