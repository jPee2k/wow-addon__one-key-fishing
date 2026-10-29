-- CatchDB.lua with a bundled seed: merged with the own record, nothing counted twice, resets after a patch.

local FISH, OTHER = 6291, 6303
local ID = "k7f2q9xa"

local cellOf = catch_cell

-- Saved data of an earlier session: the own record (epoch 1) went into the seed of epoch 2.
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
        absorbed = { [ID] = 1 },
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

test("an absorbed record starts over at the seed's epoch; mine keeps its counts", function()
    local record = shared.records[ID]
    eq(record.epoch, 2, "new epoch")
    eq(record.seq, 0, "new record")
    eq(next(record.builds), nil, "empty")
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
