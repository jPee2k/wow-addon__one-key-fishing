-- Fishing/Mode.lua: a real login after a session that crashed right after a /reload, with the hand-changed rows still
-- saved (spec 015 FR-006): a real login never resumes the mode, so the list is dropped.

C_CVar.SetCVar("Sound_MusicVolume", "0.7")
C_CVar.SetCVar("Sound_AmbienceVolume", "0.5")
C_CVar.SetCVar("Sound_DialogVolume", "1.0")
fishing_ready()
login_with({ schema = 1, settings = { splashFocus = true, gear = false, camera = false } },
    { schema = 1, resumeOwned = { Sound_MusicVolume = true } }, true, false)

test("a real login drops the list; the next entry silences the music", function()
    eq(ns.Mode.IsActive(), false, "not resumed")
    eq(ns.charDB.resumeOwned, nil, "the list dropped")
    ns.Mode.Enter()
    eq(C_CVar.GetCVar("Sound_MusicVolume"), "0", "a fresh entry owns nothing")
    ns.Mode.Exit()
end)
