-- CatchDB.lua: which items a view lists (specs/004-public-channel-sync, FR-014, FR-017a, research R8). An item
-- neither the seed nor the own catch has is listed from three other contributions on the map on; an item the client
-- does not know yet is listed too, with its reporters (the tab draws it as "Unknown item").

local FISH, SEEDED, OWN, NEW = 6291, 6303, 6358, 99999
OneKeyFishingDB = { shareNotice = true, shared = { mine = { ["3999:0:x"] = { c = 1, m = 0, t = 10, i = {
    [OWN] = { 1, 1 } } } }, records = {} } }
load_addon(function()
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {},
        cells = { ["9999:0:x"] = { c = 2, m = 0, t = 20, k = 1, i = { [SEEDED] = { 1, 1 }, [FISH] = { 1, 1 } } } } }
end)

local CatchDB = ns.CatchDB
local shared = ns.db.shared
local ALL = { range = "all", source = "all" }

-- Another player's contribution at <map>:<range>:11: 100 catches of FISH, `extra` of them also with `itemID`.
local function contribution(id, map, range, itemID, extra)
    shared.records[id .. "@0"] = { id = id, epoch = 0, seq = 1, seen = 1, proof = ("a"):rep(16),
        builds = { ["1.60.1"] = { [map .. ":" .. range .. ":11"] = catch_cell(100, 0,
            { [FISH] = { 100, 100 }, [itemID] = extra and { extra, extra } or nil }) } } }
    ns.Fire("SHARED_DATA_CHANGED")
end

local function item(view, itemID)
    for _, entry in ipairs(view.items) do
        if entry.itemID == itemID then
            return entry
        end
    end
end

test("an item neither the seed nor the own catch has is listed from three contributions on the map", function()
    contribution("aaaaaaa2", 3200, 0, NEW, 5)
    eq(item(CatchDB.Query(3200, "11", ALL), NEW), nil, "one report: not listed")
    contribution("baaaaaa2", 3200, 1, NEW, 5)
    local view = CatchDB.Query(3200, "11", ALL)
    eq(item(view, NEW), nil, "two reports: not listed")
    eq(view.catches, 200, "its catches still count")
    contribution("caaaaaa2", 3200, 4, NEW, 5) -- another skill range of the same map
    local listed = item(CatchDB.Query(3200, "11", ALL), NEW)
    assert(listed, "three reports, in any range: listed")
    eq(listed.reporters, 3, "reporters")
    eq(listed.inSeed, false, "not from the seed")
end)

test("an item of the seed or of the own catch is listed from one report on", function()
    contribution("daaaaaa2", 3210, 3, SEEDED, 5)
    contribution("eaaaaaa2", 3220, 3, OWN, 5)
    local seeded = item(CatchDB.Query(3210, "11", ALL), SEEDED)
    assert(seeded, "a seed item")
    eq(seeded.inSeed, true, "inSeed")
    assert(item(CatchDB.Query(3220, "11", ALL), OWN), "an item of the own catch")
end)

test("an item the client does not know is listed with its reporters", function()
    unknown_items[NEW] = true
    ns.Fire("SHARED_DATA_CHANGED")
    local listed = item(CatchDB.Query(3200, "11", ALL), NEW)
    assert(listed, "listed")
    eq(listed.reporters, 3, "three reports")
    unknown_items[NEW] = nil
end)

test("Only mine lists every item of the own catch", function()
    local view = CatchDB.Query(3999, "x", { range = 0, source = "mine" })
    assert(item(view, OWN), "the own item")
end)
