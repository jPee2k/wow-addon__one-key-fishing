-- The addon's popups show their buttons in the addon's language, not the client's (spec 007, User Story 3).
-- A Russian client with the addon in Ukrainian, as found in game on 2026-11-05.

CLIENT_LOCALE = "ruRU"
OneKeyFishingDB = { schema = 1, settings = { language = "ukUA" } }
-- The game's own button texts, in the client's language; a popup that shows one of them is wrong.
YES, NO, CANCEL = "client yes", "client no", "client cancel"

load_addon()
local L = ns.L
local _, ukrainian = load_translation("ukUA")

local function buttons(key)
    local dialog = assert(StaticPopupDialogs[key], "popup " .. key)
    return dialog.button1, dialog.button2
end

test("the addon is in Ukrainian on the Russian client", function()
    eq(ns.language, "ukUA", "language")
end)

test("the statistics reset popups say yes and no in Ukrainian", function()
    ns.StatsFrame.Toggle()
    local window = _G.OneKeyFishingStatsFrame
    for _, case in ipairs({
        { button = L["Reset session"], popup = "ONEKEYFISHING_RESET_SESSION" },
        { button = L["Reset all"], popup = "ONEKEYFISHING_RESET_ALL" },
    }) do
        reset_popup()
        click(case.button, window)
        eq(rawget(_G, "last_popup"), case.popup, "popup shown")
        local accept, cancel = buttons(case.popup)
        eq(accept, ukrainian["Yes"], case.popup .. " accept")
        eq(cancel, ukrainian["No"], case.popup .. " cancel")
    end
end)

test("the map pin popup cancels in Ukrainian", function()
    user_waypoint = { uiMapID = 5, position = { x = 0.1, y = 0.1 } } -- a pin of the player's own
    reset_popup()
    ns.MapPin.Set({ mapID = 1434, x = 0.274, y = 0.77 }, "Booty Bay")
    eq(rawget(_G, "last_popup"), "ONEKEYFISHING_REPLACE_PIN", "popup shown")
    local accept, cancel = buttons("ONEKEYFISHING_REPLACE_PIN")
    eq(accept, ukrainian["Replace"], "accept")
    eq(cancel, ukrainian["Cancel"], "cancel")
    user_waypoint = nil
end)

test("the language reload popup keeps its own texts", function()
    reset_popup()
    ns.SettingsUI.ChooseLanguage("deDE")
    local accept, cancel = buttons("ONEKEYFISHING_RELOAD_LANGUAGE")
    eq(accept, ukrainian["Reload now"], "accept")
    eq(cancel, ukrainian["Later"], "cancel")
end)
