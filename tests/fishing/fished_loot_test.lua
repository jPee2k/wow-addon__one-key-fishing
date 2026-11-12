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

-- A loot source the game gives as a secret value (an instance, spec 012 US1): it is neither the opened container nor
-- another known source, so the timing fallback takes the loot as the container's. Here the container stays in the
-- bags after the window closes, which the addon reads as full bags (the looted path), not as a failed open.
test("a secret loot source falls back to the timing of the open attempt", function()
    local SECRET = "Item-0-1-SECRET"
    secret_values[SECRET] = true
    C_Container.GetContainerItemInfo = function(bag, slot)
        if bag == 0 and slot == 1 then
            return { itemID = CLAM, stackCount = 1, hasLoot = true, hyperlink = "[Clam]" }
        end
    end
    C_Item.GetItemGUID = function() return "Item-0-1-CLAM" end
    ItemLocation = { CreateFromBagAndSlot = function() return {} end }
    chat = {}
    ns.Bags.NoteOpenAttempt(0, 1)
    loot = { fishing = false, items = { { HERB, 1 } } }
    loot_sources = { SECRET }
    fire("LOOT_READY")
    fire("LOOT_CLOSED")
    loot, loot_sources = nil, {}
    advance(5)
    ns.Bags.FindContainer()
    local text = table.concat(chat, "\n")
    assert(text:find("Not enough bag space", 1, true), "taken as the container's loot: " .. text)
    assert(not text:find("Cannot open", 1, true), "not a failed open")
end)
