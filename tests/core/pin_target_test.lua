-- Core/MapPin.lua MapPin.Target: where the game's map pin for a point can go, for the next rank and the catch
-- catalog alike (spec 001 User Story 3; specs/005-catch-catalog research R6; specs/008-architecture-alignment US3).

load_addon()

local MapPin = ns.MapPin
local MAPS = { 1434, 224 } -- candidates: the Classic map ID first, then the modern one
map_info_missing[1434], map_info_missing[224] = true, true -- unknown to the client until a test says otherwise

test("no target while the client knows none of the candidate maps", function()
    eq(MapPin.Target(MAPS, 0.274, 0.77), nil, "target")
end)

test("the first candidate the client knows and allows pins on wins", function()
    map_info_missing[224], waypoint_maps[224] = nil, true
    eq(MapPin.Target(MAPS, 0.274, 0.77).mapID, 224, "only the modern map works")
    map_info_missing[1434] = nil
    eq(MapPin.Target(MAPS, 0.274, 0.77).mapID, 224, "a known map without pins is skipped")
    waypoint_maps[1434] = true
    local target = MapPin.Target(MAPS, 0.274, 0.77)
    eq(target.mapID, 1434, "the Classic map first")
    near(target.x, 0.274, "x")
    near(target.y, 0.77, "y")
end)

test("a cave that refuses goes to its zone's map through the world position", function()
    map_types[5000], map_parents[5000], waypoint_maps[5001] = Enum.UIMapType.Micro, 5001, true
    map_world[5000] = { 0, 100, 200, 10, 10 }
    map_world[5001] = { 0, 0, 0, 1000, 1000 }
    local target = MapPin.Target({ 5000 }, 0.45, 0.72)
    eq(target.mapID, 5001, "the parent")
    near(target.x, 0.1045, "x on the parent")
    near(target.y, 0.2072, "y on the parent")
    map_world[5000] = { 0, 990, 200, 100, 10 }
    eq(MapPin.Target({ 5000 }, 0.45, 0.72), nil, "a point outside the parent's 0..1")
end)

test("the cave fallback uses only the first candidate: the point is on that map", function()
    -- 6000 (the first candidate) is unknown to the client; 5000, a cave with a parent that takes pins, is known
    map_info_missing[6000] = true
    map_world[5000] = { 0, 100, 200, 10, 10 }
    eq(MapPin.Target({ 6000, 5000 }, 0.45, 0.72), nil, "no pin from another map's coordinates")
    map_info_missing[6000] = nil
end)

test("a dungeon never falls back to its zone", function()
    map_types[5100], map_parents[5100] = Enum.UIMapType.Dungeon, 5001
    eq(MapPin.Target({ 5100 }, 0.45, 0.72), nil, "a dungeon")
end)

test("no target while the game rule turns map pins off; without the rule's value the check is skipped", function()
    waypoint_maps[1415] = true
    game_rules[Enum.GameRule.WorldMapTrackingPinDisabled] = true
    eq(MapPin.Target({ 1415 }, 0.45, 0.72), nil, "pins turned off")
    game_rules[Enum.GameRule.WorldMapTrackingPinDisabled] = nil
    local rule = Enum.GameRule
    Enum.GameRule = { WorldMapTrackingPinDisabled = nil }
    assert(MapPin.Target({ 1415 }, 0.45, 0.72), "a missing value is no refusal")
    Enum.GameRule = nil
    assert(MapPin.Target({ 1415 }, 0.45, 0.72), "no Enum.GameRule either")
    Enum.GameRule = rule
end)

test("no target without the waypoint API or without a point", function()
    local saved = C_Map.SetUserWaypoint
    C_Map.SetUserWaypoint = nil -- the field falls back to a stub, which is not a function
    eq(MapPin.Target(MAPS, 0.274, 0.77), nil, "target")
    C_Map.SetUserWaypoint = saved
    eq(MapPin.Target({ 1415 }, nil, nil), nil, "no point")
end)
