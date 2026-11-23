-- CatchDB.IsOwnItem (specs/023-item-kinds, research R3): an item of the account's own catch (shared.mine and the
-- records of the own ID, every game version), never another player's item or a seed item.

local MINE, OWN_OLD, OTHER, SEEDED = 6291, 6303, 6358, 6359
OneKeyFishingDB = { shareNotice = true, shared = {
    mine = { ["3999:0:x"] = { c = 1, m = 0, t = 10, i = { [MINE] = { 1, 1 } } } },
    myID = "aaaaaaa2",
    records = {
        ["aaaaaaa2@0"] = { id = "aaaaaaa2", epoch = 0, seq = 1, seen = 1, proof = ("a"):rep(16),
            builds = { ["1.13.0"] = { ["3999:0:x"] = { c = 1, m = 0, t = 10, i = { [OWN_OLD] = { 1, 1 } } } } } },
        ["baaaaaa2@0"] = { id = "baaaaaa2", epoch = 0, seq = 1, seen = 1, proof = ("a"):rep(16),
            builds = { ["1.60.1"] = { ["3999:0:x"] = { c = 1, m = 0, t = 10, i = { [OTHER] = { 1, 1 } } } } } },
    } } }
player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
load_addon(function()
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {},
        cells = { ["3999:0:x"] = { c = 1, m = 0, t = 10, k = 1, i = { [SEEDED] = { 1, 1 } } } } }
end)

local CatchDB = ns.CatchDB

test("the own catch of every version counts; another player's and the seed's items do not", function()
    eq(CatchDB.IsOwnItem(MINE), true, "shared.mine")
    eq(CatchDB.IsOwnItem(OWN_OLD), true, "an own record of an older version")
    eq(CatchDB.IsOwnItem(OTHER), false, "another player's record")
    eq(CatchDB.IsOwnItem(SEEDED), false, "the seed")
end)

test("a settled catch of a new item is own at once", function()
    eq(CatchDB.IsOwnItem(13917), false, "not yet")
    fish_cast({ { 13917, 1 } })
    eq(CatchDB.IsOwnItem(13917), true, "after the catch")
end)
