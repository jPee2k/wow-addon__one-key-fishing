-- Bags.lua: everything looted from fishing is remembered as a possible fished container, by the ID of its loot link,
-- also an item the client does not know yet.

local CLAM, HIDDEN, HERB = 5523, 88889, 2447
unknown_items[HIDDEN] = true

load_addon()

test("fishing loot is remembered, also an item the client does not know", function()
    fish_cast({ { CLAM, 1 }, { HIDDEN, 1 } })
    fire("LOOT_CLOSED") -- fish_cast leaves the loot window open for Bags
    eq(ns.db.fishedItems[CLAM], true, "the known container")
    eq(ns.db.fishedItems[HIDDEN], true, "the unknown one")
end)

test("loot that is not from fishing is not remembered", function()
    loot = { fishing = false, items = { { HERB, 1 } } }
    fire("LOOT_READY")
    fire("LOOT_CLOSED")
    loot = nil
    eq(ns.db.fishedItems[HERB], nil, "a herb")
end)
