-- Catalog/BestPlaces.lua (specs/024-best-places): gold per hour (FR-001, research R1, R2), the top 10 (FR-002), Safe
-- for me (FR-007), the filters (FR-006), the unpriced mark (FR-015), the per-character state (FR-008).
-- The tests share one login and run in order.

local FISH, GEM, JUNK, CLAM = 6291, 6355, 6358, 5523 -- fish 10c, a chest 100c, a fish without a price, a clam
item_prices[FISH], item_prices[GEM], item_prices[CLAM] = 10, 100, 50

-- A zone of 60 catches and 10 misses in 700 s on map 3000 + n: the catch is FISH, plus GEM on the richer ones.
local cells = {}
for n = 1, 12 do
    cells[(3000 + n) .. ":0:55"] = { c = 60, m = 10, t = 700, k = 1, px = 30000, py = 30000,
        i = { [FISH] = { 60, 60 }, [GEM] = n > 1 and { n, n } or nil } }
end
cells["3100:0:55"] = { c = 20, m = 0, t = 200, k = 1, i = { [GEM] = { 20, 20 } } } -- little data
cells["3101:0:55"] = { c = 60, m = 0, t = 600, k = 1, i = { [JUNK] = { 40, 40 }, [FISH] = { 20, 20 } } } -- unpriced
for n = 1, 12 do
    map_parents[3000 + n] = n <= 6 and 1414 or 1415
end
map_types[1414], map_types[1415] = 2, 2
player_level = 10
player_map_id = 3001
load_addon(function()
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = cells }
end)

local BestPlaces = ns.BestPlaces
ns.GameData.ZoneLevels[3012] = { 50, 60 }
ns.GameData.ZoneLevels[3011] = { 13, 20 }
local FILTER = { range = "all", source = "all", water = "all", bonus = "all" }

local function zones()
    local list = BestPlaces.Zones(FILTER)
    flush_timers()
    list = BestPlaces.Zones(FILTER)
    local ids = {}
    for _, zone in ipairs(list) do
        table.insert(ids, zone.mapID)
    end
    return list, table.concat(ids, ",")
end

test("gold per hour is the value of one catch times the catches per hour (SC-001)", function()
    BestPlaces.SetSafe(false)
    local list = zones()
    local zone
    for _, entry in ipairs(list) do
        if entry.mapID == 3005 then
            zone = entry
        end
    end
    assert(zone, "zone 3005 listed")
    -- per catch: FISH 1 x 10c + GEM 5/60 x 100c; catches per hour 3600 x 60 / 700
    near(zone.goldPerHour, (10 + 5 / 60 * 100) * 3600 * 60 / 700, "gold per hour")
end)

test("at most ten zones, ordered by gold, none with little data (SC-002)", function()
    local list, ids = zones()
    eq(#list, 10, "ten")
    eq(ids, "3012,3011,3010,3009,3008,3007,3006,3005,3004,3003", "the richest first; 3100 has little data")
end)

test("Safe for me hides a zone above the level plus 3, not one at plus 3 or without levels (FR-007)", function()
    BestPlaces.SetSafe(true)
    local _, ids = zones()
    assert(not ids:find("3012"), "3012 (50-60) hidden at level 10")
    assert(ids:find("3011"), "3011 (13-20) at level 10 + 3 stays")
    eq(BestPlaces.Unsafe({ levels = { min = 13 } }), true, "13 above 10: red")
    eq(BestPlaces.Unsafe({}), false, "no levels: never red")
end)

test("hidden kinds count nothing: a place whose whole catch is hidden is not listed (FR-006)", function()
    ns.Catalog.SetKindShown("fish", false)
    local _, ids = zones()
    assert(not ids:find("3001"), "3001 caught only fish: " .. ids)
    eq(ids:sub(1, 4), "3011", "the zones with GEM still rank (3012 is above Safe for me)")
    ns.Catalog.SetKindShown("fish", true)
end)

test("an item without a price counts 0, and a third or more without a price marks the place (FR-015)", function()
    local view = ns.CatchDB.QueryMap(3101, FILTER)
    local spots = BestPlaces.Spots(3101, FILTER)
    near(spots[1].unpriced, 40 / 60, "two thirds of the pieces have no price")
    assert(spots[1].unpriced >= BestPlaces.UNPRICED_MARK, "marked")
    near(spots[1].goldPerHour, (20 / 60 * 10) * 3600 * 60 / 600, "only FISH earns")
    eq(view.catches, 60, "the view")
end)

test("Continent keeps the zones of one continent; the setters fire once per change (FR-006, FR-008)", function()
    local fired = {}
    ns.On("SETTINGS_CHANGED", function(key) table.insert(fired, key) end)
    BestPlaces.SetContinent("kalimdor")
    BestPlaces.SetContinent("kalimdor")
    local _, ids = zones()
    eq(ids, "3006,3005,3004,3003,3002,3001", "Kalimdor's zones")
    eq(ns.charDB.bestPlaces.continent, "kalimdor", "saved per character")
    eq(table.concat(fired, ","), "bestPlaces", "one message")
    BestPlaces.SetContinent("eastern")
    _, ids = zones()
    eq(ids, "3011,3010,3009,3008,3007", "the Eastern Kingdoms' safe zones")
    BestPlaces.SetContinent("all")
    BestPlaces.SetContinent("nope")
    eq(BestPlaces.GetContinent(), "all", "an unknown value is not written")
end)

test("the zone's levels come from the game and the tooltip's top items carry their share", function()
    eq(select(2, BestPlaces.ZoneLevels(3011)), 20, "max")
    eq(BestPlaces.ZoneLevels(1452), 55, "a zone of the table: Winterspring 55-60")
    eq(BestPlaces.ZoneLevels(3005), nil, "no levels")
    BestPlaces.SetSafe(false)
    local list = zones()
    local top = list[1].top
    eq(top[1].itemID, GEM, "GEM brings the most at 3012")
    near(top[1].share + top[2].share, 1, "the shares add up")
end)

test("the Skill filter sums the ranges up to the chosen one (spec 021): 225+ data stays out of range 0", function()
    BestPlaces.SetSafe(false)
    -- the account's own catch, the richest place, only at skill 225+ (range 3)
    ns.db.shared.mine["3200:3:55"] = { c = 60, m = 0, t = 60, i = { [GEM] = { 60, 60 } } }
    ns.Fire("SHARED_DATA_CHANGED")
    local function mine(range)
        local filter = { range = range, source = "mine", water = "all", bonus = "all" }
        BestPlaces.Zones(filter)
        flush_timers()
        return BestPlaces.Zones(filter)
    end
    eq(#mine(0), 0, "3200 was fished only at 225+: not up to 0-74")
    eq(mine("all")[1].mapID, 3200, "with every range it is listed")
end)

-- Findings of the first review of spec 024.
local function gold(mapID)
    for _, zone in ipairs(BestPlaces.Zones(FILTER)) do
        if zone.mapID == mapID then
            return zone.goldPerHour
        end
    end
end

test("a price switch of the settings, or an item's info arriving, moves the gold", function()
    BestPlaces.SetSafe(false)
    zones()
    local before = gold(3005)
    item_prices[GEM] = 1000
    ns.Fire("SETTINGS_CHANGED", "auctionPrices")
    flush_timers()
    BestPlaces.Zones(FILTER)
    flush_timers()
    assert(gold(3005) > before, "the new price counts after the switch")
    local function spotGold()
        return BestPlaces.Spots(3101, FILTER)[1].goldPerHour -- 3101 earns too little for the top 10
    end
    local mid = spotGold()
    item_prices[JUNK] = 500 -- counted without a price until its info loads
    fire("GET_ITEM_INFO_RECEIVED", JUNK, true)
    advance(0.5)
    assert(spotGold() > mid, "the loaded price counts a moment later")
    item_prices[JUNK] = nil
    item_prices[GEM] = 100
    ns.Fire("SETTINGS_CHANGED", "auctionPrices")
    flush_timers()
end)

test("a build keeps its own filter when the caller changes its table; nothing shows while building", function()
    local filter = { range = 2, source = "mine", water = "all", bonus = "all" }
    local list, state = BestPlaces.Zones(filter)
    eq(state, "building", "a new filter builds in frame steps")
    eq(#list, 0, "no half-built list")
    filter.source = "all" -- the tab changes its own table in place
    flush_timers()
    local mine = BestPlaces.Zones({ range = 2, source = "mine", water = "all", bonus = "all" })
    eq(#mine, 0, "the account caught nothing up to 150-224 except at 3200 (225+): no other player's zones")
end)

-- Findings of the second review of spec 024.
test("a new catch on one map moves the version, so the open tab redraws", function()
    player_map_id, player_map_position, fishing_rank = 3001, { 0.5, 0.5 }, 1
    fish_cast({ { GEM, 1 } }) -- the first: an item new to the own catch moves every map
    zones()
    local before = BestPlaces.GetVersion()
    fish_cast({ { GEM, 1 } }) -- the second moves only this map
    BestPlaces.Zones(FILTER) -- one changed map: recomputed by the read
    assert(BestPlaces.GetVersion() > before, "the version moved")
end)

test("Safe for me only filters, no recount; loading an item never counted without a price changes nothing", function()
    zones()
    BestPlaces.SetSafe(not BestPlaces.GetSafe())
    local _, state = BestPlaces.Zones(FILTER)
    eq(state, "ready", "no rebuild for Safe for me")
    BestPlaces.SetSafe(false)
    local before = BestPlaces.GetVersion()
    fire("GET_ITEM_INFO_RECEIVED", 99999, true)
    advance(1)
    eq(BestPlaces.GetVersion(), before, "an item not counted without a price")
end)

test("a level-up redraws a second later, when UnitLevel gives the new level", function()
    local before = BestPlaces.GetVersion()
    fire("PLAYER_LEVEL_UP", 11)
    eq(BestPlaces.GetVersion(), before, "not at once")
    advance(1)
    assert(BestPlaces.GetVersion() > before, "a second later")
end)

-- Low findings of the review, confirmed and fixed.
test("only the latest two rankings are kept, as the catalog keeps two indexes", function()
    for range = 0, 3 do
        BestPlaces.Zones({ range = range, source = "all", water = "all", bonus = "all" })
    end
    local kept = 0
    for _, line in ipairs(BestPlaces.Describe()) do
        if line:find("^best places ") then
            kept = kept + 1
        end
    end
    eq(kept, 2, "two rankings")
end)

test("a continent map (old records kept a cave's catch there) is no place to rank; capitals read 1-60", function()
    ns.db.shared.mine["1414:0:55"] = { c = 100, m = 0, t = 100, i = { [GEM] = { 100, 100 } } } -- the richest
    ns.Fire("SHARED_DATA_CHANGED")
    local filter = { range = "all", source = "mine", water = "all", bonus = "all" }
    BestPlaces.Zones(filter)
    flush_timers()
    for _, zone in ipairs(BestPlaces.Zones(filter)) do
        assert(zone.mapID ~= 1414, "Kalimdor itself is not ranked")
    end
    eq(table.concat({ BestPlaces.ZoneLevels(1454) }, "-"), "1-60", "Orgrimmar")
    eq(table.concat({ BestPlaces.ZoneLevels(1450) }, "-"), "1-60", "Moonglade")
end)

test("an item whose info comes with no price still (a quest item, a trophy) never recounts again", function()
    zones()
    local before = BestPlaces.GetVersion()
    item_prices[JUNK] = nil
    BestPlaces.Spots(3101, FILTER) -- JUNK counted without a price
    fire("GET_ITEM_INFO_RECEIVED", JUNK, true)
    advance(1)
    eq(BestPlaces.GetVersion(), before, "no recount for a price that stays 0")
end)

test("a cave or building map inside a zone takes its zone's level range", function()
    map_types[3990], map_parents[3990] = 4, 1452 -- a Micro map inside Winterspring
    eq(table.concat({ BestPlaces.ZoneLevels(3990) }, "-"), "55-60", "Winterspring's")
end)

test("a ranking dropped while it builds stops its steps", function()
    for range = 0, 2 do
        BestPlaces.Zones({ range = range, source = "all", water = "pool", bonus = "all" }) -- three new filters
    end
    flush_timers()
    local kept = 0
    for _, line in ipairs(BestPlaces.Describe()) do
        kept = kept + (line:find("^best places ") and 1 or 0)
    end
    eq(kept, 2, "only the latest two built")
    check_no_errors()
end)
