-- Fishing/Sound.lua in a fight (specs/013-fishing-sounds FR-018): at the fight's start every sound stops and none
-- plays until it ends; after it the sounds play again while fishing mode is still on.

load_addon()

local function green_loot()
    loot = { fishing = true, items = { { 6304, 1, 2 } } }
    fire("LOOT_READY")
    loot = nil
end

test("a fight stops the sounds, keeps them silent, and they come back after it", function()
    ns.db.settings.exitOnCombat = false
    ns.Sound.SetEnabled(true)
    enter_fishing_mode()
    ns.Fire("FISHING_CAST_START", 7620)
    eq(#sound_calls, 1, "the bell")
    in_combat = true
    fire("PLAYER_REGEN_DISABLED")
    eq(#sound_stops, 1, "the bell stopped at the fight's start")
    green_loot()
    advance(1)
    ns.Fire("FISHING_CAST_STOP", 7620)
    advance(2)
    ns.Fire("FISHING_CAST_START", 7620)
    eq(#sound_calls, 1, "nothing in the fight")
    ns.Fire("FISHING_CAST_STOP", 7620)
    advance(2)
    in_combat = false
    fire("PLAYER_REGEN_ENABLED")
    ns.Fire("FISHING_CAST_START", 7620)
    eq(#sound_calls, 2, "the bell after the fight")
    ns.Fire("FISHING_CAST_STOP", 7620)
    advance(2)
end)

test("a rare sound waiting when the fight starts does not play", function()
    ns.db.settings.exitOnCombat = false
    ns.Sound.SetEnabled(true)
    enter_fishing_mode()
    ns.Fire("FISHING_CAST_START", 7620)
    green_loot()
    eq(#sound_calls, 2, "bell and hook")
    in_combat = true
    fire("PLAYER_REGEN_DISABLED")
    advance(1)
    eq(#sound_calls, 2, "no rare sound in the fight")
    in_combat = false
    fire("PLAYER_REGEN_ENABLED")
    ns.Fire("FISHING_CAST_STOP", 7620)
    advance(2)
end)
