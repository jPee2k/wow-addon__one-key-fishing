-- Catch.lua: the items of FISH_CAUGHT carry their item ID, and Stats and CatchDB count by it.

local KNOWN, UNKNOWN = 6303, 88888
unknown_items[UNKNOWN] = true
player_map_id = 1415
fishing_rank = 100

load_addon()
ns.Mode.IsActive = function() return true end

test("a caught item has its item ID; one the client does not know has none", function()
    local caught
    ns.On("FISH_CAUGHT", function(items) caught = items end)
    fish_cast({ { KNOWN, 2 }, { UNKNOWN, 1 } })
    eq(#caught, 2, "both items")
    eq(caught[1].itemID, KNOWN, "the known item's ID")
    eq(caught[1].quantity, 2, "its quantity")
    eq(caught[2].itemID, nil, "no ID for the unknown item")
end)

test("Stats counts the known item by its ID and leaves the unknown one out", function()
    local items = ns.Stats.GetTotal().items
    eq(items[KNOWN], 2, "the known item")
    eq(items[UNKNOWN], nil, "the unknown item")
end)

test("CatchDB records the known item in the own cell and leaves the unknown one out", function()
    local seen, unknown
    for _, cell in pairs(ns.db.shared.mine) do
        seen = seen or cell.i[KNOWN]
        unknown = unknown or cell.i[UNKNOWN]
    end
    eq(seen and seen[2], 2, "pieces of the known item")
    eq(unknown, nil, "the unknown item")
end)
