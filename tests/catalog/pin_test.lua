-- The map pin (specs/005-catch-catalog, research R6, data-model.md "Pin target"): Catalog.PinTarget and
-- CatalogTab.Pin. The tests run in order and share one login.

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
local Catalog = ns.Catalog
local SPOT = { point = { x = 0.45, y = 0.72 } }

local toasts = {}
ns.Toast = function(text) table.insert(toasts, text) end

---------------------------------------------------------------------------
-- PinTarget
---------------------------------------------------------------------------
test("an allowed map takes the pin at the spot's point", function()
    waypoint_maps[1415] = true
    local target = Catalog.PinTarget(1415, SPOT)
    eq(target.mapID, 1415, "map")
    eq(target.x, 0.45, "x")
    eq(target.y, 0.72, "y")
end)

test("a cave that refuses goes to its zone's map through the world position", function()
    map_types[5000], map_parents[5000], waypoint_maps[5001] = Enum.UIMapType.Micro, 5001, true
    map_world[5000] = { 0, 100, 200, 10, 10 }
    map_world[5001] = { 0, 0, 0, 1000, 1000 }
    local target = Catalog.PinTarget(5000, SPOT)
    eq(target.mapID, 5001, "the parent")
    near(target.x, 0.1045, "x on the parent")
    near(target.y, 0.2072, "y on the parent")
    map_world[5000] = { 0, 990, 200, 100, 10 }
    eq(Catalog.PinTarget(5000, SPOT), nil, "a point outside the parent's 0..1")
end)

test("a dungeon, cell x and the game rule get no pin", function()
    map_types[5100], map_parents[5100] = Enum.UIMapType.Dungeon, 5001
    eq(Catalog.PinTarget(5100, SPOT), nil, "a dungeon never falls back")
    eq(Catalog.PinTarget(1415, {}), nil, "no point")
    game_rules[Enum.GameRule.WorldMapTrackingPinDisabled] = true
    eq(Catalog.PinTarget(1415, SPOT), nil, "pins turned off")
    game_rules = {}
end)

test("without the rule's value the check is skipped; without the waypoint API there is no pin", function()
    local rule = Enum.GameRule
    Enum.GameRule = { WorldMapTrackingPinDisabled = nil }
    assert(Catalog.PinTarget(1415, SPOT), "a missing value is no refusal")
    Enum.GameRule = nil
    assert(Catalog.PinTarget(1415, SPOT), "no Enum.GameRule either")
    Enum.GameRule = rule
    local set = C_Map.SetUserWaypoint
    C_Map.SetUserWaypoint = nil
    eq(Catalog.PinTarget(1415, SPOT), nil, "no SetUserWaypoint")
    C_Map.SetUserWaypoint = set
end)

---------------------------------------------------------------------------
-- CatalogTab.Pin
---------------------------------------------------------------------------
local TARGET = { mapID = 1415, x = 0.45, y = 0.72 }

test("no waypoint: the pin, the arrow, the saved pin, the toast and the map", function()
    ns.CatalogTab.Pin(TARGET, "Test Zone - Crystal Lake (45, 72)")
    eq(#waypoint_sets, 1, "set")
    eq(user_waypoint.uiMapID, 1415, "on the map")
    eq(user_waypoint.position.x, 0.45, "at the point")
    eq(super_tracked, true, "navigation on")
    eq(ns.charDB.pin.mapID, 1415, "saved")
    eq(toasts[#toasts], (L["Map pin: %s"]):format("Test Zone - Crystal Lake (45, 72)"), "toast")
    eq(world_maps_opened[#world_maps_opened], 1415, "the map opened")
end)

test("the addon's own pin is replaced without a question", function()
    reset_popup()
    user_waypoint = UiMapPoint.CreateFromCoordinates(1415, 0.4502, 0.7198) -- within PIN_EPSILON
    ns.CatalogTab.Pin({ mapID = 1415, x = 0.5, y = 0.5 }, "There")
    eq(rawget(_G, "last_popup"), nil, "no popup")
    eq(user_waypoint.position.x, 0.5, "replaced")
end)

test("a pin the player set: the question; Cancel keeps everything, Replace sets the pin", function()
    user_waypoint = UiMapPoint.CreateFromCoordinates(1429, 0.1, 0.1)
    local sets = #waypoint_sets
    ns.CatalogTab.Pin(TARGET, "Here")
    eq(last_popup, "ONEKEYFISHING_REPLACE_PIN", "asked")
    eq(StaticPopupDialogs.ONEKEYFISHING_REPLACE_PIN.text, L["Replace your map pin with this place?"], "the question")
    eq(StaticPopupDialogs.ONEKEYFISHING_REPLACE_PIN.button1, L["Replace"], "Replace")
    eq(StaticPopupDialogs.ONEKEYFISHING_REPLACE_PIN.button2, L["Cancel"], "Cancel")
    cancel_popup()
    eq(#waypoint_sets, sets, "nothing set")
    eq(user_waypoint.uiMapID, 1429, "the player's pin stays")
    eq(ns.charDB.pin.x, 0.5, "the saved pin stays")
    ns.CatalogTab.Pin(TARGET, "Here")
    accept_popup()
    eq(user_waypoint.uiMapID, 1415, "replaced")
    eq(ns.charDB.pin.x, 0.45, "saved")
end)

test("in combat the pin is set but no map opens", function()
    in_combat = true
    local opened = #world_maps_opened
    ns.CatalogTab.Pin(TARGET, "Here")
    eq(#world_maps_opened, opened, "no map")
    eq(user_waypoint.uiMapID, 1415, "the pin")
    in_combat = false
end)

test("a refused pin toasts and keeps nothing", function()
    ns.charDB.pin, user_waypoint, waypoint_result = nil, nil, false
    ns.CatalogTab.Pin(TARGET, "Here")
    eq(toasts[#toasts], L["The game did not accept the map pin."], "toast")
    eq(ns.charDB.pin, nil, "nothing saved")
    waypoint_result = nil
end)

---------------------------------------------------------------------------
-- The buttons on the catalog's spot rows
---------------------------------------------------------------------------
test("a pin button only on spot rows with a target, with its hover text", function()
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
    assert(toasts[#toasts]:find("Test Zone - ", 1, true), toasts[#toasts])
end)
