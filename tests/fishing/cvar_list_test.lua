-- Fishing/Mode.lua: Mode.CVAR_NAMES lists the CVars fishing mode may change, and the debug report shows each of
-- them from that one list (specs/008-architecture-alignment research R8); spec 013 adds the six sound CVars and the
-- four settings of the "Sound effects" page (FR-017).

load_addon()

local SOUND_CVARS = { "Sound_EnableSoundWhenGameIsInBG", "Sound_MusicVolume", "Sound_AmbienceVolume",
    "Sound_DialogVolume", "Sound_EnableSFX", "Sound_SFXVolume" }

test("the debug report's Game settings show every CVar of Mode.CVAR_NAMES", function()
    local names = ns.Mode.CVAR_NAMES
    eq(#names, 10, "the soft-target interact, auto loot, the two interact icons and the six sound CVars")
    local listed = {}
    for _, name in ipairs(names) do
        listed[name] = true
    end
    for _, name in ipairs(SOUND_CVARS) do
        assert(listed[name], name .. " in Mode.CVAR_NAMES")
    end
    local _, report = ns.Debug.Report()
    for _, name in ipairs(names) do
        assert(report:find(name .. " = ", 1, true), name .. " in the report:\n" .. report)
    end
end)

test("the four settings of the Sound effects page are in the report", function()
    local _, report = ns.Debug.Report()
    for _, key in ipairs({ "fishingSounds", "soundVolume", "backgroundSound", "splashFocus" }) do
        assert(report:find(key .. " = ", 1, true), key .. " in the report:\n" .. report)
    end
end)
