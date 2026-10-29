-- CatchDB.lua: place keys, and recording into the account's lifetime counts (mine) and its contribution record.
-- The tests run in order and share one login: each starts where the previous ended.

local FISH, OTHER = 6291, 6303
local POOL_GUID = "GameObject-0-1-2-3-180582-4"
local BOBBER_GUID = "GameObject-0-1-2-3-35591-4"

player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
load_addon()

local CatchDB = ns.CatchDB
local KEY = "1415:3:47"

local function shared()
    return ns.db.shared
end

local function record()
    return shared().records[shared().myID]
end

local function own(key)
    return record().builds["1.60.1"][key or KEY]
end

local cast = fish_cast

---------------------------------------------------------------------------
-- Place key
---------------------------------------------------------------------------
test("a place key is map, skill range and cell", function()
    eq(CatchDB.PlaceKey(1415, 3, "47"), "1415:3:47")
end)

test("the current place comes from the map, the position and the rank", function()
    local mapID, range, cell = CatchDB.GetCurrentPlace()
    eq(mapID, 1415, "map")
    eq(range, 3, "rank 230 is range 3")
    eq(cell, "47", "x 0.43 -> 4, y 0.78 -> 7")
end)

test("the grid edge and a missing position", function()
    player_map_position = { 1.0, 1.0 }
    eq(select(3, CatchDB.GetCurrentPlace()), "99", "x and y of 1.0 stay in the grid")
    player_map_position = { 0, 0.05 }
    eq(select(3, CatchDB.GetCurrentPlace()), "00", "the first cell")
    player_map_position = nil
    eq(select(3, CatchDB.GetCurrentPlace()), "x", "no position: the whole map")
    player_map_position = { 0.43, 0.78 }
end)

test("skill ranges are steps of 75 points of the base rank, up to 4", function()
    local expected = { [0] = 0, [74] = 0, [75] = 1, [299] = 3, [300] = 4, [375] = 4 }
    for rank, range in pairs(expected) do
        fishing_rank = rank
        eq(select(2, CatchDB.GetCurrentPlace()), range, "rank " .. rank)
    end
    fishing_rank = nil
    eq(CatchDB.GetCurrentPlace(), nil, "no Fishing, no place")
    fishing_rank = 230
end)

test("a position a little outside the map stays inside it", function()
    player_map_position = { 1.02, -0.01 }
    local _, _, cell, x, y = CatchDB.GetCurrentPlace()
    eq(cell, "90", "the edge cells")
    eq(x, 1, "x clamped")
    eq(y, 0, "y clamped")
    player_map_position = { 0.43, 0.78 }
end)

test("every key matches the documented format", function()
    for _, position in ipairs({ { 0.43, 0.78 }, { 0.999, 0 }, false }) do
        player_map_position = position or nil
        local key = CatchDB.PlaceKey(CatchDB.GetCurrentPlace())
        assert(key:find("^%d+:[0-4]:%d%d$") or key:find("^%d+:[0-4]:x$"), key)
    end
    player_map_position = { 0.43, 0.78 }
end)

---------------------------------------------------------------------------
-- Recording
---------------------------------------------------------------------------
test("the account gets a random anonymous ID and its own record", function()
    local id = shared().myID
    assert(type(id) == "string" and #id == 8 and id:find("^[a-z2-7]+$"), "8 base32 characters: " .. tostring(id))
    eq(record().id, id, "the record carries the ID")
    eq(record().epoch, 0, "the epoch of the (empty) seed")
    fire("ADDON_LOADED", "OneKeyFishing")
    eq(shared().myID, id, "kept on the next load")
end)

test("a catch is recorded in mine and in the own record", function()
    local before = CatchDB.GetVersion()
    cast({ { FISH, 2 } })
    for name, cell in pairs({ mine = shared().mine[KEY], record = own() }) do
        eq(cell.c, 1, name .. " catches")
        eq(cell.m, 0, name .. " misses")
        eq(cell.t, 10, name .. " seconds casting")
        eq(cell.i[FISH][1], 1, name .. " catches with the fish")
        eq(cell.i[FISH][2], 2, name .. " pieces")
        eq(cell.px, 430, name .. " x sum")
        eq(cell.py, 780, name .. " y sum")
    end
    assert(CatchDB.GetVersion() > before, "version bumped")
end)

test("a cast without loot is a miss", function()
    cast(nil, 6)
    eq(own().m, 1, "miss")
    eq(own().c, 1, "catches unchanged")
    eq(own().t, 16, "its time counts too")
end)

test("two items in one catch count one catch each", function()
    cast({ { FISH, 1 }, { OTHER, 3 } })
    eq(own().c, 2, "catches")
    eq(own().i[FISH][1], 2, "catches with the fish")
    eq(own().i[OTHER][1], 1, "catches with the other item")
    eq(own().i[OTHER][2], 3, "pieces of the other item")
end)

test("a loot quantity of 0 counts as one piece", function()
    cast({ { OTHER, 0 } })
    eq(own().i[OTHER][2], 4, "3 + 1: pieces never fall below the catches")
end)

test("pieces per catch are capped at 20", function()
    cast({ { OTHER, 50 } })
    eq(own().i[OTHER][2], 24, "4 + 20")
end)

test("the place is the one where the cast started", function()
    ns.Fire("FISHING_CAST_START", 7620)
    player_map_position = { 0.91, 0.12 }
    advance(5)
    loot = { fishing = true, items = { { FISH, 1 } } }
    fire("LOOT_READY")
    loot = nil
    ns.Fire("FISHING_CAST_STOP", 7620)
    advance(2)
    eq(shared().mine["1415:3:91"], nil, "nothing at the new spot")
    eq(own().c, 5, "counted at the start spot (the fifth catch there)")
    player_map_position = { 0.43, 0.78 }
end)

test("a cast picked up after a /reload records its catch once, at the place read then", function()
    ns.charDB.countedCast = 123456 -- Stats skips counting the cast itself; CatchDB counts nothing at the start
    player_map_position = { 0.15, 0.25 }
    cast({ { FISH, 1 } }, 3)
    local cell = own("1415:3:12")
    eq(cell.c, 1, "one catch")
    eq(cell.t, 3, "time from the pickup")
    player_map_position = { 0.43, 0.78 }
end)

test("fishing loot without a cast in fishing mode records nothing", function()
    local catches = own().c
    loot = { fishing = true, items = { { FISH, 1 } } }
    fire("LOOT_READY")
    loot = nil
    advance(2)
    eq(own().c, catches, "unchanged")
end)

test("the record's seq grows at most once a minute, and on logout", function()
    local seq = record().seq
    advance(61)
    cast({ { FISH, 1 } })
    eq(record().seq, seq + 1, "more than a minute after the last bump")
    cast({ { FISH, 1 } })
    eq(record().seq, seq + 1, "within a minute of the last bump")
    fire("PLAYER_LOGOUT")
    eq(record().seq, seq + 2, "a change waiting for its bump is bumped on logout")
    fire("PLAYER_LOGOUT")
    eq(record().seq, seq + 2, "nothing waiting, no bump")
end)

---------------------------------------------------------------------------
-- Pools
---------------------------------------------------------------------------
test("pool loot also goes into the pool part", function()
    cast({ { FISH, 2 } }, 10, { [1] = POOL_GUID })
    local pool = own().p
    assert(pool, "pool part")
    eq(pool.c, 1, "pool catches")
    eq(pool.i[FISH][1], 1, "pool catches with the fish")
    eq(pool.i[FISH][2], 2, "pool pieces")
end)

test("bobber loot and loot without a source have no pool part", function()
    local cell = "1415:3:55"
    player_map_position = { 0.55, 0.55 }
    cast({ { FISH, 1 } }, 10, { [1] = BOBBER_GUID })
    cast({ { FISH, 1 } })
    eq(own(cell).c, 2, "both counted")
    eq(own(cell).p, nil, "no pool part")
    player_map_position = { 0.43, 0.78 }
end)

test("IsPoolLoot tells the pool, the bobber and no source apart", function()
    loot = { fishing = true, items = { { FISH, 1 } } }
    loot_sources = { [1] = POOL_GUID }
    eq(ns.IsPoolLoot(), true, "pool")
    loot_sources = { [1] = BOBBER_GUID }
    eq(ns.IsPoolLoot(), false, "bobber")
    loot_sources = {}
    eq(ns.IsPoolLoot(), nil, "no source")
    loot = nil
end)

---------------------------------------------------------------------------
-- Query (own data only: the seed is empty here)
---------------------------------------------------------------------------
local cellOf = catch_cell

-- Data on map 2000, written straight into the tables: the own record (source "all") and mine.
local recordCells = record().builds["1.60.1"]
recordCells["2000:3:11"] = cellOf(60, 6, { [FISH] = { 33, 40 }, [OTHER] = { 27, 27 } })
recordCells["2000:3:22"] = cellOf(20, 0, { [FISH] = { 20, 20 } })
recordCells["2000:3:x"] = cellOf(250, 10, { [OTHER] = { 250, 300 } })
recordCells["2000:1:22"] = cellOf(5, 1, { [FISH] = { 5, 5 } })
recordCells["2001:3:22"] = cellOf(20, 2, { [FISH] = { 20, 20 } })
recordCells["2001:3:33"] = cellOf(10, 0, { [FISH] = { 10, 10 } })
shared().mine["2000:3:11"] = cellOf(4, 1, { [FISH] = { 4, 4 } })

local ALL = { range = 3, source = "all" }

test("a spot with 50 or more catches shows its own numbers", function()
    local view = CatchDB.Query(2000, "11", ALL)
    eq(view.scope, "spot", "scope")
    eq(view.littleData, false, "enough data")
    eq(view.catches, 60, "catches")
    eq(view.misses, 6, "misses")
    eq(view.items[1].itemID, FISH, "highest chance first")
    near(view.items[1].chance, 33 / 60, "chance: catches with the item / all catches")
    near(view.items[1].pieces, 40 / 33, "pieces per catch with the item")
    eq(view.items[2].itemID, OTHER, "then the other item")
end)

test("a spot with fewer than 50 catches falls back to the whole map", function()
    local view = CatchDB.Query(2000, "22", ALL)
    eq(view.scope, "map", "scope")
    eq(view.littleData, false, "the map has enough")
    eq(view.catches, 60 + 20 + 250, "every cell of the map in the range, the x cell included")
end)

test("a map with fewer than 50 catches is little data", function()
    local view = CatchDB.Query(2001, "22", ALL)
    eq(view.scope, "map", "scope")
    eq(view.littleData, true, "little data")
    eq(view.catches, 30, "catches")
end)

test("nothing caught on the map is scope none", function()
    local view = CatchDB.Query(2002, "22", ALL)
    eq(view.scope, "none", "scope")
    eq(#view.items, 0, "no items")
end)

test("only misses on the map is scope none too", function()
    recordCells["2003:3:22"] = cellOf(0, 3) -- a map not queried before, so nothing is cached for it
    local view = CatchDB.Query(2003, "22", { range = 3, source = "all" })
    eq(view.scope, "none", "nothing caught")
end)

test("the skill filter: one range or all ranges", function()
    eq(CatchDB.Query(2000, "22", { range = 1, source = "all" }).catches, 5, "range 1 only (map fallback)")
    eq(CatchDB.Query(2000, "22", { range = "all", source = "all" }).catches, 60 + 20 + 250 + 5, "all ranges")
end)

test("the source filter: mine reads the lifetime counts", function()
    local view = CatchDB.Query(2000, "11", { range = 3, source = "mine" })
    eq(view.catches, 4, "mine")
    eq(view.scope, "map", "4 is too few for the spot")
end)

test("a query is cached until the data changes", function()
    local first = CatchDB.Query(2000, "11", ALL)
    eq(CatchDB.Query(2000, "11", ALL), first, "same view object")
    cast({ { FISH, 1 } })
    assert(CatchDB.Query(2000, "11", ALL) ~= first, "new view after a change")
end)

test("Describe gives lines for the debug report, without the anonymous ID", function()
    local text = table.concat(CatchDB.Describe(), "\n")
    assert(text:find("1415:3:47", 1, true), "current place: " .. text)
    assert(not text:find(shared().myID, 1, true), "no ID")
end)

test("the debug report has a catch database section without the anonymous ID", function()
    local report
    local show = ns.ShowCopyWindow
    ns.ShowCopyWindow = function(_, text) report = text end
    ns.ShowReport()
    ns.ShowCopyWindow = show
    assert(report:find("-- Catch database --", 1, true), "section")
    assert(report:find("current place 1415:3:47", 1, true), "current place")
    assert(report:find("last price scan:", 1, true), "price coverage")
    assert(not report:find(shared().myID, 1, true), "no ID")
end)
