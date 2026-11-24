-- UI/Minimap.lua: the minimap button's menu in a fight. The game's title element is refused to addon code in combat
-- (the "Interface action failed because of an AddOn" line, seen in game 2026-11-18); the stub counts it.

load_addon()
local L = ns.L

local function OpenMenu()
    OneKeyFishing_OnAddonCompartmentClick(nil, "RightButton")
end

local function texts()
    local out = {}
    for _, entry in ipairs(menu_entries) do
        if entry.kind ~= "title" then
            table.insert(out, entry.text)
        end
    end
    return table.concat(out, "|")
end

test("out of combat the menu has its title", function()
    in_combat = false
    OpenMenu()
    eq(menu_entries[1].kind, "title", "first entry")
    eq(menu_entries[1].text, "OneKeyFishing", "the title")
    eq(menu_blocked, 0, "nothing refused")
end)

test("in combat the menu opens without a title, and the game refuses nothing", function()
    in_combat = false
    OpenMenu()
    local outside = texts()
    in_combat = true
    OpenMenu()
    in_combat = false
    eq(menu_blocked, 0, "no title, divider or spacer in combat")
    assert(not menu_entry("OneKeyFishing"), "no title")
    eq(texts(), outside, "the same entries as out of combat")
    assert(menu_entry(L["Statistics"]), "the statistics entry")
end)

test("the menu has Catalog and Best places after Statistics, each opening its tab (spec 024)", function()
    OpenMenu()
    local list = texts()
    assert(list:find(L["Statistics"] .. "|" .. L["Catalog"] .. "|" .. L["Best places"], 1, true), list)
    menu_entry(L["Best places"]).onClick()
    local window = _G.OneKeyFishingStatsFrame
    assert(window.bestPage:IsShown(), "the best places")
    menu_entry(L["Catalog"]).onClick()
    assert(window.catalogPage:IsShown(), "the catalog")
end)

test("the menu's Statistics opens the statistics tab, not the last one used", function()
    OpenMenu()
    menu_entry(L["Best places"]).onClick()
    menu_entry(L["Statistics"]).onClick()
    local window = _G.OneKeyFishingStatsFrame
    assert(window:IsShown(), "the window stays open")
    assert(not window.bestPage:IsShown(), "not the best places")
    eq(ns.db.statsTab, "stats", "the statistics tab")
end)

test("a closed window opens straight on the statistics, the best places never shown on the way", function()
    local window = _G.OneKeyFishingStatsFrame
    ns.StatsFrame.OpenBest()
    window:Hide()
    local shown, setShown = false, window.bestPage.SetShown
    window.bestPage.SetShown = function(self, on)
        shown = shown or on
        return setShown(self, on)
    end
    OpenMenu()
    menu_entry(L["Statistics"]).onClick()
    window.bestPage.SetShown = setShown
    assert(window:IsShown(), "the window opened")
    assert(not shown, "the best places were not shown")
    eq(ns.db.statsTab, "stats", "the statistics tab")
end)
