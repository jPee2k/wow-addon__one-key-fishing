-- CatchDB.lua with a bundled seed: merged with the own record, nothing counted twice, resets after a patch.

local FISH, OTHER = 6291, 6303
local ID = "k7f2q6xa"

local cellOf = catch_cell

-- Saved data of an earlier session: the own record (epoch 1, seq 9) went whole into the seed of epoch 2.
OneKeyFishingDB = {
    schema = 1,
    shared = {
        myID = ID,
        mine = { ["1415:3:47"] = cellOf(30, 2, { [FISH] = { 30, 30 } }) },
        records = { [ID] = { id = ID, epoch = 1, seq = 9,
            builds = { ["1.60.1"] = { ["1415:3:47"] = cellOf(30, 2, { [FISH] = { 30, 30 } }) } } } },
    },
}
player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230

-- The seed of this release replaces the one SeedData.lua sets, before the login.
load_addon(function()
    ns.SeedData = {
        epoch = 2, built = "2026-12-01", build = "1.60.1",
        absorbed = { [ID] = { [1] = 9 } },
        resets = {},
        cells = {
            ["1415:3:47"] = cellOf(1000, 80, { [FISH] = { 700, 760 }, [OTHER] = { 300, 300 } }),
            ["1415:3:48"] = cellOf(10, 1, { [FISH] = { 10, 10 } }),
        },
    }
end)

local CatchDB = ns.CatchDB
local shared = ns.db.shared
local ALL = { range = 3, source = "all" }
local MINE = { range = 3, source = "mine" }

local cast = fish_cast

test("an own record the seed holds whole starts over at the seed's epoch; mine keeps its counts", function()
    local record = shared.records[ID]
    eq(record.epoch, 2, "new epoch")
    eq(record.seq, 0, "new record")
    eq(next(record.builds), nil, "empty")
    eq(shared.records[ID .. "@1"], nil, "the old one is not kept: the seed has all of it")
    eq(shared.mine["1415:3:47"].c, 30, "mine unchanged")
end)

test("All is the seed (it already holds the old record), Only mine the lifetime counts", function()
    eq(CatchDB.Query(1415, "47", ALL).catches, 1000, "seed only")
    eq(CatchDB.Query(1415, "47", MINE).catches, 30, "mine")
    eq(CatchDB.HasSeed(), true, "a seed is bundled")
end)

test("new own catches add to the seed exactly once", function()
    for _ = 1, 5 do
        cast({ { FISH, 1 } })
    end
    local view = CatchDB.Query(1415, "47", ALL)
    eq(view.catches, 1005, "1000 + 5")
    eq(view.items[1].itemID, FISH, "most caught first")
    near(view.items[1].chance, 705 / 1005, "chance")
    eq(CatchDB.Query(1415, "47", MINE).catches, 35, "mine")
end)

test("the map fallback sums the seed and the own record", function()
    local view = CatchDB.Query(1415, "48", ALL)
    eq(view.scope, "map", "10 at the spot is too few")
    eq(view.catches, 1015, "1000 + 10 + 5")
end)

test("a record the seed did not absorb counts in full", function()
    shared.records[ID] = { id = ID, epoch = 1, seq = 4,
        builds = { ["1.60.1"] = { ["1415:3:47"] = cellOf(7, 0, { [FISH] = { 7, 7 } }) } } }
    ns.SeedData.absorbed = {}
    fire("ADDON_LOADED", "OneKeyFishing")
    eq(shared.records[ID].epoch, 1, "kept")
    eq(CatchDB.Query(1415, "47", ALL).catches, 1007, "1000 + 7")
end)

test("after a reset of the map, own cells of older game versions are left out", function()
    shared.records[ID].builds["1.60.2"] = { ["1415:3:47"] = cellOf(3, 0, { [FISH] = { 3, 3 } }) }
    ns.SeedData.resets = { [1415] = "1.60.2" }
    fire("ADDON_LOADED", "OneKeyFishing")
    eq(CatchDB.Query(1415, "47", ALL).catches, 1003, "the 1.60.1 cell is left out, the 1.60.2 one counts")
    eq(CatchDB.Query(1415, "47", MINE).catches, 35, "mine keeps everything")
    ns.SeedData.resets = {}
end)

test("a missing or malformed seed counts as empty", function()
    local seed = ns.SeedData
    ns.SeedData = "not a table"
    fire("ADDON_LOADED", "OneKeyFishing")
    eq(CatchDB.HasSeed(), false, "no seed")
    eq(CatchDB.Query(1415, "47", ALL).catches, 7 + 3, "own record only")
    ns.SeedData = { epoch = 3, cells = "broken" }
    fire("ADDON_LOADED", "OneKeyFishing")
    eq(CatchDB.HasSeed(), false, "malformed")
    ns.SeedData = seed
    fire("ADDON_LOADED", "OneKeyFishing")
end)

test("a whole-world seed: the whole-map sums are right", function()
    local cells = {}
    for map = 1, 300 do
        for spot = 0, 9 do
            cells[(5000 + map) .. ":3:" .. spot .. spot] = cellOf(10, 1, { [FISH] = { 6, 6 }, [OTHER] = { 4, 8 } })
        end
    end
    ns.SeedData = { epoch = 2, built = "", build = "1.60.1", absorbed = {}, resets = {}, cells = cells }
    fire("ADDON_LOADED", "OneKeyFishing")
    local view = CatchDB.Query(5042, "33", ALL)
    eq(view.scope, "map", "10 catches at the spot")
    eq(view.catches, 100, "ten spots of the map")
    near(view.items[1].chance, 0.6, "chance on the map")
    eq(CatchDB.Query(5044, "11", { range = "all", source = "all" }).catches, 100, "all ranges")
    eq(CatchDB.Query(5301, "00", ALL).scope, "none", "a map outside the seed")
end)

test("a damaged own record starts over instead of breaking every catch", function()
    shared.records[ID] = { id = ID, epoch = 2 } -- no builds, no seq
    fire("ADDON_LOADED", "OneKeyFishing")
    eq(type(shared.records[ID].builds), "table", "a new record")
    cast({ { FISH, 1 } })
    eq(shared.records[ID].builds["1.60.1"]["1415:3:47"].c, 1, "catches are recorded again")
end)

test("other players' records: the reset rule applies to them; players add the seed's k without counting twice",
    function()
    ns.SeedData = { epoch = 3, built = "", build = "1.60.1", absorbed = { [ID] = { [1] = 9 }, qqqqqqqq = { [1] = 1 } },
        resets = {},
        cells = {
            ["1600:3:11"] = { c = 60, m = 0, t = 600, k = 3, i = { [FISH] = { 60, 60 } } },
            ["1600:3:22"] = { c = 10, m = 0, t = 100, k = 5, i = { [FISH] = { 10, 10 } } },
        } }
    fire("ADDON_LOADED", "OneKeyFishing")
    shared.records["rrrrrrrr@0"] = { id = "rrrrrrrr", epoch = 0, seq = 1, seen = 1, builds = {
        ["1.60.1"] = { ["1600:3:11"] = cellOf(20, 0, { [FISH] = { 20, 20 } }) },
        ["1.60.2"] = { ["1600:3:11"] = cellOf(5, 0, { [FISH] = { 5, 5 } }) } } }
    ns.Fire("SHARED_DATA_CHANGED")
    local view = CatchDB.Query(1600, "11", ALL)
    eq(view.catches, 85, "60 + 20 + 5")
    eq(view.players, 4, "k 3 of the seed cell + one record the seed never saw")
    ns.SeedData.resets = { [1600] = "1.60.2" }
    ns.Fire("SHARED_DATA_CHANGED")
    eq(CatchDB.Query(1600, "11", ALL).catches, 65, "the record's 1.60.1 cell is left out after the reset")
    ns.SeedData.resets = {}
    ns.Fire("SHARED_DATA_CHANGED")
    eq(CatchDB.Query(1600, "33", ALL).players, 6, "whole map: the largest k (5) + the record")
    -- A newer epoch of a player the seed already has may be one of its k: it only counts above them.
    shared.records["qqqqqqqq@2"] = { id = "qqqqqqqq", epoch = 2, seq = 1, seen = 1,
        builds = { ["1.60.1"] = { ["1600:3:11"] = cellOf(5, 0, { [FISH] = { 5, 5 } }) } } }
    ns.Fire("SHARED_DATA_CHANGED")
    eq(CatchDB.Query(1600, "11", ALL).players, 4, "still 4: q may be among the seed's 3")
end)

test("an own record the seed holds only up to an older seq is kept, not counted, and a new one starts", function()
    shared.records[ID] = { id = ID, epoch = 3, seq = 12,
        builds = { ["1.60.1"] = { ["1700:3:11"] = cellOf(12, 0, { [FISH] = { 12, 12 } }) } } }
    -- The author's harvest read the record at seq 8 (8 catches); this client went on to seq 12.
    ns.SeedData = { epoch = 4, built = "", build = "1.60.1", absorbed = { [ID] = { [3] = 8 } }, resets = {},
        cells = { ["1700:3:11"] = { c = 8, m = 0, t = 80, k = 1, i = { [FISH] = { 8, 8 } } } } }
    fire("ADDON_LOADED", "OneKeyFishing")
    local kept = shared.records[ID .. "@3"]
    assert(kept, "kept under <id>@<epoch> for the next harvest")
    eq(kept.seq, 12, "with its seq")
    eq(shared.records[ID].epoch, 4, "a new record at the seed's epoch")
    eq(shared.records[ID].seq, 0, "empty")
    eq(CatchDB.Query(1700, "11", ALL).catches, 8, "the seed only: the kept record's first 8 are in it")
    ns.Share.SetEnabled(false)
    eq(CatchDB.Query(1700, "11", ALL).catches, 8, "sharing off: the same")
    ns.Share.SetEnabled(true)
    eq(ns.Share.Store.Units(shared)[ID .. "@3"], 12, "offered to peers")
end)

test("a catch at a new place past 500 places rolls the own record; both count, with sharing off too", function()
    local own = shared.records[ID]
    local epoch = own.epoch
    own.builds = { ["1.60.1"] = {} }
    for i = 1, 500 do
        own.builds["1.60.1"][(8000 + i) .. ":3:x"] = cellOf(1, 0, { [FISH] = { 1, 1 } })
    end
    own.seq = 500
    player_map_id, player_map_position = 8001, nil
    cast({ { FISH, 1 } })
    eq(shared.records[ID].epoch, epoch, "a catch at a place the record has: no roll")
    eq(own.builds["1.60.1"]["8001:3:x"].c, 2, "counted")
    player_map_id, player_map_position = 1415, { 0.43, 0.78 }
    cast({ { FISH, 1 } })
    local kept = shared.records[ID .. "@" .. epoch]
    assert(kept, "rolled: the old record is kept")
    eq(CatchDB.CountPlaces(kept), 500, "with its 500 places")
    eq(shared.records[ID].epoch, epoch + 1, "a new epoch")
    eq(shared.records[ID].builds["1.60.1"]["1415:3:47"].c, 1, "the catch is in the new record")
    eq(CatchDB.Query(8001, "x", ALL).catches, 2, "the kept record counts")
    ns.Share.SetEnabled(false)
    eq(CatchDB.Query(8001, "x", ALL).catches, 2, "with sharing off too")
    ns.Share.SetEnabled(true)
    local ok, reason = CatchDB.CheckRecord(ns.Share.Store.ForSending(kept))
    eq(ok, true, "a peer would take it: " .. tostring(reason))
end)

test("a seed that holds the kept records whole deletes them; the live record stays", function()
    local live = shared.records[ID]
    ns.SeedData.absorbed = { [ID] = { [3] = 12, [live.epoch - 1] = shared.records[ID .. "@" .. (live.epoch - 1)].seq } }
    fire("ADDON_LOADED", "OneKeyFishing")
    eq(shared.records[ID .. "@3"], nil, "the first kept record went")
    eq(shared.records[ID .. "@" .. (live.epoch - 1)], nil, "the second too")
    eq(shared.records[ID], live, "the live record is not touched")
end)
