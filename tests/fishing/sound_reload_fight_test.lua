-- Fishing/Sound.lua and Mode.lua after a /reload in a fight (review 1 of spec 013): PLAYER_REGEN_DISABLED does not
-- come again, so the fight is read from the lockdown at load; the slider's sample stays silent until the fight ends.

in_combat = true
load_addon()

test("a /reload in a fight: no sample until the fight ends", function()
    eq(ns.Mode.InFight(), true, "the fight is known")
    ns.Sound.Preview()
    eq(#sound_calls, 0, "no sample in the fight")
    in_combat = false
    fire("PLAYER_REGEN_ENABLED")
    eq(ns.Mode.InFight(), false, "over")
    ns.Sound.Preview()
    eq(#sound_calls, 1, "the sample after it")
end)
