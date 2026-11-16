-- Fishing/Mode.lua: a /reload with fishing mode on and the splash focus on, after the player turned the music up by
-- hand (spec 015 US2, contract M4, M5, SC-002): the mode resumes and the music keeps the player's value through the
-- resume, a second /reload and the exit.

C_CVar.SetCVar("Sound_MusicVolume", "0.7") -- the player's value, set while fishing before the /reload
C_CVar.SetCVar("Sound_AmbienceVolume", "0.5")
C_CVar.SetCVar("Sound_DialogVolume", "1.0")
fishing_ready()
login_with({ schema = 1, settings = { splashFocus = true, gear = false, camera = false } },
    { schema = 1, resumeMode = true, resumeOwned = { Sound_MusicVolume = true } }, false, true)

local function cvar(name)
    return C_CVar.GetCVar(name)
end

test("the resumed mode leaves the hand-changed music alone and applies the rest", function()
    eq(ns.Mode.IsActive(), true, "resumed")
    eq(cvar("Sound_MusicVolume"), "0.7", "the player's music")
    eq(cvar("Sound_AmbienceVolume"), "0", "the focus on the ambience")
    eq(cvar("Sound_DialogVolume"), "0", "and on the dialog")
    eq(ns.charDB.resumeOwned, nil, "the list taken")
    eq(ns.charDB.resumeMode, nil, "the flag taken")
end)

test("a second /reload keeps the list", function()
    fire("PLAYER_LOGOUT")
    eq(cvar("Sound_MusicVolume"), "0.7", "the player's music")
    eq(ns.charDB.resumeOwned and ns.charDB.resumeOwned.Sound_MusicVolume, true, "still the player's")
    ns.charDB.resumeMode, ns.charDB.resumeOwned = nil, nil
end)

test("the exit does not restore over the player's music", function()
    ns.Mode.Exit()
    eq(cvar("Sound_MusicVolume"), "0.7", "the player's music")
    eq(cvar("Sound_AmbienceVolume"), "0.5", "the ambience back")
    eq(cvar("Sound_DialogVolume"), "1.0", "the dialog back")
end)

test("a fresh entry owns nothing: the focus silences the music again", function()
    ns.Mode.Enter()
    eq(cvar("Sound_MusicVolume"), "0", "silenced")
    ns.Mode.Exit()
    eq(cvar("Sound_MusicVolume"), "0.7", "back")
end)
