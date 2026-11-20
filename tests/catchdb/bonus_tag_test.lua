-- The camp bonus tag of a view's items (specs/020-camp-buffs FR-016 to FR-022, SC-003, SC-008, research R7): a known
-- item is tagged in every view; an item whose every catch of the scope lies under one bonus is tagged from the data
-- when the seed or three players hold it so; the tag's numbers are those of the same scope under that bonus, never of
-- another scope, and no view fetches another. The tests run in order and share one login.

local FISH, BLOATED, OIL, FIREFIN = 6291, 6643, 6358, 6359
local RACK = 1280341

player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
OneKeyFishingDB = { shareNotice = true }

local function seedCell(c, items, k, q)
    local cell = catch_cell(c, 0, items)
    cell.k, cell.q = k, q
    return cell
end

local function part(c, items, k)
    return { c = c, m = 0, k = k, i = items }
end

local SEED = { epoch = 1, absorbed = {}, resets = {}, cells = {
    ["2001:3:x"] = seedCell(100, { [FISH] = { 90, 90 }, [BLOATED] = { 10, 10 } }, 3,
        { ["1"] = part(50, { [FISH] = { 40, 40 }, [BLOATED] = { 10, 10 } }, 3) }),
    ["2002:3:x"] = seedCell(100, { [FISH] = { 90, 90 }, [BLOATED] = { 10, 10 } }, 3,
        { ["1"] = part(49, { [FISH] = { 39, 39 }, [BLOATED] = { 10, 10 } }, 3) }),
    ["2003:3:x"] = seedCell(20, { [FISH] = { 18, 18 }, [BLOATED] = { 2, 2 } }, 2),
    ["2004:3:47"] = seedCell(60, { [FISH] = { 55, 55 }, [BLOATED] = { 5, 5 } }, 2,
        { ["1"] = part(10, { [FISH] = { 5, 5 }, [BLOATED] = { 5, 5 } }, 2) }),
    ["2004:3:11"] = seedCell(200, { [FISH] = { 200, 200 } }, 2, { ["1"] = part(200, { [FISH] = { 200, 200 } }, 2) }),
    ["2005:3:x"] = seedCell(30, { [FISH] = { 25, 25 }, [OIL] = { 5, 5 } }, 2,
        { ["2"] = part(5, { [OIL] = { 5, 5 } }, 1) }),
    ["2006:3:x"] = seedCell(30, { [FISH] = { 27, 27 }, [OIL] = { 3, 3 } }, 2,
        { ["3"] = part(3, { [OIL] = { 3, 3 } }, 1) }),
    ["2008:3:x"] = seedCell(20, { [FISH] = { 17, 17 }, [OIL] = { 3, 3 } }, 2,
        { ["1"] = part(5, { [FISH] = { 3, 3 }, [OIL] = { 2, 2 } }, 1) }),
    ["2009:3:x"] = seedCell(10, { [FISH] = { 6, 6 }, [OIL] = { 4, 4 } }, 2,
        { ["1"] = part(2, { [OIL] = { 2, 2 } }, 1), ["2"] = part(2, { [OIL] = { 2, 2 } }, 1) }),
    -- 2001's data without the parts (SC-008)
    ["2010:3:x"] = seedCell(100, { [FISH] = { 90, 90 }, [BLOATED] = { 10, 10 } }, 3),
    ["2011:3:x"] = seedCell(30, { [FISH] = { 28, 28 }, [BLOATED] = { 2, 2 } }, 2,
        { ["3"] = part(4, { [FISH] = { 2, 2 }, [BLOATED] = { 2, 2 } }, 1) }),
    -- a Bloated fish under both bonuses, more often under the Hut (decision 32)
    ["2012:3:x"] = seedCell(60, { [FISH] = { 52, 52 }, [BLOATED] = { 8, 8 } }, 3, {
        ["1"] = part(10, { [FISH] = { 8, 8 }, [BLOATED] = { 2, 2 } }, 2),
        ["2"] = part(50, { [FISH] = { 44, 44 }, [BLOATED] = { 6, 6 } }, 3),
    }),
} }

load_addon(function()
    ns.SeedData = SEED
end)

local CatchDB = ns.CatchDB

local function filter(bonus, source)
    return { range = "all", source = source or "all", water = "all", bonus = bonus or "all" }
end

local function item(view, itemID)
    for _, entry in ipairs(view.items) do
        if entry.itemID == itemID then
            return entry
        end
    end
end

local function other(id, key, cell)
    eq(ns.Share.Store.Accept(ns.db.shared, prove({ id = id, epoch = 0, seq = 1,
        builds = { ["1.60.1"] = { [key] = cell } } })), "new", "record " .. id)
end

test("a known item with 50 catches under the Rack: its chance there, enough data", function()
    local bonus = item(CatchDB.QueryMap(2001, filter()), BLOATED).bonus
    eq(bonus.key, "rack", "key")
    near(bonus.chance, 10 / 50, "chance among the Rack's catches")
    eq(bonus.littleData, false, "50 catches")
    eq(bonus.catches, 50, "the Rack's catches")
    eq(bonus.players, 3, "the Rack's players")
end)

test("49 catches under the Rack: little data", function()
    eq(item(CatchDB.QueryMap(2002, filter()), BLOATED).bonus.littleData, true, "49")
end)

test("a known item caught only outside every part: tagged, little data, nothing counted", function()
    local bonus = item(CatchDB.QueryMap(2003, filter()), BLOATED).bonus
    eq(bonus.key, "rack", "key")
    eq(bonus.littleData, true, "little data")
    eq(bonus.catches, 0, "no catches")
    eq(bonus.players, 0, "no players")
    eq(bonus.chance, nil, "no chance")
end)

test("the tag's numbers come from the view's own scope: the spot, not the map", function()
    local view = CatchDB.Query(2004, "47", filter())
    eq(view.scope, "spot", "60 catches at the spot")
    local bonus = item(view, BLOATED).bonus
    eq(bonus.catches, 10, "the spot's 10 catches under the Rack")
    eq(bonus.littleData, true, "the spot's, not the map's 210")
end)

test("an item not on the list, all its catches under the Hut in the seed: tagged Hut", function()
    eq(item(CatchDB.QueryMap(2005, filter()), OIL).bonus.key, "hut", "Hut")
    eq(item(CatchDB.QueryMap(2005, filter()), FISH).bonus, nil, "the ordinary fish")
end)

test("an item caught only under both: the Hut in \"all\", each key in its own view", function()
    eq(item(CatchDB.QueryMap(2006, filter()), OIL).bonus.key, "hut", "all: the higher rank")
    local rack = CatchDB.QueryMap(2006, filter("rack"))
    local tag = item(rack, OIL).bonus
    eq(tag.key, "rack", "rack view")
    near(tag.chance, item(rack, OIL).chance, "the view's own chance")
    eq(tag.catches, rack.catches, "the view's own catches")
    eq(tag.players, rack.players, "the view's own players")
    eq(tag.littleData, rack.littleData, "the view's own little data")
    eq(item(CatchDB.QueryMap(2006, filter("hut")), OIL).bonus.key, "hut", "hut view")
end)

test("data tags need three players or the seed; \"mine\" has known tags only", function()
    auras[RACK] = { expirationTime = GetTime() + 3000, duration = 3600 }
    fire("UNIT_AURA", "player")
    fish_cast({ { FIREFIN, 1 } })
    fish_cast({ { BLOATED, 1 }, { FISH, 1 } })
    eq(item(CatchDB.QueryMap(1415, filter()), FIREFIN).bonus, nil, "the own catch alone")
    for _, id in ipairs({ "rrrrrrrr", "ssssssss" }) do
        local cell = catch_cell(2, 0, { [FIREFIN] = { 2, 2 } })
        cell.q = { ["1"] = { c = 2, m = 0, i = { [FIREFIN] = { 2, 2 } } } }
        other(id, "1415:3:47", cell)
    end
    eq(item(CatchDB.QueryMap(1415, filter()), FIREFIN).bonus.key, "rack", "own and two others")
    for _, id in ipairs({ "tttttttt", "uuuuuuuu" }) do
        local cell = catch_cell(2, 0, { [FIREFIN] = { 2, 2 } })
        cell.q = { ["1"] = { c = 2, m = 0, i = { [FIREFIN] = { 2, 2 } } } }
        other(id, "2007:3:x", cell)
    end
    eq(item(CatchDB.QueryMap(2007, filter()), FIREFIN).bonus, nil, "two other records only")
    local mine = CatchDB.QueryMap(1415, filter("all", "mine"))
    eq(item(mine, FIREFIN).bonus, nil, "no data tag under \"mine\"")
    eq(item(mine, BLOATED).bonus.key, "rack", "a known item still tagged")
end)

test("one catch outside every part, or catches under two bonuses apart: no tag", function()
    eq(item(CatchDB.QueryMap(2008, filter()), OIL).bonus, nil, "one catch outside")
    eq(item(CatchDB.QueryMap(2009, filter()), OIL).bonus, nil, "under the Rack and the Hut apart")
end)

test("untagged items keep the numbers of the same data without parts (SC-008)", function()
    local with, without = item(CatchDB.QueryMap(2001, filter()), FISH), item(CatchDB.QueryMap(2010, filter()), FISH)
    eq(with.bonus, nil, "untagged")
    eq(with.catches, without.catches, "catches")
    near(with.chance, without.chance, "chance")
    near(with.pieces, without.pieces, "pieces")
end)

test("a view under \"rack\": the known item with the view's own numbers, others untagged", function()
    local view = CatchDB.QueryMap(2001, filter("rack"))
    local bloated = item(view, BLOATED)
    eq(bloated.bonus.key, "rack", "key")
    near(bloated.bonus.chance, bloated.chance, "the view's chance")
    eq(bloated.bonus.catches, view.catches, "the view's catches")
    eq(bloated.bonus.players, view.players, "the view's players")
    eq(item(view, FISH).bonus, nil, "an ordinary fish")
end)

test("a Bloated fish is both bonuses' (decision 32): tagged under \"hut\" with the view's numbers", function()
    local view = CatchDB.QueryMap(2011, filter("hut"))
    local hut = item(view, BLOATED)
    eq(hut.bonus.key, "hut", "the Hut's under the Hut")
    eq(hut.bonus.plain, nil, "not plain")
    near(hut.bonus.chance, hut.chance, "the view's chance")
    eq(hut.bonus.catches, view.catches, "the view's catches")
    eq(hut.bonus.several, true, "known to more than one bonus")
end)

test("under \"none\" a known item is plain (the first bonus's key), and no data tag", function()
    local none = item(CatchDB.QueryMap(2003, filter("none")), BLOATED).bonus
    eq(none.key, "rack", "none: key")
    eq(none.plain, true, "none: plain")
    eq(none.several, true, "none: both bonuses'")
    eq(item(CatchDB.QueryMap(2008, filter("none")), OIL).bonus, nil, "no data tag under \"none\"")
end)

test("\"all\": a known item takes the bonus with its most catches here (decision 32)", function()
    local bonus = item(CatchDB.QueryMap(2012, filter()), BLOATED).bonus
    eq(bonus.key, "hut", "6 under the Hut against 2 under the Rack")
    near(bonus.chance, 6 / 50, "its chance among the Hut's catches")
    eq(bonus.catches, 50, "the Hut's catches")
    eq(bonus.littleData, false, "50 catches")
    eq(bonus.several, true, "both bonuses'")
    eq(item(CatchDB.QueryMap(2001, filter()), BLOATED).bonus.key, "rack", "only under the Rack: the Rack")
    eq(item(CatchDB.QueryMap(2003, filter()), BLOATED).bonus.key, "rack", "under none: the Rack, the cheapest")
end)

test("building a view calls no other query", function()
    local depth, inner = 0, 0
    for _, name in ipairs({ "Query", "QueryMap", "QueryCells" }) do
        local original = CatchDB[name]
        CatchDB[name] = function(...)
            if depth > 0 then
                inner = inner + 1
            end
            depth = depth + 1
            local result = original(...)
            depth = depth - 1
            return result
        end
    end
    ns.Fire("SHARED_DATA_CHANGED")
    for _, bonus in ipairs({ "all", "none", "rack", "hut" }) do
        CatchDB.QueryMap(2006, filter(bonus))
        CatchDB.Query(2004, "47", filter(bonus))
        CatchDB.QueryCells(2004, filter(bonus))
    end
    eq(inner, 0, "no query from inside a build")
end)
