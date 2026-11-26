-- CatchDB/Index.lua CountedOthers (specs/027-import-export, research R5): with sharing off, the imported records
-- count in the views and the others do not; with sharing on, both count. The tests run in order and share one login.

local FISH, OTHER_FISH = 6291, 6303
local A, B = "aaaaaaaa", "baaaaaab"

OneKeyFishingDB = { shareNotice = true, settings = { shareDB = true } }
load_addon()

local Store = ns.Share.Store
local shared = ns.db.shared
local ALL = { range = 3, source = "all" }

local function rec(id, epoch, seq, itemID)
    local cells = { ["1415:3:47"] = catch_cell(math.max(2, seq), 1, { [itemID] = { 2, 2 } }) }
    seq = math.max(seq, math.ceil(cells["1415:3:47"].t / ns.CatchDB.private.STEP_SECONDS))
    return prove({ id = id, epoch = epoch, seq = seq, builds = { ["1.60.1"] = cells } }, nil, 4096)
end

local function players()
    local view = ns.CatchDB.Query(1415, "47", ALL)
    return view and view.players or 0
end

eq(Store.Accept(shared, rec(A, 1, 3, FISH), 100), "new", "A from the exchange")
eq(Store.Accept(shared, rec(B, 1, 3, OTHER_FISH), 100), "new", "B from the exchange")

test("with sharing on, every other record counts", function()
    eq(players(), 2, "both")
end)

test("with sharing off, only the imported ones count", function()
    ns.Share.SetEnabled(false)
    eq(players(), 0, "none imported yet")
    shared.imported[A .. "@1"] = true
    ns.Fire("SHARED_DATA_CHANGED", { A .. "@1" }, shared)
    eq(players(), 1, "the imported one")
    local maps = ns.CatchDB.Maps(ALL)
    eq(maps[1], 1415, "its map is listed")
end)

test("a newer version of an imported unit counts too", function()
    local newer = rec(A, 1, 30, FISH)
    eq(Store.Accept(shared, newer, 200), "newer", "from the exchange")
    eq(players(), 1, "still counted")
    eq(ns.CatchDB.Query(1415, "47", ALL).catches, newer.builds["1.60.1"]["1415:3:47"].c, "its new counts")
end)

test("sharing on again counts both", function()
    ns.Share.SetEnabled(true)
    eq(players(), 2, "both")
end)

test("CleanUp drops the marks of units no longer stored", function()
    shared.imported["zzzzzzzz@1"] = true
    Store.CleanUp(shared)
    eq(shared.imported["zzzzzzzz@1"], nil, "gone")
    eq(shared.imported[A .. "@1"], true, "a stored one kept")
end)

test("with sharing off, an own record a roll kept still shows its camp bonus parts", function()
    ns.Share.SetEnabled(false)
    eq(ns.CatchDB.HasBonusData(), false, "no part yet")
    local cell = catch_cell(4, 1, { [FISH] = { 2, 2 } })
    cell.q = { ["1"] = { c = 2, m = 0, i = { [FISH] = { 2, 2 } } } }
    local frozen = prove({ id = shared.myID, epoch = 3, seq = math.max(1, math.ceil(cell.t /
        ns.CatchDB.private.STEP_SECONDS)), builds = { ["1.60.1"] = { ["1415:3:48"] = cell } } }, nil, 4096)
    shared.records[shared.myID .. "@3"] = frozen
    ns.Fire("SHARED_DATA_CHANGED", { shared.myID .. "@3" }, shared)
    eq(ns.CatchDB.HasBonusData(), true, "the kept own record's part counts")
    ns.Share.SetEnabled(true)
end)

