-- Catalog.lua: the pin target of a catalog spot comes from Core/MapPin.lua (specs/005-catch-catalog research R6;
-- specs/008-architecture-alignment US3); a cell without a point gets none. The pin button of the spot rows
-- (UI/CatalogTab.lua) sets it through MapPin.Set. The tests run in order and share one login.

local FISH = 6291

player_map_id = 1415
fishing_rank = 230
load_addon(function()
    local cell = catch_cell(60, 0, { [FISH] = { 30, 30 } })
    cell.k, cell.px, cell.py = 2, 450 * 60, 720 * 60
    local nowhere = catch_cell(10, 0, { [FISH] = { 5, 5 } })
    nowhere.k = 1
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = { ["1415:3:47"] = cell, ["1415:3:x"] = nowhere } }
end)

local L = ns.L
local toasts = {}
ns.Toast = function(text) table.insert(toasts, text) end

local FILTER = { range = "all", source = "all", water = "all" }

local function Spots()
    ns.Catalog.Places(FISH, FILTER) -- the index is built on the first read
    advance(0)
    return ns.Catalog.Spots(FISH, 1415, FILTER)
end

test("a spot with a point gets the pin target of MapPin.Target; a cell without one gets none", function()
    waypoint_maps[1415] = true
    local spots = Spots()
    local withPoint, without
    for _, spot in ipairs(spots) do
        if spot.point then
            withPoint = spot
        else
            without = spot
        end
    end
    assert(withPoint and without, "both spots are listed")
    eq(withPoint.pin.mapID, 1415, "the spot's map")
    near(withPoint.pin.x, 0.45, "x")
    near(withPoint.pin.y, 0.72, "y")
    eq(without.pin, nil, "no point, no pin")
end)

test("a pin button only on spot rows with a target, with its hover text; a click sets the pin", function()
    ns.StatsFrame.OpenCatalog(FISH)
    advance(0)
    local tab = _G.OneKeyFishingStatsFrame.catalogPage
    ns.CatalogTab.Show(FISH)
    ns.CatalogTab.Toggle(1415)
    local rows = scroll_rows(tab.places.box)
    eq(#rows, 3, "the zone and two spots")
    assert(not rows[1].pinButton:IsShown(), "no button on the zone row")
    assert(rows[2].pinButton:IsShown(), "the spot with a point")
    assert(not rows[3].pinButton:IsShown(), "no exact spot: no button")
    rows[2].pinButton.scripts.OnEnter(rows[2].pinButton)
    eq(tooltip_lines[1], L["Set a map pin here"], "hover")
    user_waypoint = nil
    rows[2].pinButton.scripts.OnClick(rows[2].pinButton)
    eq(user_waypoint.uiMapID, 1415, "the pin from the button")
    eq(#toasts, 1, "one toast")
    assert(toasts[1]:find("Test Zone - ", 1, true), toasts[1])
end)
