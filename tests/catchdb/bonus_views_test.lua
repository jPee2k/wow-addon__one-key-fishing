-- The camp bonus filter in the sums (specs/020-camp-buffs FR-013, FR-025, FR-026, research R6): a key sums the parts
-- with its bit, "none" is the cell minus all its parts, "all" is the cell. The tests run in order and share one login.

local FISH, BLOATED, OIL = 6291, 6643, 6358
local RACK = 1280341

player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230

local function seedCell(c, m, items, k, q)
    local cell = catch_cell(c, m, items)
    cell.k, cell.q = k, q
    return cell
end

local function seedData()
    return { epoch = 1, absorbed = {}, resets = {}, cells = {
        ["1415:3:47"] = seedCell(40, 10, { [FISH] = { 30, 30 }, [BLOATED] = { 4, 4 }, [OIL] = { 6, 6 } }, 3, {
            ["1"] = { c = 10, m = 2, k = 2, i = { [FISH] = { 6, 6 }, [BLOATED] = { 4, 4 } } },
            ["3"] = { c = 4, m = 1, k = 1, i = { [FISH] = { 4, 4 } } },
            ["4"] = { c = 2, m = 0, k = 1, i = { [FISH] = { 2, 2 } } },
        }),
        ["1416:3:x"] = seedCell(60, 0, { [FISH] = { 60, 60 } }, 2,
            { ["1"] = { c = 49, m = 0, k = 2, i = { [FISH] = { 49, 49 } } } }),
        ["1417:3:x"] = seedCell(10, 2, { [FISH] = { 10, 10 } }, 1),
        ["1418:3:x"] = (function()
            local cell = seedCell(20, 0, { [FISH] = { 20, 20 } }, 6,
                { ["1"] = { c = 15, m = 0, k = 4, r = 55, i = { [FISH] = { 15, 15 } } } })
            cell.r = 60
            return cell
        end)(),
    } }
end

OneKeyFishingDB = { shareNotice = true }
load_addon(function()
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = {} }
end)

local CatchDB = ns.CatchDB

local function filter(bonus, water)
    return { range = "all", source = "all", water = water or "all", bonus = bonus }
end

local function item(view, itemID)
    for _, entry in ipairs(view.items) do
        if entry.itemID == itemID then
            return entry
        end
    end
end

local function setSeed(cells)
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = cells }
    ns.Fire("SHARED_DATA_CHANGED")
end

---------------------------------------------------------------------------
-- HasBonusData (FR-024, FR-027, research R6): the button shows only over data a view uses
---------------------------------------------------------------------------
test("HasBonusData: none without a part; a part of an unknown bit counts for nothing", function()
    eq(CatchDB.HasBonusData(), false, "nothing")
    eq(CatchDB.HasBonusData("rack"), false, "no Rack")
    setSeed({ ["1500:3:x"] = seedCell(5, 0, { [FISH] = { 5, 5 } }, 1,
        { ["4"] = { c = 2, m = 0, k = 1, i = { [FISH] = { 2, 2 } } } }) })
    eq(CatchDB.HasBonusData(), false, "a part under \"4\" alone")
end)

test("HasBonusData: a seed part counts for the bonuses of its bits", function()
    setSeed({ ["1500:3:x"] = seedCell(5, 0, { [FISH] = { 5, 5 } }, 1,
        { ["1"] = { c = 2, m = 0, k = 1, i = { [FISH] = { 2, 2 } } } }) })
    eq(CatchDB.HasBonusData(), true, "any")
    eq(CatchDB.HasBonusData("rack"), true, "the Rack")
    eq(CatchDB.HasBonusData("hut"), false, "not the Hut")
    setSeed({})
    eq(CatchDB.HasBonusData(), false, "gone with the seed's part")
end)

test("HasBonusData: the own first cast under a buff", function()
    player_map_id = 1499
    auras[RACK] = { expirationTime = GetTime() + 3000, duration = 3600 }
    fire("UNIT_AURA", "player")
    eq(CatchDB.HasBonusData(), false, "before the cast")
    fish_cast({ { FISH, 1 } })
    eq(CatchDB.HasBonusData("rack"), true, "after it")
    auras[RACK] = nil
    fire("UNIT_AURA", "player")
    player_map_id = 1415
end)

test("HasBonusData: a received record counts while sharing is on, and not after it left", function()
    eq(CatchDB.HasBonusData("hut"), false, "no Hut yet")
    local cell = catch_cell(3, 0, { [FISH] = { 3, 3 } })
    cell.q = { ["2"] = { c = 1, m = 0, i = { [FISH] = { 1, 1 } } } }
    eq(ns.Share.Store.Accept(ns.db.shared, prove({ id = "hhhhhhhh", epoch = 0, seq = 1,
        builds = { ["1.60.1"] = { ["1501:3:x"] = cell } } })), "new", "stored")
    eq(CatchDB.HasBonusData("hut"), true, "the record's Hut part")
    ns.Share.SetEnabled(false)
    eq(CatchDB.HasBonusData("hut"), false, "sharing off: not used")
    ns.Share.SetEnabled(true)
    eq(CatchDB.HasBonusData("hut"), true, "sharing on again")
    ns.db.shared.records["hhhhhhhh@0"] = nil
    ns.Fire("SHARED_DATA_CHANGED", { "hhhhhhhh@0" }, ns.db.shared)
    eq(CatchDB.HasBonusData("hut"), false, "false again once the record left")
    setSeed(seedData().cells)
end)

---------------------------------------------------------------------------
-- The filter
---------------------------------------------------------------------------
test("the own catch under the Rack and another player's under the Hut", function()
    auras[RACK] = { expirationTime = GetTime() + 3000, duration = 3600 }
    fire("UNIT_AURA", "player")
    for _ = 1, 3 do
        fish_cast({ { FISH, 1 } })
    end
    fish_cast(nil)
    auras[RACK] = nil
    fire("UNIT_AURA", "player")
    local cell = catch_cell(5, 1, { [FISH] = { 5, 5 } })
    cell.q = { ["2"] = { c = 2, m = 1, i = { [FISH] = { 2, 2 } } } }
    eq(ns.Share.Store.Accept(ns.db.shared, prove({ id = "qqqqqqqq", epoch = 0, seq = 1,
        builds = { ["1.60.1"] = { ["1415:3:47"] = cell } } })), "new", "stored")
end)

test("\"rack\": the parts with bit 1 (\"1\" and \"3\") of the seed and the own catch", function()
    local view = CatchDB.QueryMap(1415, filter("rack"))
    eq(view.catches, 10 + 4 + 3, "catches")
    eq(view.misses, 2 + 1 + 1, "misses")
    eq(item(view, FISH).catches, 6 + 4 + 3, "fish")
    eq(item(view, BLOATED).catches, 4, "Bloated fish")
    eq(item(view, OIL), nil, "no oil under the Rack")
    near(view.missRate, 4 / 21, "the miss rate")
end)

test("\"hut\": \"2\" and \"3\"; \"none\": the cell minus all parts, mask 3 once", function()
    local hut = CatchDB.QueryMap(1415, filter("hut"))
    eq(hut.catches, 4 + 2, "Hut catches")
    eq(hut.misses, 1 + 1, "Hut misses")
    local none = CatchDB.QueryMap(1415, filter("none"))
    -- seed 40 - 10 - 4 - 2 (the part "4" is left out too), own 3 - 3, the other 5 - 2
    eq(none.catches, 24 + 0 + 3, "no bonus catches")
    eq(none.misses, 7 + 0 + 0, "no bonus misses")
    eq(item(none, FISH).catches, 18 + 3, "fish")
    eq(item(none, BLOATED), nil, "no Bloated fish without a bonus")
    eq(item(none, OIL).catches, 6, "oil")
end)

test("\"all\" and a missing bonus are the unfiltered numbers", function()
    local all = CatchDB.QueryMap(1415, filter("all"))
    local missing = CatchDB.QueryMap(1415, { range = "all", source = "all", water = "all" })
    eq(all.catches, 40 + 3 + 5, "catches")
    eq(missing.catches, all.catches, "a missing bonus")
    eq(item(missing, FISH).catches, item(all, FISH).catches, "fish")
end)

test("a cell without q counts for \"all\" and \"none\", never for a key", function()
    eq(CatchDB.QueryMap(1417, filter("rack")).catches, 0, "rack")
    eq(CatchDB.QueryMap(1417, filter("rack")).scope, "none", "nothing under the Rack")
    eq(CatchDB.QueryMap(1417, filter("none")).catches, 10, "none")
    eq(CatchDB.QueryMap(1417, filter("all")).catches, 10, "all")
end)

test("littleData follows the filtered catches: 49 under the Rack, then 50", function()
    eq(CatchDB.QueryMap(1416, filter("rack")).littleData, true, "49")
    local data = seedData()
    data.cells["1416:3:x"].q["1"] = { c = 50, m = 0, k = 2, i = { [FISH] = { 50, 50 } } }
    ns.SeedData = data
    ns.Fire("SHARED_DATA_CHANGED")
    eq(CatchDB.QueryMap(1416, filter("rack")).littleData, false, "50")
end)

test("a seed part's players and raw catches count under its key; \"none\" keeps the cell's players", function()
    local rack = CatchDB.QueryMap(1418, filter("rack"))
    eq(rack.players, 4, "the part's players")
    eq(rack.catches, 55, "the part's raw catches")
    eq(rack.littleData, false, "55 raw catches: enough")
    local none = CatchDB.QueryMap(1418, filter("none"))
    eq(none.catches, 5, "the rest, without raw catches")
    eq(none.players, 6, "the cell's players")
end)

test("a weighted seed cell without parts reads the same under \"none\" as under \"all\" (r and x kept)", function()
    local data = seedData()
    local cell = seedCell(20, 4, { [FISH] = { 20, 20 } }, 5)
    cell.r, cell.x = 60, 30
    data.cells["1419:3:x"] = cell
    setSeed(data.cells)
    local all = CatchDB.QueryMap(1419, filter("all"))
    local none = CatchDB.QueryMap(1419, filter("none"))
    eq(all.catches, 60, "the raw catches under \"all\"")
    eq(none.catches, all.catches, "the same under \"none\"")
    eq(none.littleData, all.littleData, "the same threshold")
    near(none.missRate, all.missRate, "the same miss rate")
    eq(none.players, all.players, "the same players")
end)

test("FilterKey tells the four values apart; a missing bonus is \"all\"", function()
    local keys = {}
    for _, bonus in ipairs({ "all", "none", "rack", "hut" }) do
        local key = CatchDB.FilterKey(filter(bonus))
        assert(not keys[key], "distinct key for " .. bonus)
        keys[key] = true
    end
    eq(CatchDB.FilterKey({ range = "all", source = "all", water = "all" }), CatchDB.FilterKey(filter("all")),
        "missing equals all")
end)

test("under a bonus filter the water filter changes nothing", function()
    local plain = CatchDB.QueryMap(1415, filter("rack"))
    local pool = CatchDB.QueryMap(1415, filter("rack", "pool"))
    eq(pool.catches, plain.catches, "catches")
    near(pool.missRate, plain.missRate, "the miss rate stays")
end)

test("BonusKeys lists the bonuses in rank order", function()
    local keys = CatchDB.BonusKeys()
    eq(#keys, 2, "two")
    eq(keys[1], "rack", "first")
    eq(keys[2], "hut", "second")
end)
