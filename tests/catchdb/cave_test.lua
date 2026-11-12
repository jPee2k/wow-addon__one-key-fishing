-- CatchDB.lua: a cast where the game reports a continent (spec 011, User Story 2). In the cave before Wailing
-- Caverns the game gives Kalimdor 1414 (type 2) as the player's map; the zone under the point is The Barrens 1413,
-- with a position on it (both seen 2026-11-08). The tests run in order and share one login.

local FISH = 6291

player_map_id = 1414
map_types = { [1414] = 2 }
player_map_position = { 0.52, 0.55 }
map_at_position = { [1414] = { mapID = 1413, mapType = 3 } }
player_map_positions = { [1413] = { 0.461, 0.30 } }
fishing_rank = 230
load_addon()

local CatchDB = ns.CatchDB
local shared = ns.db.shared

test("on a continent the place is the zone under the point, with its cell and position", function()
    local mapID, range, cell, x, y = CatchDB.GetCurrentPlace()
    eq(mapID, 1413, "The Barrens, not Kalimdor")
    eq(range, 3, "range")
    eq(cell, "43", "the cell on the zone map")
    near(x, 0.461, "x on the zone")
    near(y, 0.30, "y on the zone")
end)

test("a cast on the continent is recorded on the zone, never on the continent", function()
    fish_cast({ { FISH, 1 } })
    eq(shared.mine["1413:3:43"].c, 1, "the catch on the zone")
    for key in pairs(shared.mine) do
        assert(not key:find("^1414:"), "no continent key: " .. key)
    end
end)

test("no zone under the point, another continent, or no position: no place, nothing recorded", function()
    map_at_position = {}
    eq(CatchDB.GetCurrentPlace(), nil, "no zone under the point")
    map_at_position = { [1414] = { mapID = 1415, mapType = 2 } }
    eq(CatchDB.GetCurrentPlace(), nil, "a continent under the point")
    map_at_position = { [1414] = { mapID = 1413, mapType = 3 } }
    player_map_positions = {}
    player_map_position = { 0.52, 0.55 }
    -- Without its own entry the zone falls back to player_map_position: take it away for the zone only.
    local getPosition = C_Map.GetPlayerMapPosition
    C_Map.GetPlayerMapPosition = function(mapID, unit)
        if mapID == 1413 then
            return nil
        end
        return getPosition(mapID, unit)
    end
    eq(CatchDB.GetCurrentPlace(), nil, "no position on the zone")
    C_Map.GetPlayerMapPosition = getPosition
    player_map_position = nil
    eq(CatchDB.GetCurrentPlace(), nil, "no position on the continent")
    local before = shared.mine["1413:3:43"].c
    fish_cast({ { FISH, 1 } })
    eq(shared.mine["1413:3:43"].c, before, "nothing recorded")
    for key in pairs(shared.mine) do
        assert(not key:find("^1414:"), "no continent key: " .. key)
    end
    player_map_position = { 0.52, 0.55 }
    player_map_positions = { [1413] = { 0.461, 0.30 } }
end)

test("on a zone map nothing changes and no map under the point is asked for", function()
    player_map_id = 1413
    map_types[1413] = 3
    local asked = 0
    local getAt = C_Map.GetMapInfoAtPosition
    C_Map.GetMapInfoAtPosition = function(...)
        asked = asked + 1
        return getAt(...)
    end
    local mapID, _, cell = CatchDB.GetCurrentPlace()
    eq(mapID, 1413, "the zone itself")
    eq(cell, "43", "its cell")
    eq(asked, 0, "no lookup on a zone")
    C_Map.GetMapInfoAtPosition = getAt
    player_map_id = 1414
end)
