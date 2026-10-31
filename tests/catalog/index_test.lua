-- Catalog.lua (specs/005-catch-catalog): the index across every map, the items and their names, the places, the
-- zone names, Find, CommandArg and Describe. The tests run in order and share one login.

local FISH, TROUT, PIKE, KOREAN, CHINESE, BOOT, OWN, UNKNOWN, OTHERS = 6291, 6303, 6304, 6305, 6306, 6307, 6308,
    88888, 77777

item_names[FISH] = "Deviate Fish"
item_names[TROUT] = "Truite \195\137" -- E acute
item_names[PIKE] = "\208\169\209\131\208\186\208\176" -- Shchuka, a capital first
item_names[KOREAN] = "\235\172\188\234\179\160\234\184\176"
item_names[CHINESE] = "\233\177\188"
item_names[BOOT] = "Rusty Boot"
item_qualities[BOOT] = 0
item_names[OWN] = "Own Fish"
item_names[OTHERS] = "Far Fish"
unknown_items[UNKNOWN] = true

local function cell(c, items, k)
    local out = catch_cell(c, 0, items)
    out.k = k or 1
    return out
end

player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
load_addon(function()
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = {
        ["1415:3:47"] = cell(100, { [FISH] = { 30, 30 }, [TROUT] = { 70, 70 } }, 3),
        ["1416:3:11"] = cell(60, { [FISH] = { 40, 40 }, [PIKE] = { 20, 20 } }, 2),
        ["1417:3:11"] = cell(10, { [FISH] = { 3, 3 }, [KOREAN] = { 7, 7 } }),
        ["1418:3:11"] = cell(10, { [FISH] = { 8, 8 }, [CHINESE] = { 2, 2 } }),
        ["1419:3:11"] = cell(10, { [FISH] = { 8, 8 }, [BOOT] = { 1, 1 }, [UNKNOWN] = { 1, 1 } }),
    } }
end)

local Catalog, CatchDB = ns.Catalog, ns.CatchDB
local ALL = { range = "all", source = "all", water = "all" }

-- Runs the timers due now that exist already, not the ones they create: one frame step of every chain.
local function one_step()
    local due = {}
    for i = #timers, 1, -1 do
        if timers[i].at <= now then
            table.insert(due, 1, table.remove(timers, i))
        end
    end
    for _, timer in ipairs(due) do
        timer.fn()
    end
    return #due
end

-- Adds seed cells: the seed is read as a new table, as a new version of the addon brings it.
local function add_seed(cells)
    local seed = {}
    for key, value in pairs(ns.SeedData) do
        seed[key] = value
    end
    seed.cells = {}
    for key, value in pairs(ns.SeedData.cells) do
        seed.cells[key] = value
    end
    for key, value in pairs(cells) do
        seed.cells[key] = value
    end
    ns.SeedData = seed
    ns.Fire("SHARED_DATA_CHANGED")
end

local function describe()
    return table.concat(Catalog.Describe(), "\n")
end

local function ids(list)
    local out = {}
    for i, row in ipairs(list) do
        out[i] = type(row) == "table" and (row.itemID or row.mapID) or row
    end
    return table.concat(out, ",")
end

-- A read, then the frame steps it started: the index after every change so far.
local function settle()
    Catalog.Items(ALL)
    advance(0)
end

local function zonesOf(itemID, filter)
    for _, row in ipairs((Catalog.Items(filter or ALL))) do
        if row.itemID == itemID then
            return row.zones
        end
    end
end

---------------------------------------------------------------------------
-- The index
---------------------------------------------------------------------------
test("the default index is built 10 s after the first loading screen of the session", function()
    advance(9)
    eq(describe():match("^[^\n]*"), "no index yet", "not before")
    advance(1)
    assert(describe():find("index all|all|all: ready, stale false, 5 maps", 1, true), describe())
end)

test("a later loading screen does not start it again", function()
    local maps, reads = CatchDB.Maps, 0
    CatchDB.Maps = function(...)
        reads = reads + 1
        return maps(...)
    end
    enter_world(false, false)
    advance(11)
    CatchDB.Maps = maps
    eq(reads, 0, "the index was not read again")
end)

test("a first build runs in steps: building until the last one, then ready", function()
    local cells = {}
    for i = 1, 20 do
        cells[(2000 + i) .. ":2:11"] = cell(5, { [FISH] = { 5, 5 } })
    end
    add_seed(cells)
    local filter = { range = 2, source = "all", water = "all" }
    local items, state = Catalog.Items(filter)
    eq(state, "building", "the first read starts it")
    eq(#items, 0, "nothing yet")
    one_step()
    assert(describe():find("this build 1 steps of at most 8 maps", 1, true), "8 maps without a clock: " .. describe())
    eq(select(2, Catalog.Items(filter)), "building", "still building")
    advance(0) -- the other steps: 25 maps, 8 a step
    assert(describe():find("this build 4 steps of at most 8 maps", 1, true), describe())
    items, state = Catalog.Items(filter)
    eq(state, "ready", "after the last step")
    eq(ids(items), tostring(FISH), "the item of range 2")
    eq(items[1].zones, 20, "on 20 maps")
end)

test("with a clock, every step ends at STEP_MS", function()
    profile_ms, profile_step = 0, 1
    ns.Fire("SHARED_DATA_CHANGED")
    local filter = { range = "all", source = "mine", water = "all" }
    Catalog.Items(filter) -- another filter: the range 2 index is dropped for it
    Catalog.Items({ range = 2, source = "all", water = "all" })
    eq(select(2, Catalog.Items({ range = 2, source = "all", water = "all" })), "building", "built anew")
    one_step()
    assert(describe():find("this build 1 steps of at most 3 maps", 1, true), "3 ms at 1 ms a map: " .. describe())
    advance(0)
    assert(describe():find("longest step 4.0 ms", 1, true), describe())
    profile_ms, profile_step = nil, nil
end)

test("up to SYNC_MAPS changed maps: the next read is complete at once", function()
    fish_cast({ { FISH, 1 } }) -- the first own catch of the item moves every map
    settle()
    local version = Catalog.GetVersion()
    eq(zonesOf(FISH), 25, "5 + 20 maps")
    player_map_id = 3001
    fish_cast({ { FISH, 1 } })
    eq(zonesOf(FISH), 26, "the new map at once")
    assert(Catalog.GetVersion() > version, "the version grew")
    player_map_id = 1415
end)

test("more changed maps: the stale index answers, one build runs, the next read after it is new", function()
    local cells = {}
    for i = 1, 10 do
        cells[(4000 + i) .. ":3:11"] = cell(5, { [FISH] = { 5, 5 } })
    end
    add_seed(cells)
    eq(zonesOf(FISH), 26, "stale")
    assert(describe():find("ready, stale true", 1, true), describe())
    local count = #timers
    eq(zonesOf(FISH), 26, "still stale")
    eq(#timers, count, "no second build")
    advance(0)
    eq(zonesOf(FISH), 36, "the new maps")
end)

---------------------------------------------------------------------------
-- The items
---------------------------------------------------------------------------
test("the seed's, the own and other players' items are listed, sorted by name, each with its zones", function()
    fish_cast({ { OWN, 1 } })
    Catalog.Items(ALL)
    advance(0) -- an item new to the own catch moves every map
    for i = 1, 2 do
        local id = "rrrrrrr" .. ("ab"):sub(i, i)
        eq(ns.Share.Store.Accept(ns.db.shared, prove({ id = id, epoch = 0, seq = 1,
            builds = { ["1.60.1"] = { ["1500:3:11"] = catch_cell(5, 0, { [OTHERS] = { 5, 5 } }) } } })), "new", id)
    end
    local items = Catalog.Items(ALL)
    eq(ids(items), table.concat({ FISH, OWN, TROUT, PIKE, CHINESE, KOREAN }, ","), "by name; no grey, no unknown")
    for _, row in ipairs(items) do
        assert(row.zones >= 1 and row.name, "zones and name of " .. row.itemID)
    end
end)

test("an item only other players report shows from three contributions on its map", function()
    eq(zonesOf(OTHERS), nil, "two reports: not yet")
    eq(ns.Share.Store.Accept(ns.db.shared, prove({ id = "rrrrrrrc", epoch = 0, seq = 1,
        builds = { ["1.60.1"] = { ["1500:3:11"] = catch_cell(5, 0, { [OTHERS] = { 5, 5 } }) } } })), "new", "third")
    eq(zonesOf(OTHERS), 1, "three reports")
end)

test("sharing off drops other players' items", function()
    ns.Share.SetEnabled(false)
    settle()
    eq(zonesOf(OTHERS), nil, "gone")
    ns.Share.SetEnabled(true)
    settle()
    eq(zonesOf(OTHERS), 1, "back")
end)

test("an unknown item is hidden, asked for 20 per step, and listed once the game knows it", function()
    local cells = {}
    for i = 1, 24 do
        cells[(5000 + i) .. ":3:11"] = cell(5, { [90000 + i] = { 5, 5 } })
        unknown_items[90000 + i] = true
    end
    add_seed(cells)
    settle()
    local before = #item_load_requests
    Catalog.Items(ALL) -- the names of the new items are looked up here
    eq(#item_load_requests, before, "asked in a step, not in the read")
    one_step()
    eq(#item_load_requests - before, 20, "20 in the first step")
    one_step()
    eq(#item_load_requests - before, 24, "the rest in the next")
    eq(zonesOf(UNKNOWN), nil, "hidden")
    local version = Catalog.GetVersion()
    item_loaded(UNKNOWN, true)
    assert(Catalog.GetVersion() > version, "the version grew")
    eq(zonesOf(UNKNOWN), 1, "listed")
    one_step()
    eq(#item_load_requests - before, 24, "never asked twice")
end)

test("a grey item shows only with search text", function()
    eq(zonesOf(BOOT), nil, "hidden without a search")
    local found = Catalog.Items(ALL, "rusty")
    eq(ids(found), tostring(BOOT), "found by a search")
end)

test("a search in lower case finds names with capitals in every script (SC-001)", function()
    eq(ids(Catalog.Items(ALL, "truite \195\169")), tostring(TROUT), "Latin with an accent")
    eq(ids(Catalog.Items(ALL, "\209\137\209\131\208\186")), tostring(PIKE), "Cyrillic")
    eq(ids(Catalog.Items(ALL, "\234\179\160\234\184\176")), tostring(KOREAN), "Korean, part of the name")
    eq(ids(Catalog.Items(ALL, "\233\177\188")), tostring(CHINESE), "Chinese")
    eq(ids(Catalog.Items(ALL, "FISH")), FISH .. "," .. OTHERS .. "," .. OWN, "upper case finds lower case")
    eq(#Catalog.Items(ALL, "nothing like it"), 0, "no match")
end)

---------------------------------------------------------------------------
-- The places
---------------------------------------------------------------------------
test("places: reliable zones by chance, then little-data ones by the item's catches, ties by map", function()
    local places = Catalog.Places(FISH, ALL)
    local first = {}
    for i = 1, 4 do
        first[i] = places[i].mapID
    end
    eq(table.concat(first, ","), "1416,1415,1418,1419", "the order")
    eq(places[5].mapID, 2001, "then 5 catches of the item, before map 1417's 3")
    eq(places[#places - 1].mapID, 1417, "3 catches of the item")
    eq(places[#places].mapID, 3001, "the fewest last: the one own catch")
    local place = places[1]
    eq(place.name, "Test Zone", "name")
    near(place.chance, 40 / 60, "chance")
    eq(place.catches, 60, "the zone's catches")
    eq(place.players, 2, "players")
    eq(place.littleData, false, "reliable")
    eq(place.ranges.min, 3, "skill span")
    eq(places[3].littleData, true, "little data")
    eq(#Catalog.Places(424242, ALL), 0, "no places for an item outside the database")
end)

---------------------------------------------------------------------------
-- Names, Find, CommandArg, Describe
---------------------------------------------------------------------------
test("zone names: a zone, a map inside a zone, a dungeon, an unknown map", function()
    map_names[7001], map_names[7002], map_names[7003] = "Elwynn Forest", "Jasperlode Mine", "The Deadmines"
    map_types[7002], map_parents[7002] = Enum.UIMapType.Micro, 7001
    map_types[7003], map_parents[7003] = Enum.UIMapType.Dungeon, 7001
    map_info_missing[7004] = true
    eq(Catalog.ZoneName(7001), "Elwynn Forest", "a zone")
    eq(Catalog.ZoneName(7002), "Elwynn Forest - Jasperlode Mine", "a cave")
    eq(Catalog.ZoneName(7003), "Elwynn Forest - The Deadmines", "a dungeon")
    eq(Catalog.ZoneName(7004), (ns.L["Unknown zone (%d)"]):format(7004), "no map info")
end)

test("Find and CommandArg", function()
    eq(ids(Catalog.Find("deviate")), tostring(FISH), "Find by part of the name")
    eq(#Catalog.Find("fish"), 3, "three fish")
    eq(Catalog.CommandArg("|cff9d9d9d|Hitem:6291::::::::60:::::|h[Deviate Fish]|h|r"), FISH, "an item link")
    eq(Catalog.CommandArg(""), nil, "no text")
    eq(Catalog.CommandArg("  trout "), "trout", "text")
end)

test("Describe lists the state, maps, items, the build times and the name queue", function()
    local text = describe()
    assert(text:find("index all|all|all: ready, stale false, %d+ maps, %d+ items"), text)
    assert(text:find("last build no clock of work, longest step no clock", 1, true), text)
    assert(text:find("names known %d+, unknown %d+, requests sent %d+, queued 0"), text)
end)

test("the debug report holds the catalog section and no item name", function()
    local _, report = ns.Debug.Report()
    assert(report:find("-- Catch catalog --", 1, true), "section")
    assert(report:find("index all|all|all: ready", 1, true), "the index")
    for _, itemID in ipairs({ FISH, TROUT, OWN }) do
        assert(not report:find(item_names[itemID], 1, true), "no name of " .. itemID)
    end
end)

---------------------------------------------------------------------------
-- Spots (US1)
---------------------------------------------------------------------------
test("the spots of an item on a map: sorted like zones, each with its name, point and numbers", function()
    area_names[20] = "Crystal Lake"
    local function spot(c, item, x, y, a)
        local out = cell(c, { [FISH] = { item, item } })
        if x then
            out.px, out.py = math.floor(x * 1000 + 0.5) * c, math.floor(y * 1000 + 0.5) * c
        end
        out.a = a
        return out
    end
    add_seed({
        ["8000:3:47"] = spot(60, 30, 0.45, 0.72, { [20] = 60 }),
        ["8000:1:47"] = spot(10, 10, 0.45, 0.72),
        ["8000:3:12"] = spot(20, 5, 0.51, 0.66),
        ["8000:3:x"] = spot(5, 5),
    })
    local rows = Catalog.Spots(FISH, 8000, ALL)
    eq(#rows, 3, "three spots")
    eq(rows[1].cell, "47", "the reliable spot first")
    eq(rows[1].name, "Crystal Lake (45, 72)", "named after its subzone")
    near(rows[1].chance, 40 / 70, "chance")
    eq(rows[1].catches, 70, "the spot's catches")
    eq(rows[1].littleData, false, "reliable")
    eq(rows[1].ranges.min, 1, "skill span from")
    eq(rows[1].ranges.max, 3, "to")
    eq(rows[1].pin, nil, "no pin before US2")
    eq(rows[2].cell, "12", "little data, a tie by the item's catches: by cell")
    eq(rows[2].name, "51, 66", "the coordinates alone")
    eq(rows[3].name, ns.L["No exact spot"], "cell x")
    eq(rows[3].point, nil, "no point")
    assert(Catalog.Spots(FISH, 8000, ALL) == rows, "kept while the map does not change")
end)

test("SpotName", function()
    eq(Catalog.SpotName({ point = { x = 0.454, y = 0.716 }, area = 20 }), "Crystal Lake (45, 72)", "with an area")
    eq(Catalog.SpotName({ point = { x = 0.5, y = 0.1 }, area = 999 }), "50, 10", "an area without a name")
    eq(Catalog.SpotName({}), ns.L["No exact spot"], "no point")
end)

---------------------------------------------------------------------------
-- Tooltip lines (US3)
---------------------------------------------------------------------------
test("TooltipLines: up to three reliable zones by chance, with the players from 2 on", function()
    local lines = Catalog.TooltipLines(FISH)
    eq(#lines, 2, "the two reliable zones of the item")
    eq(lines[1].zone, "Test Zone", "the zone")
    local places = Catalog.Places(FISH, ALL)
    eq(lines[1].right, (ns.L["%s (%d players)"]):format("67%", 2), "40 of 60, two players")
    eq(lines[2].right, (ns.L["%s (%d players)"]):format(("%d%%"):format(math.floor(places[2].chance * 100 + 0.5)),
        places[2].players), "the next, with the own catch there")
    local trout = Catalog.TooltipLines(TROUT)
    eq(#trout, 1, "one zone")
end)

test("TooltipLines: without a reliable zone, the little-data ones by the item's catches; nil outside", function()
    local lines = Catalog.TooltipLines(KOREAN)
    eq(#lines, 1, "one zone")
    eq(lines[1].right, ns.L["Little data"], "little data, one player")
    eq(Catalog.TooltipLines(424242), nil, "an item outside the database")
    eq(#Catalog.TooltipLines(BOOT), 1, "a grey item still has lines")
end)

test("a new catch of the item is in the next TooltipLines without the catalog being opened (FR-028)", function()
    fish_cast({ { TROUT, 1 } }) -- the first own trout moves every map
    settle()
    player_map_id = 8100
    for _ = 1, 50 do
        fish_cast({ { TROUT, 1 } })
    end
    player_map_id = 1415
    local lines = Catalog.TooltipLines(TROUT)
    eq(#lines, 2, "the new map at once")
    eq(lines[1].right, "100%", "50 of 50, first")
end)

test("MinimapLines: nil outside fishing mode and with the setting off", function()
    eq(Catalog.MinimapLines(), nil, "not fishing")
    local active = ns.Mode.IsActive
    ns.Mode.IsActive = function() return true end
    ns.db.settings.tooltipChances = false
    eq(Catalog.MinimapLines(), nil, "setting off")
    ns.db.settings.tooltipChances = true
    ns.Mode.IsActive = active
end)

test("MinimapLines: the top three of the place, no grey or unknown items, and the footer", function()
    local active = ns.Mode.IsActive
    ns.Mode.IsActive = function() return true end
    player_map_id = 1419 -- 10 catches: FISH, the grey boot, the unknown item
    local lines = Catalog.MinimapLines()
    for _, item in ipairs(lines.items) do
        assert(item.name ~= "Rusty Boot", "no grey item")
    end
    eq(lines.items[1].name, "Deviate Fish", "the fish")
    eq(lines.items[1].right, ns.L["Little data"], "little data on the whole map")
    eq(lines.footer, (ns.L["%d catches"]):format(10), "the footer")
    player_map_id = 1415
    lines = Catalog.MinimapLines()
    local view = CatchDB.Query(1415, "47", { range = 3, source = "all", water = "all" })
    eq(view.scope, "spot", "the spot's own numbers")
    eq(lines.items[1].right, ("%d%%"):format(math.floor(view.items[1].chance * 100 + 0.5)), "chances at the spot")
    eq(#lines.items, 3, "the top three")
    eq(lines.footer, (ns.L["%d catches from %d players"]):format(view.catches, view.players), "the footer")
    player_map_id = 9999
    lines = Catalog.MinimapLines()
    eq(#lines.items, 0, "nothing")
    eq(lines.footer, ns.L["Nothing has been caught here yet."], "said so")
    player_map_id = 1415
    ns.Mode.IsActive = active
end)
