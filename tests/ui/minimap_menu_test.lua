-- UI/Minimap.lua: the minimap button's menu, the addon's own (ns.OpenMenu; specs/029-blocked-actions): no title,
-- the same entries in a fight as out of it.

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

test("the menu has no title and the same entries in a fight", function()
    in_combat = false
    OpenMenu()
    local outside = texts()
    for _, entry in ipairs(menu_entries) do
        assert(entry.kind ~= "title", "no title out of combat")
    end
    in_combat = true
    OpenMenu()
    in_combat = false
    assert(not menu_entry("OneKeyFishing"), "no title")
    eq(texts(), outside, "the same entries in combat")
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
