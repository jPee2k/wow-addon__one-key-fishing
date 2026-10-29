-- UI/MapPin.lua: where the game's map pin can go and setting it (spec 001, User Story 3, FR-022).

load_addon()

local MapPin = ns.MapPin
local MAPS = { 1434, 224 } -- candidates: the Classic map ID first, then the modern one
map_info_missing[1434], map_info_missing[224] = true, true -- unknown to the client until a test says otherwise

test("no target while the client knows none of the candidate maps", function()
    eq(MapPin.Target(MAPS, 0.274, 0.77), nil, "target")
end)

test("the first candidate the client knows and allows pins on wins", function()
    map_info_missing[224], pin_maps[224] = nil, true
    eq(MapPin.Target(MAPS, 0.274, 0.77).mapID, 224, "only the modern map works")
    map_info_missing[1434] = nil
    eq(MapPin.Target(MAPS, 0.274, 0.77).mapID, 224, "a known map without pins is skipped")
    pin_maps[1434] = true
    local target = MapPin.Target(MAPS, 0.274, 0.77)
    eq(target.mapID, 1434, "the Classic map first")
    near(target.x, 0.274, "x")
    near(target.y, 0.77, "y")
end)

test("no target while the game rule turns map pins off", function()
    pins_disabled = true
    eq(MapPin.Target(MAPS, 0.274, 0.77), nil, "target")
    pins_disabled = false
end)

test("no target without the waypoint API", function()
    local saved = C_Map.SetUserWaypoint
    C_Map.SetUserWaypoint = nil -- the field falls back to a stub, which is not a function
    eq(MapPin.Target(MAPS, 0.274, 0.77), nil, "target")
    C_Map.SetUserWaypoint = saved
end)

test("setting a pin: waypoint, navigation arrow, saved, the map opens", function()
    MapPin.Set({ mapID = 1434, x = 0.274, y = 0.77 }, "Booty Bay")
    eq(user_waypoint.uiMapID, 1434, "waypoint map")
    near(user_waypoint.position.x, 0.274, "waypoint x")
    eq(super_tracked, true, "navigation arrow")
    eq(ns.charDB.pin.mapID, 1434, "saved as the addon's pin")
    eq(opened_map, 1434, "world map opened")
end)

test("the addon's own pin is replaced without asking; in combat the map stays closed", function()
    reset_popup()
    opened_map = nil
    in_combat = true
    MapPin.Set({ mapID = 1445, x = 0.586, y = 0.602 }, "Tidefury Cove")
    eq(rawget(_G, "last_popup"), nil, "no popup")
    eq(user_waypoint.uiMapID, 1445, "replaced")
    eq(rawget(_G, "opened_map"), nil, "no world map in combat")
    in_combat = false
end)

test("a pin the player set is replaced only after a confirmation", function()
    user_waypoint = { uiMapID = 5, position = { x = 0.1, y = 0.1 } }
    reset_popup()
    MapPin.Set({ mapID = 1434, x = 0.274, y = 0.77 }, "Booty Bay")
    eq(rawget(_G, "last_popup"), "ONEKEYFISHING_REPLACE_PIN", "popup")
    eq(user_waypoint.uiMapID, 5, "not replaced before the answer")
    accept_popup()
    eq(user_waypoint.uiMapID, 1434, "replaced after the answer")
end)

test("a pin already at the place (set through the chat link) is replaced without asking", function()
    ns.charDB.pin = nil
    user_waypoint = { uiMapID = 1445, position = { x = 0.586, y = 0.602 } }
    reset_popup()
    MapPin.Set({ mapID = 1445, x = 0.586, y = 0.602 }, "Tidefury Cove")
    eq(rawget(_G, "last_popup"), nil, "no popup")
    eq(ns.charDB.pin.mapID, 1445, "now the addon's pin")
end)

test("a pin the game refuses is not saved", function()
    local saved = C_Map.SetUserWaypoint
    C_Map.SetUserWaypoint = function() return false end
    ns.charDB.pin = nil
    user_waypoint = nil
    MapPin.Set({ mapID = 1445, x = 0.586, y = 0.602 }, "Tidefury Cove")
    eq(ns.charDB.pin, nil, "not saved")
    C_Map.SetUserWaypoint = saved
end)
