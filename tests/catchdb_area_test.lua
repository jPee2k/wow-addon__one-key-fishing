-- CatchDB.lua: the subzone of a cast (specs/005-catch-catalog, research R4, data-model.md "Cell"): read at the cast,
-- stored as a, checked in received records, summed into a spot's area. The tests run in order and share one login.

local FISH = 6291
local KEY = "1415:3:47"

player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
explored_areas = { 10, 20 }
area_names = { [10] = "Elwynn Forest", [20] = "Crystal Lake" }
sub_zone = "Crystal Lake"
load_addon()

local CatchDB = ns.CatchDB
local shared = ns.db.shared

local function own(key)
    return shared.records[shared.myID].builds["1.60.1"][key or KEY]
end

test("a cast keeps the explored area the game names as the subzone", function()
    eq(CatchDB.GetArea(1415, 0.43, 0.78), 20, "Crystal Lake")
    local lookup = area_lookups[#area_lookups]
    eq(lookup[1], 1415, "the map")
    near(lookup[2], 0.43, "x")
    near(lookup[3], 0.78, "y")
end)

test("a subzone that differs only in letter case, Cyrillic included, still matches (Principle II)", function()
    area_names[20] = "\208\154\209\128\208\184\209\136\209\130\208\176\208\187\209\140"
    sub_zone = "\208\186\209\128\208\184\209\136\209\130\208\176\208\187\209\140"
    eq(CatchDB.GetArea(1415, 0.43, 0.78), 20, "Kryshtal against kryshtal")
    area_names[20], sub_zone = "Crystal Lake", "CRYSTAL LAKE"
    eq(CatchDB.GetArea(1415, 0.43, 0.78), 20, "ASCII case")
    sub_zone = "Crystal Lake"
end)

test("no subzone text, no matching name or no position: no area", function()
    sub_zone = ""
    eq(CatchDB.GetArea(1415, 0.43, 0.78), nil, "empty subzone")
    sub_zone = "Somewhere Else"
    eq(CatchDB.GetArea(1415, 0.43, 0.78), nil, "no match")
    sub_zone = "Crystal Lake"
    eq(CatchDB.GetArea(1415, nil, nil), nil, "no position")
end)

test("a settled catch or miss adds 1 to the area in mine and the own record", function()
    fish_cast({ { FISH, 1 } })
    fish_cast(nil)
    eq(shared.mine[KEY].a[20], 2, "mine")
    eq(own().a[20], 2, "own record")
end)

test("a ninth area of a cell is not added; the eight keep counting", function()
    for areaID = 101, 107 do
        explored_areas, area_names[areaID], sub_zone = { areaID }, "Area " .. areaID, "Area " .. areaID
        fish_cast(nil)
    end
    eq(ns.CountKeys(shared.mine[KEY].a), 8, "eight areas")
    explored_areas, area_names[108], sub_zone = { 108 }, "Area 108", "Area 108"
    fish_cast(nil)
    eq(shared.mine[KEY].a[108], nil, "the ninth is not added")
    explored_areas, sub_zone = { 10, 20 }, "Crystal Lake"
    fish_cast(nil)
    eq(shared.mine[KEY].a[20], 3, "a known one still counts")
end)

test("cell x never gets areas", function()
    player_map_position = nil
    fish_cast({ { FISH, 1 } })
    eq(shared.mine["1415:3:x"].a, nil, "no a")
    player_map_position = { 0.43, 0.78 }
end)

---------------------------------------------------------------------------
-- CheckRecord
---------------------------------------------------------------------------
local function record(a)
    local cell = catch_cell(5, 1, { [FISH] = { 5, 5 } })
    cell.px, cell.py, cell.a = 2000, 3000, a
    return prove({ id = "qqqqqqqq", epoch = 0, seq = 1, builds = { ["1.60.1"] = { [KEY] = cell } } })
end

local function rejects(a, what)
    local ok = CatchDB.CheckRecord(record(a))
    eq(ok, false, what)
end

test("CheckRecord refuses bad areas and accepts a cell without them", function()
    eq(CatchDB.CheckRecord(record(nil)), true, "no a")
    eq(CatchDB.CheckRecord(record({ [20] = 4, [10] = 2 })), true, "a sum of c + m")
    rejects("20", "not a table")
    local nine = {}
    for i = 1, 9 do
        nine[i] = 0
    end
    rejects(nine, "more than 8 entries")
    rejects({ [0] = 1 }, "key 0")
    rejects({ [1.5] = 1 }, "a fraction as key")
    rejects({ [2147483648] = 1 }, "above 32 bits")
    rejects({ x = 1 }, "a text key")
    rejects({ [20] = -1 }, "a negative count")
    rejects({ [20] = 0.5 }, "a fraction as count")
    rejects({ [20] = 5, [10] = 2 }, "above c + m")
end)

---------------------------------------------------------------------------
-- The spot's area
---------------------------------------------------------------------------
test("a spot is named after the area with most casts, ties to the lower ID, other players scaled", function()
    local view = CatchDB.QueryCells(1415, { range = "all", source = "all" })[1]
    eq(view.cell, "47", "the spot")
    eq(view.area, 20, "Crystal Lake has the most casts")
    -- Five other players in another cell: from five contributions on, the largest is weighted down.
    for i = 1, 5 do
        local cell = catch_cell(i == 1 and 200 or 10, 0, { [FISH] = { 10, 10 } })
        cell.px, cell.py, cell.t = 100, 100, cell.c -- a second a cast: within the casting a seq step allows
        cell.a = i == 1 and { [30] = 200 } or { [40] = 10 }
        local id = "rrrrrrr" .. ("abcde"):sub(i, i)
        eq(ns.Share.Store.Accept(shared, prove({ id = id, epoch = 0, seq = 2,
            builds = { ["1.60.1"] = { ["1415:3:11"] = cell } } })), "new", id)
    end
    local spot
    for _, v in ipairs(CatchDB.QueryCells(1415, { range = "all", source = "all" })) do
        if v.cell == "11" then
            spot = v
        end
    end
    -- Unscaled, area 30 has 200 casts against 40; scaled like the casts, the big part weighs 10 (part 3, R7).
    eq(spot.area, 40, "the other players' parts scaled by their cast factors")
    local cell = catch_cell(20, 0, {})
    cell.px, cell.py, cell.a = 100, 100, { [50] = 10, [45] = 10 }
    shared.mine["1415:3:12"], shared.records[shared.myID].builds["1.60.1"]["1415:3:12"] = cell, cell
    ns.Fire("SHARED_DATA_CHANGED")
    for _, v in ipairs(CatchDB.QueryCells(1415, { range = "all", source = "mine" })) do
        if v.cell == "12" then
            spot = v
        end
    end
    eq(spot.area, 45, "a tie goes to the lower ID")
end)
