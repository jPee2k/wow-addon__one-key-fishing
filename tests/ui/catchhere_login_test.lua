-- The statistics window on a new login: it opens on the tab saved last time, the filters of "What can be caught
-- here" start at their defaults, and a client without the game's tab functions gets plain buttons.

OneKeyFishingDB = { schema = 1, statsTab = "here" } -- saved by an earlier session
PanelTemplates_SetTab = false -- a client without the game's tab functions
player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
load_addon()

local L = ns.L
ns.StatsFrame.Toggle()
local window = _G.OneKeyFishingStatsFrame
local here = window.herePage

test("the window opens on the tab saved last time", function()
    assert(here:IsShown(), "What can be caught here shown")
    assert(not window.statsPage:IsShown(), "statistics hidden")
end)

test("the filters start at their defaults", function()
    eq(here.skillButton.text, (L["Skill: %s"]):format("225-299"), "own skill range")
    eq(here.sourceButton.text, (L["Source: %s"]):format(L["All"]), "all sources")
end)

test("without the game's tab functions the tabs are plain buttons that still switch", function()
    eq(window.usesPanelTabs, false, "plain buttons")
    click(L["Statistics"], window)
    assert(window.statsPage:IsShown(), "statistics shown")
    eq(ns.db.statsTab, "stats", "saved")
    click(L["What can be caught here"], window)
    assert(here:IsShown(), "back on the page")
end)
