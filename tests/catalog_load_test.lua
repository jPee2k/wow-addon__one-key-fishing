-- Catalog.lua with the largest database the addon allows (research R11, SC-003): 3,000 seed cells on 150 maps,
-- 20,000 places of 1,000 other players' records, 2,000 own cells. The frame budget cannot be measured here; the work
-- per step and per read is bounded instead (V39 measures the time in game).

local MAPS, FIRST_MAP = 150, 10001
local ITEM = 30000 -- items ITEM + 0 .. ITEM + 59

local function mapOf(i)
    return FIRST_MAP + (i - 1) % MAPS
end

local function cellOf(i)
    return ("%d%d"):format(math.floor(i / 10) % 10, i % 10)
end

local function items(i)
    local out = {}
    for j = 0, 2 do
        out[ITEM + (i + j * 7) % 60] = { 2, 2 }
    end
    return out
end

player_map_id = FIRST_MAP
player_map_position = { 0.05, 0.05 }
fishing_rank = 230
load_addon(function()
    local cells = {}
    for i = 1, 3000 do
        local cell = catch_cell(6, 1, items(i))
        cell.k = 1
        cells[mapOf(i) .. ":" .. (i % 5) .. ":" .. cellOf(math.floor(i / MAPS))] = cell
    end
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = cells }
end)

local shared = ns.db.shared
local own = shared.records[shared.myID]
own.builds["1.60.1"] = {}
for i = 1, 2000 do
    local key = mapOf(i) .. ":3:" .. cellOf(i % 100)
    shared.mine[key] = catch_cell(3, 0, items(i))
    own.builds["1.60.1"][key] = catch_cell(3, 0, items(i))
end
for r = 1, 1000 do
    local id = ns.Base32(r, 8)
    local cells = {}
    for p = 1, 20 do
        local i = r * 20 + p
        cells[mapOf(i) .. ":" .. (i % 5) .. ":" .. cellOf(i % 97)] = catch_cell(4, 0, items(i))
    end
    shared.records[id .. "@0"] = { id = id, epoch = 0, seq = 1, seen = 1, proof = ("a"):rep(16),
        builds = { ["1.60.1"] = cells } }
end
ns.Fire("SHARED_DATA_CHANGED")

local Catalog, CatchDB = ns.Catalog, ns.CatchDB
local ALL = { range = "all", source = "all", water = "all" }

test("the default index builds in steps of at most MAPS_PER_STEP maps", function()
    advance(10)
    local report = table.concat(Catalog.Describe(), "\n")
    assert(report:find("index all|all|all: ready, stale false, 150 maps, 60 items", 1, true), report)
    local steps = tonumber(report:match("this build (%d+) steps of at most 8 maps"))
    assert(steps and steps >= MAPS / 8, report)
    print(("  maps %d, items %d, steps %d"):format(MAPS, #Catalog.Items(ALL), steps))
end)

test("one own catch moves one map's stamp and recomputes one map", function()
    local before = {}
    for _, mapID in ipairs(CatchDB.Maps(ALL)) do
        before[mapID] = CatchDB.MapStamp(mapID)
    end
    fish_cast({ { ITEM + 1, 1 } }) -- an item of the own catch already: no other map changes
    local moved = 0
    for mapID, stamp in pairs(before) do
        if CatchDB.MapStamp(mapID) ~= stamp then
            moved = moved + 1
        end
    end
    eq(moved, 1, "maps moved")
    local queryMap, computed = CatchDB.QueryMap, 0
    CatchDB.QueryMap = function(...)
        computed = computed + 1
        return queryMap(...)
    end
    Catalog.Items(ALL)
    CatchDB.QueryMap = queryMap
    eq(computed, 1, "maps recomputed")
end)

test("a search over every name, the places of the most common item and the largest map's spots in one call",
    function()
    local list = Catalog.Items(ALL, "item")
    eq(#list, 60, "every item")
    local best, zones = nil, 0
    for _, row in ipairs(list) do
        if row.zones > zones then
            best, zones = row.itemID, row.zones
        end
    end
    eq(#Catalog.Places(best, ALL), zones, "every zone of the item")
    local largest, cells = nil, 0
    for _, mapID in ipairs(CatchDB.Maps(ALL)) do
        local count = #CatchDB.QueryCells(mapID, ALL)
        if count > cells then
            largest, cells = mapID, count
        end
    end
    assert(cells > 0, "spots")
    print(("  most common item on %d zones; largest map %d with %d spots"):format(zones, largest, cells))
end)
