-- Views.lua: CatchDB.ScanItems, the items the auction scan takes beyond the own catches (specs/018-auction-scan,
-- User Story 2): the bundled database's items, and the items of other players' records while sharing is on.

local SEEDED, BOTH, OTHER, FROZEN = 6303, 6291, 99001, 99002
OneKeyFishingDB = { shareNotice = true, shared = { mine = {}, records = {} } }
load_addon(function()
    ns.SeedData = { epoch = 1, absorbed = {}, resets = { [3300] = "1.60.0" },
        cells = { ["9999:0:x"] = { c = 2, m = 0, t = 20, k = 1, i = { [SEEDED] = { 1, 1 }, [BOTH] = { 1, 1 } } } } }
end)

local CatchDB = ns.CatchDB
local shared = ns.db.shared

-- A record under `key` with 100 catches at `place` (3200:0:11) of game version `build` (1.60.1), `catches` (five)
-- of each item.
local function record(key, id, items, place, build, catches)
    local cellItems = {}
    for _, itemID in ipairs(items) do
        cellItems[itemID] = { catches or 5, catches or 5 }
    end
    shared.records[key] = { id = id, epoch = 0, seq = 1, seen = 1, proof = ("a"):rep(16),
        builds = { [build or "1.60.1"] = { [place or "3200:0:11"] = catch_cell(100, 0, cellItems) } } }
    ns.Fire("SHARED_DATA_CHANGED")
end

local function keys(set)
    local list = {}
    for itemID in pairs(set or {}) do
        table.insert(list, itemID)
    end
    table.sort(list)
    return table.concat(list, ",")
end

test("the first set is the bundled database's items", function()
    local bundled = CatchDB.ScanItems()
    eq(keys(bundled), BOTH .. "," .. SEEDED, "the seed's items")
end)

test("the second set is what the catalog shows of other players' records while sharing is on", function()
    ns.Share.SetEnabled(true)
    record("aaaaaaa2@0", "aaaaaaa2", { OTHER })
    local _, others = CatchDB.ScanItems()
    eq(others[OTHER], nil, "one record does not add an item")
    record("baaaaaa2@0", "baaaaaa2", { OTHER })
    record("caaaaaa2@0", "caaaaaa2", { OTHER, BOTH })
    _, others = CatchDB.ScanItems()
    eq(others[OTHER], true, "three records on one map")
    eq(others[BOTH], nil, "one record: not added, though the seed has it (it is in the first set)")
    ns.Share.SetEnabled(false)
    _, others = CatchDB.ScanItems()
    eq(keys(others), "", "nothing with sharing off")
    ns.Share.SetEnabled(true)
end)

test("an own record frozen by a roll is not another player's", function()
    record(shared.myID .. "@0", shared.myID, { FROZEN })
    local _, others = CatchDB.ScanItems()
    eq(others[FROZEN], nil, "the own frozen record's item")
end)

test("a report counts as in the catalog: a catch, of a game version not older than the map's reset", function()
    local ZERO, OLD = 99003, 99004
    for _, prefix in ipairs({ "d", "e", "f" }) do
        local id = prefix .. "aaaaaa3"
        record(id .. "@0", id, { ZERO }, nil, nil, 0)
    end
    local _, others = CatchDB.ScanItems()
    eq(others[ZERO], nil, "three records without a catch of the item")
    for _, prefix in ipairs({ "g", "h", "i" }) do
        local id = prefix .. "aaaaaa3"
        record(id .. "@0", id, { OLD }, "3300:0:11", "1.59.0")
    end
    _, others = CatchDB.ScanItems()
    eq(others[OLD], nil, "three records of a game version before the map's reset")
end)
