-- CatchDB.HasPoolData from an own pool catch (specs/005-catch-catalog, research R5); tests/catchdb/water_test.lua
-- has the seed's pool data, tests/catchdb/water_record_test.lua a received record's.

player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
load_addon(function()
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = {} }
end)

test("an own pool catch is pool data", function()
    fish_cast({ { 6291, 1 } })
    eq(ns.CatchDB.HasPoolData(), false, "an open water catch")
    fish_cast({ { 6291, 1 } }, 10, { [1] = "GameObject-0-1-2-3-180582-4" }) -- from a pool
    eq(ns.CatchDB.HasPoolData(), true, "a pool catch")
end)
