-- Fishing/Sound.lua: the volume of the fishing sounds (specs/013-fishing-sounds US2, FR-010). PlaySoundFile has no
-- volume argument, so each step plays its own pre-rendered file; 0 % plays nothing; the sample of the slider plays
-- also outside fishing mode, but never in a fight.

load_addon()

local MASTER = "Interface\\AddOns\\OneKeyFishing\\Media\\Sounds\\hook.ogg"

test("the file of each step", function()
    eq(ns.Sound.Path("hook", 100), MASTER, "100 %: the master")
    eq(ns.Sound.Path("hook", 30), "Interface\\AddOns\\OneKeyFishing\\Media\\Sounds\\Volume30\\hook.ogg", "30 %")
    eq(ns.Sound.Path("hook", 0), nil, "0 %: nothing")
end)

test("a saved volume off the grid reads as the nearest step from 0 to 100", function()
    local function read(value)
        ns.db.settings.soundVolume = value
        return ns.Sound.Volume()
    end
    eq(read(37), 40, "37")
    eq(read(-5), 0, "-5")
    eq(read(250), 100, "250")
    eq(read("x"), 100, "not a number")
    ns.Sound.SetVolume(64)
    eq(ns.db.settings.soundVolume, 60, "stored rounded")
end)

test("the fishing sounds use the chosen step, and nothing plays at 0 %", function()
    ns.Sound.SetEnabled(true)
    enter_fishing_mode()
    ns.Sound.SetVolume(50)
    ns.Fire("FISHING_CAST_START", 7620)
    eq(sound_calls[1].path, "Interface\\AddOns\\OneKeyFishing\\Media\\Sounds\\Volume50\\bell.ogg", "the 50 % bell")
    ns.Fire("FISHING_CAST_STOP", 7620)
    advance(2)
    ns.Sound.SetVolume(0)
    ns.Fire("FISHING_CAST_START", 7620)
    eq(#sound_calls, 1, "nothing at 0 %")
    ns.Fire("FISHING_CAST_STOP", 7620)
    advance(2)
    ns.Sound.SetVolume(100)
end)

test("the sample plays at the current volume, also with the sounds and the mode off, not in a fight", function()
    ns.Sound.SetEnabled(false)
    ns.Mode.Exit()
    sound_calls = {}
    ns.Sound.SetVolume(70)
    ns.Sound.Preview()
    eq(#sound_calls, 1, "one sample")
    eq(sound_calls[1].path, "Interface\\AddOns\\OneKeyFishing\\Media\\Sounds\\Volume70\\hook.ogg", "at 70 %")
    in_combat = true
    fire("PLAYER_REGEN_DISABLED")
    ns.Sound.Preview()
    eq(#sound_calls, 1, "no sample in a fight")
    in_combat = false
    fire("PLAYER_REGEN_ENABLED")
    ns.Sound.SetVolume(100)
end)

-- Final review: moving the volume to 0 % stops the sample that still plays.
test("a sample at 0 % stops the previous one and plays nothing", function()
    ns.Sound.SetVolume(10)
    ns.Sound.Preview()
    local played, stopped = #sound_calls, #sound_stops
    ns.Sound.SetVolume(0)
    ns.Sound.Preview()
    eq(#sound_calls, played, "nothing new plays")
    eq(#sound_stops, stopped + 1, "the 10 % sample stopped")
    ns.Sound.SetVolume(100)
end)
