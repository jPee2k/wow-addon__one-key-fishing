-- Fishing/Mode.lua: the game audio settings of the "Sound effects" page (specs/013-fishing-sounds US3, US4,
-- FR-013 to FR-016, FR-018): recorded before they change, set while fishing, applied or restored at once when switched
-- while fishing, put back on every end of fishing mode, a player's own change kept; the background sound kept in a
-- fight, the splash focus lifted for it.

load_addon()

local BG = "Sound_EnableSoundWhenGameIsInBG"

local function cvar(name)
    return C_CVar.GetCVar(name)
end

local function switch(key, value)
    ns.db.settings[key] = value
    ns.Fire("SETTINGS_CHANGED", key)
end

local function fight(exitOnCombat)
    ns.db.settings.exitOnCombat = exitOnCombat
    in_combat = true
    fire("PLAYER_REGEN_DISABLED")
end

local function fight_ends()
    in_combat = false
    fire("PLAYER_REGEN_ENABLED")
end

-- Background sound (US3) ---------------------------------------------------------------------------------------------

test("background on: set while fishing, recorded first, put back on exit", function()
    ns.db.settings.backgroundSound = true
    enter_fishing_mode()
    eq(cvar(BG), "1", "on while fishing")
    eq(ns.charDB.savedCVars[BG], "0", "the old value recorded")
    ns.Mode.Exit()
    eq(cvar(BG), "0", "back after the exit")
end)

test("background off: the game setting is not touched", function()
    ns.db.settings.backgroundSound = false
    enter_fishing_mode()
    eq(cvar(BG), "0", "untouched")
    eq(ns.charDB.savedCVars and ns.charDB.savedCVars[BG], nil, "no record")
    ns.Mode.Exit()
end)

test("switched while fishing: applied and restored at once; untouched outside fishing mode", function()
    ns.db.settings.backgroundSound = false
    enter_fishing_mode()
    switch("backgroundSound", true)
    eq(cvar(BG), "1", "on at once")
    switch("backgroundSound", false)
    eq(cvar(BG), "0", "back at once")
    ns.Mode.Exit()
    switch("backgroundSound", true)
    eq(cvar(BG), "0", "nothing outside fishing mode")
end)

test("a hand change while fishing is kept at the exit", function()
    C_CVar.SetCVar(BG, "0")
    ns.db.settings.backgroundSound = true
    enter_fishing_mode()
    C_CVar.SetCVar(BG, "0") -- Options -> Audio -> Sound in Background, by hand
    ns.Mode.Exit()
    eq(cvar(BG), "0", "the player's value")
    C_CVar.SetCVar(BG, "1") -- the player's own setting is on: fishing changes nothing
    enter_fishing_mode()
    eq(cvar(BG), "1", "unchanged")
    ns.Mode.Exit()
    eq(cvar(BG), "1", "still the player's")
    C_CVar.SetCVar(BG, "0")
end)

test("a fight keeps the background sound; a fight that ends the mode restores it with the exit", function()
    ns.db.settings.backgroundSound = true
    enter_fishing_mode()
    fight(false)
    eq(cvar(BG), "1", "kept in the fight")
    fight_ends()
    eq(cvar(BG), "1", "kept after it")
    fight(true)
    eq(cvar(BG), "1", "kept while the exit waits")
    fight_ends()
    eq(ns.Mode.IsActive(), false, "the fight ended the mode")
    eq(cvar(BG), "0", "restored with the exit")
end)

test("logout restores it, and a crash's record is restored at the next login", function()
    ns.db.settings.backgroundSound = true
    enter_fishing_mode()
    fire("PLAYER_LOGOUT")
    eq(cvar(BG), "0", "restored at logout")
    ns.Mode.Exit()
    ns.charDB.resumeMode = nil
    C_CVar.SetCVar(BG, "1")
    ns.charDB.savedCVars = { [BG] = "0" }
    fire("PLAYER_LOGIN")
    eq(cvar(BG), "0", "restored at login")
    eq(ns.charDB.savedCVars, nil, "no record left")
end)

-- Splash focus (US4) -------------------------------------------------------------------------------------------------

local FOCUS = { "Sound_MusicVolume", "Sound_AmbienceVolume", "Sound_DialogVolume", "Sound_EnableSFX",
    "Sound_SFXVolume" }

local function set_mix(music, ambience, dialog, sfxOn, sfx)
    C_CVar.SetCVar("Sound_MusicVolume", music)
    C_CVar.SetCVar("Sound_AmbienceVolume", ambience)
    C_CVar.SetCVar("Sound_DialogVolume", dialog)
    C_CVar.SetCVar("Sound_EnableSFX", sfxOn)
    C_CVar.SetCVar("Sound_SFXVolume", sfx)
end

local function mix()
    local values = {}
    for _, name in ipairs(FOCUS) do
        table.insert(values, cvar(name))
    end
    return table.concat(values, " ")
end

test("focus on: music, ambience and dialog silenced, effects on and at least 90 %, all back on exit", function()
    ns.db.settings.backgroundSound = false
    ns.db.settings.splashFocus = true
    set_mix("0.4", "0.6", "1.0", "0", "0.5")
    enter_fishing_mode()
    eq(mix(), "0 0 0 1 0.9", "the focus")
    ns.Mode.Exit()
    eq(mix(), "0.4 0.6 1.0 0 0.5", "the player's mix again")
    eq(ns.charDB.savedCVars, nil, "no record left")
end)

test("effects already at 90 % or more are not changed, only recorded", function()
    set_mix("0.4", "0.6", "1.0", "1", "1.0")
    enter_fishing_mode()
    eq(cvar("Sound_SFXVolume"), "1.0", "unchanged")
    eq(ns.charDB.savedCVars.Sound_SFXVolume, "1.0", "recorded, so a hand change can be told apart")
    ns.Mode.Exit()
    eq(cvar("Sound_SFXVolume"), "1.0", "the same after the exit")
end)

test("a hand change of the music while fishing is kept, the rest put back", function()
    set_mix("0.4", "0.6", "1.0", "1", "0.5")
    enter_fishing_mode()
    C_CVar.SetCVar("Sound_MusicVolume", "0.3")
    ns.Mode.Exit()
    eq(mix(), "0.3 0.6 1.0 1 0.5", "the music as the player set it")
end)

test("a fight lifts the focus at once and it comes back after the fight", function()
    set_mix("0.4", "0.6", "1.0", "1", "0.5")
    enter_fishing_mode()
    fight(false)
    eq(mix(), "0.4 0.6 1.0 1 0.5", "lifted at the fight's start")
    for _, name in ipairs(FOCUS) do
        eq(ns.charDB.savedCVars and ns.charDB.savedCVars[name], nil, name .. " record dropped")
    end
    fight_ends()
    eq(mix(), "0 0 0 1 0.9", "back after the fight")
    ns.Mode.Exit()
    eq(mix(), "0.4 0.6 1.0 1 0.5", "restored on exit")
end)

test("a fight that ends fishing mode leaves everything restored", function()
    set_mix("0.4", "0.6", "1.0", "1", "0.5")
    enter_fishing_mode()
    fight(true)
    eq(mix(), "0.4 0.6 1.0 1 0.5", "lifted")
    fight_ends()
    eq(ns.Mode.IsActive(), false, "the mode ended")
    eq(mix(), "0.4 0.6 1.0 1 0.5", "nothing set again")
end)

test("switched on in a fight: nothing until the fight ends; switched off while fishing: restored at once", function()
    ns.db.settings.splashFocus = false
    set_mix("0.4", "0.6", "1.0", "1", "0.5")
    enter_fishing_mode()
    fight(false)
    switch("splashFocus", true)
    eq(mix(), "0.4 0.6 1.0 1 0.5", "nothing in the fight")
    fight_ends()
    eq(mix(), "0 0 0 1 0.9", "applied after it")
    switch("splashFocus", false)
    eq(mix(), "0.4 0.6 1.0 1 0.5", "restored at once")
    ns.Mode.Exit()
end)

-- Review 1 (2026-11-16) ----------------------------------------------------------------------------------------------

test("a fight or a sound switch while fishing leaves the next-time rows (auto loot) alone", function()
    ns.db.settings.splashFocus = true
    ns.db.settings.autoLoot = true
    C_CVar.SetCVar("autoLootDefault", "0")
    enter_fishing_mode()
    eq(cvar("autoLootDefault"), "1", "set on entry")
    ns.db.settings.autoLoot = false -- the main page's checkbox: applies the next time
    ns.Fire("SETTINGS_CHANGED", "autoLoot")
    fight(false)
    eq(cvar("autoLootDefault"), "1", "untouched at the fight's start")
    fight_ends()
    switch("splashFocus", false)
    eq(cvar("autoLootDefault"), "1", "untouched by a sound switch")
    ns.Mode.Exit()
    eq(cvar("autoLootDefault"), "0", "back on exit")
    ns.db.settings.autoLoot = true
end)

test("a music volume set by hand while fishing survives a fight", function()
    ns.db.settings.splashFocus = true
    set_mix("0.8", "0.6", "1.0", "1", "0.5")
    enter_fishing_mode()
    C_CVar.SetCVar("Sound_MusicVolume", "0.4") -- by hand
    fight(false)
    fight_ends()
    eq(cvar("Sound_MusicVolume"), "0.4", "the player's value, not silenced again")
    eq(cvar("Sound_AmbienceVolume"), "0", "the rest of the focus came back")
    switch("splashFocus", false)
    switch("splashFocus", true)
    eq(cvar("Sound_MusicVolume"), "0", "switching the focus on again applies it again")
    ns.Mode.Exit()
    eq(cvar("Sound_MusicVolume"), "0.4", "the player's value after the exit")
end)

-- Final review: a row that already held the addon's value on entry is recorded too, so a hand change is seen.
test("effects already at 100 % on entry, lowered by hand while fishing: a fight keeps the player's value", function()
    ns.db.settings.splashFocus = true
    set_mix("0.4", "0.6", "1.0", "1", "1.0")
    enter_fishing_mode()
    C_CVar.SetCVar("Sound_SFXVolume", "0.5") -- by hand
    fight(false)
    fight_ends()
    eq(cvar("Sound_SFXVolume"), "0.5", "the player's value, not raised again")
    ns.Mode.Exit()
    eq(cvar("Sound_SFXVolume"), "0.5", "still the player's after the exit")
end)

-- Review of 2026-11-16 (after the in-game test): a hand change made during the fight is the player's too.
test("music set by hand during a fight is not silenced again when the fight ends", function()
    ns.db.settings.splashFocus = true
    set_mix("0.6", "0.6", "1.0", "1", "0.5")
    enter_fishing_mode()
    fight(false)
    eq(cvar("Sound_MusicVolume"), "0.6", "lifted for the fight")
    C_CVar.SetCVar("Sound_MusicVolume", "0.3") -- by hand, during the fight
    fight_ends()
    eq(cvar("Sound_MusicVolume"), "0.3", "the player's value")
    eq(cvar("Sound_AmbienceVolume"), "0", "the rest of the focus came back")
    ns.Mode.Exit()
    eq(cvar("Sound_MusicVolume"), "0.3", "still the player's after the exit")
end)
