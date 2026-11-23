-- UI/BestPlacesTab.lua in every interface language (specs/024-best-places FR-012, FR-013): the tab draws, a zone opens
-- into its subzones, and the tooltip formats its lines (with the "*" line) without an error in each of the ten
-- languages; zone, subzone and continent names come from the game by ID, never from a translation.

local FISH, JUNK = 6291, 6358
item_prices[FISH] = 10
area_names[101], area_names[102] = "Baradin Bay", "Menethil Harbor"
map_names[1437] = "Wetlands"
map_parents[1437], map_types[1415] = 1415, 2
local function cell(x, area, junk)
    return { c = 60, m = 0, t = 600, k = 1, px = x * 600, py = 18000, a = { [area] = 60 },
        i = { [FISH] = { 60 - junk, 60 - junk }, [JUNK] = junk > 0 and { junk, junk } or nil } }
end
load_addon(function()
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = {
        ["1437:0:11"] = cell(15, 101, 30), -- half the catch without a price: the "*"
        ["1437:0:12"] = cell(25, 101, 0),
        ["1437:0:21"] = cell(35, 102, 0),
    } }
end)

test("the tab, a zone's subzones and the tooltip in every language", function()
    for _, language in ipairs(ns.GetLanguages()) do
        ns.SetLanguage(language.code)
        local L = ns.L
        ns.StatsFrame.OpenBest()
        flush_timers()
        tick(_G.OneKeyFishingStatsFrame)
        local tab = _G.OneKeyFishingStatsFrame.bestPage
        eq(tab.safeButton.text, L["Safe for me: %s"]:format(L["On"]), language.code .. ": Safe for me")
        eq(tab.continentButton.text, L["Continent: %s"]:format(L["All"]), language.code .. ": Continent")
        local rows = scroll_rows(tab.places.box)
        eq(rows[1].name.text, "Wetlands", language.code .. ": the zone's name from the game")
        eq(rows[1].level.text, "20-30", language.code .. ": the level from GameData by map ID")
        rows[1].scripts.OnClick(rows[1], "LeftButton")
        local group
        for _, row in ipairs(scroll_rows(tab.places.box)) do
            group = group or (row.element.kind == "group" and row)
        end
        eq(group.name.text, "Baradin Bay", language.code .. ": the subzone's name from the game")
        tooltip_lines = {}
        group.scripts.OnEnter(group)
        assert(#tooltip_lines >= 3, language.code .. ": the tooltip's lines")
        assert(group.gold.text:find("%*$"), language.code .. ": the unpriced mark")
        rows[1].scripts.OnClick(rows[1], "LeftButton") -- fold the zone for the next language
        check_no_errors()
    end
    ns.SetLanguage("enUS")
end)
