-- Fishing/Mode.lua: a /reload in a fight with fishing mode on (spec 015 FR-006): the mode does not resume, which is
-- its end, so the hand-changed rows of the earlier session are dropped and the next entry is a fresh one.

C_CVar.SetCVar("Sound_MusicVolume", "0.7")
C_CVar.SetCVar("Sound_AmbienceVolume", "0.5")
C_CVar.SetCVar("Sound_DialogVolume", "1.0")
in_combat = true
fishing_ready()
login_with({ schema = 1, settings = { splashFocus = true, gear = false, camera = false } },
    { schema = 1, resumeMode = true, resumeOwned = { Sound_MusicVolume = true } }, false, true)

test("a resume blocked by a fight drops the list; the next entry silences the music", function()
    eq(ns.Mode.IsActive(), false, "not resumed in the fight")
    eq(ns.charDB.resumeOwned, nil, "the list dropped")
    in_combat = false
    fire("PLAYER_REGEN_ENABLED")
    ns.Mode.Enter()
    eq(ns.Mode.IsActive(), true, "entered after the fight")
    eq(C_CVar.GetCVar("Sound_MusicVolume"), "0", "a fresh entry owns nothing")
    ns.Mode.Exit()
    eq(C_CVar.GetCVar("Sound_MusicVolume"), "0.7", "back")
end)
