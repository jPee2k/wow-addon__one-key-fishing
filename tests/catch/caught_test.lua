-- Catch.lua: the items of FISH_CAUGHT carry their item ID, read from the loot link, and Stats and CatchDB count by
-- it, also for an item the client does not know yet (spec 004 FR-017a).

local KNOWN, UNKNOWN = 6303, 88888
unknown_items[UNKNOWN] = true
player_map_id = 1415
fishing_rank = 100

load_addon()
ns.Mode.IsActive = function() return true end

test("a caught item has its item ID, also one the client does not know", function()
    local caught
    ns.On("FISH_CAUGHT", function(items) caught = items end)
    fish_cast({ { KNOWN, 2 }, { UNKNOWN, 1 } })
    eq(#caught, 2, "both items")
    eq(caught[1].itemID, KNOWN, "the known item's ID")
    eq(caught[1].quantity, 2, "its quantity")
    eq(caught[2].itemID, UNKNOWN, "the unknown item's ID, from its link")
end)

test("Stats counts both items by their IDs", function()
    local items = ns.Stats.GetTotal().items
    eq(items[KNOWN], 2, "the known item")
    eq(items[UNKNOWN], 1, "the unknown item")
end)

test("CatchDB records both items in the own cell", function()
    local seen, unknown
    for _, cell in pairs(ns.db.shared.mine) do
        seen = seen or cell.i[KNOWN]
        unknown = unknown or cell.i[UNKNOWN]
    end
    eq(seen and seen[2], 2, "pieces of the known item")
    eq(unknown and unknown[1], 1, "one catch of the unknown item")
    eq(unknown and unknown[2], 1, "one piece of it")
end)
