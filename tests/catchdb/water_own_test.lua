-- CatchDB.HasPoolData and an own catch (specs/005-catch-catalog, research R5): since spec 011 (research R4) the
-- source of a catch is not known, so no own catch is pool data, even with a pool object as its loot source;
-- tests/catchdb/water_test.lua has the seed's pool data, tests/catchdb/water_record_test.lua a received record's.

player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
load_addon(function()
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = {} }
end)

test("an own catch is never pool data", function()
    fish_cast({ { 6291, 1 } })
    eq(ns.CatchDB.HasPoolData(), false, "an open water catch")
    fish_cast({ { 6291, 1 } }, 10, { [1] = "GameObject-0-1-2-3-180582-4" }) -- a pool object as the source
    eq(ns.CatchDB.HasPoolData(), false, "a catch with a pool source")
    eq(ns.db.shared.mine["1415:3:47"].p, nil, "no pool part")
end)
