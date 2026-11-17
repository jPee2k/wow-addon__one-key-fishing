-- Catalog.lua: the order of the catalog's list (specs/017-catalog-sort): the saved order and its texts, the order by
-- price (the statistics' value) and by chance (the best place, little data last), ties by name. The tests run in
-- order and share one login; the price items and the chance items live on different maps, and each list is read
-- for one of the two sets.

-- The price set (T007): eleven items on map 1420, 10 catches each.
local A, B, C, D, E, F, G, H, I, J, K = 90101, 90102, 90103, 90104, 90105, 90106, 90107, 90108, 90109, 90110, 90111
local PRICE_SET = { A, B, C, D, E, F, G, H, I, J, K }
local NAMES = { "Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "Golf", "Hotel", "India", "Juliet", "Kilo" }
local VENDOR = { 5, 100, 50, 0, 100, 20, 0, 75, 20, 1, 30 }
for index, itemID in ipairs(PRICE_SET) do
    item_names[itemID] = NAMES[index]
    item_prices[itemID] = VENDOR[index]
end
item_qualities[K] = 0 -- grey: listed only with a search

-- The chance set (T011): five items on maps 1415 to 1418.
local CA, CB, CC, CD, CE = 90201, 90202, 90203, 90204, 90205
local CHANCE_SET = { CA, CB, CC, CD, CE }
for index, itemID in ipairs(CHANCE_SET) do
    item_names[itemID] = ({ "Amber", "Birch", "Cedar", "Dune", "Elm" })[index]
end

-- A seed cell (as tests/catalog/index_test.lua's helper): k is the cell's weight, 1 here; the skill range is the
-- middle part of the place's key, <mapID>:<range>:<cell>.
local function cell(c, items)
    local out = catch_cell(c, 0, items)
    out.k = 1
    return out
end

player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
load_addon(function()
    local priceItems = {}
    for _, itemID in ipairs(PRICE_SET) do
        priceItems[itemID] = { 10, 10 }
    end
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = {
        ["1420:3:47"] = cell(110, priceItems),
        ["1415:3:47"] = cell(100, { [CA] = { 60, 60 }, [CB] = { 30, 30 }, [CC] = { 10, 10 } }),
        ["1416:3:11"] = cell(10, { [CD] = { 10, 10 } }),
        ["1417:3:11"] = cell(10, { [CE] = { 5, 5 }, [CB] = { 5, 5 } }),
        ["1418:2:11"] = cell(80, { [CC] = { 80, 80 } }),
    } }
end)

local Catalog, L = ns.Catalog, ns.L
local ALL = { range = "all", source = "all", water = "all" }

-- The list of the filter (and search) once its index is ready: the index is built in frame steps, a new filter's
-- index starts empty, and the default one is built only 10 s after the loading screen.
local function settle(filter, search)
    Catalog.Items(filter, search)
    advance(0)
    local items, state = Catalog.Items(filter, search)
    eq(state, "ready", "the index is ready")
    return items
end

-- The item IDs of a list that belong to `set`, in the list's order, joined with ",".
local function ids(list, set)
    local member = {}
    for _, itemID in ipairs(set) do
        member[itemID] = true
    end
    local out = {}
    for _, row in ipairs(list) do
        if member[row.itemID] then
            table.insert(out, tostring(row.itemID))
        end
    end
    return table.concat(out, ",")
end

local function join(...)
    local out = {}
    for _, itemID in ipairs({ ... }) do
        table.insert(out, tostring(itemID))
    end
    return table.concat(out, ",")
end

---------------------------------------------------------------------------
-- The saved order (T003)
---------------------------------------------------------------------------
test("SORTS is the menu's order", function()
    eq(table.concat(Catalog.SORTS, ","), "name,price,chance", "orders")
end)

test("a fresh install sorts by name", function()
    eq(ns.db.settings.catalogSort, "name", "the default")
    eq(Catalog.GetSort(), "name", "read")
end)

test("SetSort writes the order and fires SETTINGS_CHANGED once; the same or an unknown order does nothing", function()
    local fired = {}
    ns.On("SETTINGS_CHANGED", function(key) table.insert(fired, key) end)
    Catalog.SetSort("price")
    eq(ns.db.settings.catalogSort, "price", "written")
    eq(Catalog.GetSort(), "price", "read")
    eq(table.concat(fired, ","), "catalogSort", "one message with the key")
    Catalog.SetSort("price")
    eq(#fired, 1, "the same order fires nothing")
    Catalog.SetSort("nope")
    eq(ns.db.settings.catalogSort, "price", "an unknown order is not written")
    eq(#fired, 1, "an unknown order fires nothing")
    Catalog.SetSort("name")
    eq(#fired, 2, "back to name")
end)

test("an unknown saved order (a later version's) reads as name and is left as it is", function()
    ns.db.settings.catalogSort = "later"
    eq(Catalog.GetSort(), "name", "read as name")
    eq(ns.db.settings.catalogSort, "later", "not rewritten")
    ns.db.settings.catalogSort = "name"
end)

test("SortText gives each order's text, Name for anything else", function()
    eq(Catalog.SortText("name"), L["Name"], "name")
    eq(Catalog.SortText("price"), L["Price"], "price")
    eq(Catalog.SortText("chance"), L["Chance"], "chance")
    eq(Catalog.SortText("later"), L["Name"], "unknown")
end)

---------------------------------------------------------------------------
-- By price (T007)
---------------------------------------------------------------------------
-- Every adjacent pair of the price set: the price not increasing, equal prices in name order.
local function assertPriceOrder(list)
    local previous
    for _, row in ipairs(list) do
        if row.itemID >= A and row.itemID <= K then
            if previous then
                local a, b = ns.Prices.Get(previous.itemID), ns.Prices.Get(row.itemID)
                assert(a > b or (a == b and ns.CompareText(previous.name, row.name)),
                    previous.name .. " before " .. row.name)
            end
            previous = row
        end
    end
end

test("by price: the statistics' value, highest first; ties and no price by name; few lots not used", function()
    ns.db.prices[C] = { price = 500, quantity = 20, lots = 10, time = 1 }
    ns.db.prices[D] = { price = 9999, quantity = 1, lots = 1, time = 1 }
    local byName = settle(ALL)
    eq(ids(byName, PRICE_SET), join(A, B, C, D, E, F, G, H, I, J), "by name, as before (SC-005)")
    Catalog.SetSort("price")
    local list = settle(ALL)
    eq(ids(list, PRICE_SET), join(C, B, E, H, F, I, A, J, D, G), "by price; the grey Kilo left out")
    assertPriceOrder(list)
    eq(ns.Prices.Get(C), 500, "the trusted auction price (SC-003)")
    eq(ns.Prices.Get(D), 0, "the few-lots price is not used")
    local rows = {}
    for _, row in ipairs(byName) do
        rows[row.itemID] = row
    end
    for _, row in ipairs(list) do
        if rows[row.itemID] then
            eq(row, rows[row.itemID], "the same row table")
        end
    end
end)

test("by price without auction prices: the vendor price", function()
    ns.db.settings.auctionPrices = false
    local list = settle(ALL)
    eq(ids(list, PRICE_SET), join(B, E, H, C, F, I, A, J, D, G), "vendor prices only")
    assertPriceOrder(list)
    ns.db.settings.auctionPrices = true
end)

test("by price with a search: the matches in the same order, a grey match by its price", function()
    local list = settle(ALL, "o")
    eq(ids(list, PRICE_SET), join(B, E, H, K, F, G), "Bravo, Echo, Hotel, Kilo, Foxtrot, Golf")
    assertPriceOrder(list)
end)

test("back to name: the list as before", function()
    Catalog.SetSort("name")
    eq(ids(settle(ALL), PRICE_SET), join(A, B, C, D, E, F, G, H, I, J), "by name")
end)

---------------------------------------------------------------------------
-- By chance (T011)
---------------------------------------------------------------------------
-- Every adjacent pair of the chance set: little data last, the chance not increasing, ties by name.
local function assertChanceOrder(list)
    local previous
    for _, row in ipairs(list) do
        if row.itemID >= CA and row.itemID <= CE then
            if previous then
                local ok
                if previous.littleData ~= row.littleData then
                    ok = row.littleData
                else
                    ok = previous.chance > row.chance
                        or (previous.chance == row.chance and ns.CompareText(previous.name, row.name))
                end
                assert(ok, previous.name .. " before " .. row.name)
            end
            previous = row
        end
    end
end

test("by chance: the best place's chance, highest first; little data last", function()
    Catalog.SetSort("chance")
    local list = settle(ALL)
    eq(ids(list, CHANCE_SET), join(CC, CA, CB, CD, CE), "Cedar (map 1418), Amber, Birch; Dune, Elm little data")
    assertChanceOrder(list)
    for _, row in ipairs(list) do
        if row.itemID == CB then
            eq(row.littleData, false, "Birch's best place has enough data")
            eq(row.chance, 0.3, "Birch's chance on map 1415, not the little-data 1417")
        elseif row.itemID == CD then
            eq(row.littleData, true, "Dune: little data only")
        end
        local first = Catalog.Places(row.itemID, ALL)[1]
        eq(row.chance, first.chance, "the chance of the first place of " .. row.name)
        eq(row.littleData, first.littleData, "the little data of the first place of " .. row.name)
    end
end)

test("by chance under a skill filter: the filtered index's places", function()
    local range3 = { range = 3, source = "all", water = "all" }
    local list = settle(range3)
    eq(ids(list, CHANCE_SET), join(CA, CB, CC, CD, CE), "map 1418 (range 2) left out: Cedar 0.1")
    assertChanceOrder(list)
    Catalog.SetSort("name")
end)
