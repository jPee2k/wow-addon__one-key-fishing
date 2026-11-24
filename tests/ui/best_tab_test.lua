-- UI/BestPlacesTab.lua (specs/024-best-places US1, US2, US3, US5): the zones with their columns, the level in red, a
-- zone opening into its subzones and spots with pins (the best spot's pin in three clicks, SC-004), the tooltip's
-- top items, the filters and what a login keeps. The tests share one login and run in order.

local FISH, CHEST = 6291, 6355
item_prices[FISH], item_prices[CHEST] = 10, 100
area_names[101] = "Baradin Bay"
map_names[3301], map_names[3302] = "Wetlands", "Badlands"
waypoint_maps[3301] = true
player_level = 33
local function cell(c, t, x, area, chests)
    return { c = c, m = 0, t = t, k = 1, px = x * c * 10, py = 300 * c, a = area and { [area] = c } or nil,
        i = { [FISH] = { c - (chests or 0), c - (chests or 0) }, [CHEST] = chests and { chests, chests } or nil } }
end
load_addon(function()
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = {
        ["3301:0:11"] = cell(60, 600, 15, 101, 30),
        ["3301:0:12"] = cell(60, 600, 25, 101, 6),
        ["3301:0:21"] = cell(60, 600, 35, nil, 0),
        ["3302:0:11"] = cell(60, 600, 15, nil, 60), -- the richest, but 35-45
    } }
end)

local L = ns.L
local pinned -- the place name of the last map pin (MAP_PIN_SET)
ns.On("MAP_PIN_SET", function(name) pinned = name end)
ns.GameData.ZoneLevels[3302] = { 35, 45 }

local function open()
    ns.StatsFrame.OpenBest()
    flush_timers()
    tick(_G.OneKeyFishingStatsFrame)
    return _G.OneKeyFishingStatsFrame.bestPage
end

local function rows(tab)
    return scroll_rows(tab.places.box)
end

test("the zones in their order, with skill, level, gold per hour and catches; level 35 at 33 shows red", function()
    local tab = open()
    local list = rows(tab)
    eq(#list, 2, "two zones (35-45 is within 33 + 3)")
    eq(list[1].name.text, "Badlands", "the richest first")
    eq(list[1].level.text, "35-45", "its levels")
    eq(list[1].level.textColor[1], 1, "red")
    eq(list[1].level.textColor[2], 0.3, "red")
    eq(list[2].level.textColor[2], 1, "a reused row is white again")
    eq(list[2].level.text, "", "no levels for Wetlands")
    eq(list[1].gold.text, ns.BestPlaces.FormatGold(60 * 100 * 3600 / 600), "gold per hour")
    eq(list[1].catches.text, "60", "catches")
end)

test("Safe for me at level 31 hides a zone of 35, and the empty text shows when nothing passes", function()
    player_level = 31
    ns.BestPlaces.SetSafe(true)
    local tab = open()
    eq(#rows(tab), 1, "Badlands hidden at 31 (35 > 31 + 3)")
    ns.BestPlaces.SetContinent("kalimdor")
    tab = open()
    eq(#rows(tab), 0, "no zone on Kalimdor")
    eq(tab.status.text, L["Nothing matches the filters."], "the empty text")
    ns.BestPlaces.SetContinent("all")
    player_level = 33
end)

test("a zone opens into its subzone and lone spot, the subzone into its spots; three clicks to the best pin", function()
    local tab = open()
    local wetlands = rows(tab)[2]
    wetlands.scripts.OnClick(wetlands, "LeftButton") -- click 2 (the menu entry was click 1)
    local list = rows(tab)
    eq(#list, 4, "two zones, Baradin Bay and the lone spot")
    eq(list[3].name.text, "Baradin Bay", "the subzone once")
    assert(list[3].pinButton:IsShown(), "the subzone's pin")
    user_waypoint = nil
    list[3].pinButton.scripts.OnClick(list[3].pinButton) -- click 3
    assert(user_waypoint, "the pin is set on its best spot")
    assert(pinned and pinned:find("Baradin Bay (", 1, true), "the label names the spot it marks: " .. tostring(pinned))
    list[3].scripts.OnClick(list[3], "LeftButton")
    list = rows(tab)
    eq(#list, 6, "and its two spots")
    eq(list[4].name.text, "15, 30", "a spot under its subzone names only its coordinates")
end)

test("hovering a zone lists the items that bring the gold, the players and no unpriced line", function()
    local tab = open()
    local badlands = rows(tab)[1]
    tooltip_lines = {}
    badlands.scripts.OnEnter(badlands)
    eq(tooltip_lines[1], "Badlands", "the place")
    assert(tooltip_lines[2]:find("100%%"), "the chests bring all its gold: " .. tooltip_lines[2])
    eq(tooltip_lines[3], ns.Catalog.CatchesText(60, 1), "the catches and players")
    eq(tooltip_lines[4], nil, "no unpriced line")
end)

test("the other faction's zone shows its Level in red with Safe for me off, and is hidden with it on (spec 026)",
    function()
    ns.GameData.ZoneFactions[3302] = "Alliance" -- Badlands plays an Alliance zone; the character is of the Horde
    ns.GameData.ZoneFactions[3301] = "Horde"
    ns.GameData.ZoneLevels[3301] = { 20, 30 }
    ns.Fire("PRICES_CHANGED") -- a recount, so the zones take their new factions
    player_faction = "Horde"
    ns.BestPlaces.SetSafe(false)
    player_level = 40 -- Badlands (35-45) within the level: only its faction makes it red
    local tab = open()
    local list = rows(tab)
    eq(list[1].name.text, "Badlands", "listed with Safe for me off")
    eq(list[1].level.textColor[2], 0.3, "the enemy zone's Level is red")
    eq(list[2].level.textColor[2], 1, "the own zone within the level is not")
    local function names()
        local found = {}
        for _, row in ipairs(rows(open())) do
            found[row.name.text] = true
        end
        return found
    end
    ns.BestPlaces.SetSafe(true)
    local shown = names()
    assert(shown.Wetlands and not shown.Badlands, "Safe for me on: the Horde zone stays, the Alliance zone is hidden")
    player_faction = "Alliance" -- read when the list is read; a filter change redraws
    ns.BestPlaces.SetContinent("eastern")
    ns.BestPlaces.SetContinent("all")
    shown = names()
    assert(shown.Badlands and not shown.Wetlands, "for the Alliance only Badlands")
    ns.GameData.ZoneFactions[3302] = "Horde" -- now every zone with data is the Horde's
    ns.Fire("PRICES_CHANGED")
    tab = open()
    eq(#rows(tab), 0, "only enemy zones hold data")
    eq(tab.status.text, L["Nothing matches the filters."], "the empty text (US1 scenario 5)")
    ns.GameData.ZoneFactions[3301], ns.GameData.ZoneFactions[3302], ns.GameData.ZoneLevels[3301] = nil, nil, nil
    ns.Fire("PRICES_CHANGED")
    player_faction, player_level = "Horde", 33 -- Safe for me stays on, as the tests before left it
end)

test("hiding Containers changes the gold at once; Skill, Source and the rest reset at a login", function()
    local tab = open()
    ns.Catalog.SetKindShown("containers", false)
    eq(rows(tab)[1].name.text, "Wetlands", "Badlands earned only by chests")
    ns.Catalog.SetKindShown("containers", true)
    ns.BestPlacesTab.SetSource("mine")
    tab = open()
    eq(#rows(tab), 0, "nothing of mine")
    ns.BestPlacesTab.SetSource("all")
end)
