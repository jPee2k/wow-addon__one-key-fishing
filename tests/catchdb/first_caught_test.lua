-- CatchDB.lua: ITEM_FIRST_CAUGHT (specs/023-item-kinds, research R4): a settled catch that brings an item new to the
-- account's own catch fires the message once per item, after the write; the own items are read before the write, so
-- the first catch is seen even when no view has built them yet. The tests share one login and run in order.

local FISH, OLD, TROPHY, TROPHY2 = 6291, 6303, 6292, 13917
OneKeyFishingDB = { shareNotice = true, shared = { mine = {}, records = {
    -- an own record of an older game version that already holds OLD (myID is set below)
    ["aaaaaaa2@0"] = { id = "aaaaaaa2", epoch = 0, seq = 1, seen = 1, proof = ("a"):rep(16),
        builds = { ["1.13.0"] = { ["1415:3:47"] = { c = 1, m = 0, t = 10, i = { [OLD] = { 1, 1 } } } } } },
}, myID = "aaaaaaa2" } }
player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
load_addon()

local CatchDB = ns.CatchDB
local fired = {}
ns.On("ITEM_FIRST_CAUGHT", function(itemID, castID)
    table.insert(fired, { itemID = itemID, castID = castID, own = CatchDB.IsOwnItem(itemID) })
end)

local function ids()
    local out = {}
    for _, entry in ipairs(fired) do
        table.insert(out, entry.itemID)
    end
    return table.concat(out, ",")
end

test("the first catch of an item fires once, after the write, with its cast, before any view was built", function()
    fish_cast({ { FISH, 1 } })
    eq(ids(), tostring(FISH), "fired for the new item")
    eq(fired[1].own, true, "the own catch holds it when the message comes")
    eq(fired[1].castID, ns.GetFishingCastID(), "the cast that brought it")
end)

test("a repeated item, a miss and an item of an older own record fire nothing", function()
    fired = {}
    fish_cast({ { FISH, 1 } })
    fish_cast(nil)
    fish_cast({ { OLD, 1 } })
    eq(ids(), "", "nothing new")
end)

test("two new items in one loot fire twice; a cast without a place fires nothing", function()
    fired = {}
    fish_cast({ { TROPHY2, 1 }, { TROPHY, 1 } })
    eq(ids(), TROPHY .. "," .. TROPHY2, "both, in item ID order")
    fired = {}
    player_map_id = nil
    fish_cast({ { 13916, 1 } })
    player_map_id = 1415
    eq(ids(), "", "not recorded, so not new to the own catch")
    eq(CatchDB.IsOwnItem(13916), false, "and not caught for the collection")
end)
