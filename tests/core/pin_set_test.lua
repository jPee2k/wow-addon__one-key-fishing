-- Core/MapPin.lua MapPin.Set: setting the game's map pin on the player's click, for the next rank and the catch
-- catalog alike, and its answer through MAP_PIN_SET (spec 001 User Story 3, FR-022; specs/005-catch-catalog FR-012;
-- specs/008-architecture-alignment US3). Since spec 009 (research R5, contract P4) no pin opens the world map, in or
-- out of a fight: a map opened from addon code was tainted for a later fight. The tests run in order and share one
-- login.

load_addon()

local L = ns.L
local MapPin = ns.MapPin
local TARGET = { mapID = 1415, x = 0.45, y = 0.72 }

local toasts = {}
ns.Toast = function(text) table.insert(toasts, text) end -- UI/Toast.lua calls it at runtime

test("no waypoint: the pin, the tracking, the saved pin, one toast; the map stays closed", function()
    world_maps_opened = {}
    MapPin.Set(TARGET, "Test Zone - Crystal Lake (45, 72)")
    eq(#waypoint_sets, 1, "set")
    eq(user_waypoint.uiMapID, 1415, "on the map")
    near(user_waypoint.position.x, 0.45, "at the point")
    eq(super_tracked, true, "navigation arrow")
    eq(ns.charDB.pin.mapID, 1415, "saved as the addon's pin")
    eq(#toasts, 1, "one toast, through MAP_PIN_SET")
    eq(toasts[1], (L["Map pin: %s. Open the world map to see it."]):format("Test Zone - Crystal Lake (45, 72)"),
        "toast")
    eq(#world_maps_opened, 0, "the map stays closed")
end)

test("the addon's own pin is replaced without asking; in combat the map stays closed", function()
    reset_popup()
    world_maps_opened = {}
    in_combat = true
    user_waypoint = UiMapPoint.CreateFromCoordinates(1415, 0.4502, 0.7198) -- within the epsilon of the saved pin
    MapPin.Set({ mapID = 1445, x = 0.586, y = 0.602 }, "Tidefury Cove")
    eq(rawget(_G, "last_popup"), nil, "no popup")
    eq(user_waypoint.uiMapID, 1445, "replaced")
    eq(#world_maps_opened, 0, "no world map in combat")
    in_combat = false
end)

test("a pin already at the place is replaced without asking", function()
    ns.charDB.pin = nil
    user_waypoint = { uiMapID = 1415, position = { x = 0.45, y = 0.72 } }
    reset_popup()
    MapPin.Set(TARGET, "Here")
    eq(rawget(_G, "last_popup"), nil, "no popup")
    eq(ns.charDB.pin.mapID, 1415, "now the addon's pin")
end)

test("a pin the player set: the question; Cancel keeps everything, Replace sets the pin", function()
    user_waypoint = UiMapPoint.CreateFromCoordinates(1429, 0.1, 0.1)
    reset_popup()
    local sets = #waypoint_sets
    MapPin.Set({ mapID = 1445, x = 0.586, y = 0.602 }, "There")
    eq(last_popup, "ONEKEYFISHING_REPLACE_PIN", "asked")
    eq(StaticPopupDialogs.ONEKEYFISHING_REPLACE_PIN.text, L["Replace your map pin with this place?"], "the question")
    eq(StaticPopupDialogs.ONEKEYFISHING_REPLACE_PIN.button1, L["Replace"], "Replace")
    eq(StaticPopupDialogs.ONEKEYFISHING_REPLACE_PIN.button2, L["Cancel"], "Cancel")
    cancel_popup()
    eq(#waypoint_sets, sets, "nothing set")
    eq(user_waypoint.uiMapID, 1429, "the player's pin stays")
    eq(ns.charDB.pin.mapID, 1415, "the saved pin stays")
    MapPin.Set({ mapID = 1445, x = 0.586, y = 0.602 }, "There")
    world_maps_opened = {}
    accept_popup()
    eq(user_waypoint.uiMapID, 1445, "replaced")
    eq(ns.charDB.pin.mapID, 1445, "saved")
    eq(#world_maps_opened, 0, "no map after Replace")
end)

test("a pin the game refuses toasts and keeps nothing", function()
    ns.charDB.pin, user_waypoint, waypoint_result = nil, nil, false
    toasts = {}
    MapPin.Set(TARGET, "Here")
    eq(toasts[1], L["The game did not accept the map pin."], "toast")
    eq(#toasts, 1, "one toast")
    eq(ns.charDB.pin, nil, "not saved")
    waypoint_result = nil
end)
