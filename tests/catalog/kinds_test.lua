-- Catalog.lua: the item kinds of spec 014 (specs/014-catch-filters): the kind of an item by its ID, then by the
-- client's class numbers; the grouping of a list; the remembered choice of hidden kinds.

load_addon()

local Catalog = ns.Catalog

-- The byItem list of data-model.md, by kind.
local LISTED = {
    fish = { 4603, 6289, 6291, 6292, 6303, 6308, 6309, 6358, 6359, 6361, 6362, 6458, 6522, 8365, 21071, 13422 },
    containers = { 5523, 5524, 6353, 6355, 6357, 7973, 15874, 20708, 21113, 21150,
        6351, 6352, 6354, 6356, 13874, 13875, 13918 },
    potions = { 858, 2455, 20709, 21114 },
    reagents = { 3820, 6470 },
}

test("every listed item gets the kind of the list", function()
    local count = 0
    for kind, ids in pairs(LISTED) do
        for _, itemID in ipairs(ids) do
            eq(Catalog.ItemKind(itemID), kind, "item " .. itemID)
            count = count + 1
        end
    end
    eq(count, 39, "the 31 items of FR-003 and 8 known catches of higher waters")
end)

test("an unlisted item gets its kind from the client's class numbers", function()
    item_classes[90001] = { 7, 8 }
    item_classes[90002] = { 7, 11 }
    item_classes[90003] = { 7, 6 }
    item_classes[90004] = { 0, 5 }
    item_classes[90005] = { 0, 1 }
    item_classes[90006] = { 15, 0 }
    item_classes[90007] = { 4, 0 }
    eq(Catalog.ItemKind(90001), "fish", "Trade Goods / Cooking")
    eq(Catalog.ItemKind(90002), "reagents", "Trade Goods / Other")
    eq(Catalog.ItemKind(90003), "reagents", "Trade Goods / Leather")
    eq(Catalog.ItemKind(90004), "potions", "Consumable / Food & Drink")
    eq(Catalog.ItemKind(90005), "potions", "Consumable / Potion")
    eq(Catalog.ItemKind(90006), "other", "Miscellaneous / Junk")
    eq(Catalog.ItemKind(90007), "other", "Armor")
    eq(Catalog.ItemKind(90008), "other", "no class numbers")
end)

test("an item the client does not know is Other, and takes its class kind once known (no cache)", function()
    unknown_items[90010] = true
    item_classes[90010] = { 7, 8 }
    eq(Catalog.ItemKind(90010), "other", "unknown")
    unknown_items[90010] = nil
    eq(Catalog.ItemKind(90010), "fish", "known now")
end)

test("the list wins over the class, and quality is never read", function()
    item_classes[5523] = { 7, 11 } -- the clam's class in game: Trade Goods / Other
    eq(Catalog.ItemKind(5523), "containers", "the clam stays a container")
    item_classes[6292] = { 15, 0 } -- the junk fish's class in game
    eq(Catalog.ItemKind(6292), "fish", "the junk fish stays a fish")
    local quality = C_Item.GetItemQualityByID
    C_Item.GetItemQualityByID = function() error("quality must not be read") end
    item_classes[90020] = { 7, 8 }
    eq(Catalog.ItemKind(90020), "fish", "no quality read")
    eq(Catalog.ItemKind(6291), "fish", "no quality read for a listed item")
    C_Item.GetItemQualityByID = quality
end)

test("every item of the bundled seed and every fished container is listed (SC-001)", function()
    local byItem = ns.GameData.ItemKinds.byItem
    local missing = {}
    local function check(itemID)
        if not byItem[tonumber(itemID)] then
            table.insert(missing, tostring(itemID))
        end
    end
    local seen = 0
    for _, cell in pairs(bundled_seed.cells or {}) do
        for itemID in pairs(cell.i or {}) do
            check(itemID)
            seen = seen + 1
        end
        if type(cell.p) == "table" then
            for itemID in pairs(cell.p.i or {}) do
                check(itemID)
            end
        end
    end
    for itemID in pairs(ns.GameData.FishedContainers) do
        check(itemID)
    end
    assert(seen > 0, "the bundled seed has items")
    eq(#missing, 0, "missing from GameData/ItemKinds.lua: " .. table.concat(missing, ", "))
end)

test("KINDS is the fixed order of FR-001", function()
    eq(table.concat(Catalog.KINDS, ","), "fish,containers,potions,reagents,other", "order")
end)

test("KindText gives each kind's text", function()
    eq(Catalog.KindText("fish"), ns.L["Fish"], "fish")
    eq(Catalog.KindText("containers"), ns.L["Containers"], "containers")
    eq(Catalog.KindText("potions"), ns.L["Potions & drinks"], "potions")
    eq(Catalog.KindText("reagents"), ns.L["Reagents & herbs"], "reagents")
    eq(Catalog.KindText("other"), ns.L["Other"], "other")
end)

-- Group's list as "H:<kind>" for a header and the item ID for a row.
local function drawn(list)
    local out = {}
    for _, element in ipairs(list) do
        table.insert(out, element.header and ("H:" .. element.header) or tostring(element.itemID))
    end
    return table.concat(out, ",")
end

test("Group: a header before each kind's rows, kinds in order, rows in input order, the same row tables", function()
    local rows = { { itemID = 858 }, { itemID = 6355 }, { itemID = 6291 }, { itemID = 21113 }, { itemID = 6289 } }
    local list, hidden = Catalog.Group(rows)
    eq(drawn(list), "H:fish,6291,6289,H:containers,6355,21113,H:potions,858", "list")
    eq(list[2], rows[3], "the same table")
    eq(hidden, 0, "nothing hidden")
    local none, noneHidden = Catalog.Group({})
    eq(#none, 0, "nothing for no rows")
    eq(noneHidden, 0, "nothing hidden")
end)

test("Group leaves out hidden kinds and counts their rows", function()
    ns.db.settings.hiddenKinds = { containers = true }
    local list, hidden = Catalog.Group({ { itemID = 6355 }, { itemID = 6291 }, { itemID = 21113 } })
    eq(drawn(list), "H:fish,6291", "containers left out")
    eq(hidden, 2, "two rows hidden")
    ns.db.settings.hiddenKinds = {}
end)

test("the saved choice: defaults, SetKindShown, the message, ShownKinds", function()
    eq(type(ns.db.settings.hiddenKinds), "table", "a table by default")
    eq(next(ns.db.settings.hiddenKinds), nil, "empty by default")
    for _, kind in ipairs(Catalog.KINDS) do
        eq(Catalog.IsKindShown(kind), true, kind .. " shown")
    end
    local fired = {}
    ns.On("SETTINGS_CHANGED", function(key) table.insert(fired, key) end)
    Catalog.SetKindShown("other", false)
    eq(ns.db.settings.hiddenKinds.other, true, "other hidden")
    eq(Catalog.IsKindShown("other"), false, "not shown")
    eq(table.concat(fired, ","), "hiddenKinds", "SETTINGS_CHANGED with the key")
    local shown, total = Catalog.ShownKinds()
    eq(shown, 4, "four shown")
    eq(total, 5, "of five")
    Catalog.SetKindShown("other", false)
    eq(#fired, 1, "no message when nothing changed")
    Catalog.SetKindShown("other", true)
    eq(ns.db.settings.hiddenKinds.other, nil, "removed, not false")
    eq(#fired, 2, "a message for the change")
    Catalog.SetKindShown("nope", false)
    eq(ns.db.settings.hiddenKinds.nope, nil, "an unknown kind is not written")
    eq(#fired, 2, "nor announced")
end)

test("a remembered choice with an unknown name: the name is ignored, the rest applies", function()
    ns.db.settings.hiddenKinds = { nope = true, fish = true }
    local shown, total = Catalog.ShownKinds()
    eq(shown, 4, "only fish counts as hidden")
    eq(total, 5, "of five")
    eq(Catalog.IsKindShown("fish"), false, "fish hidden")
    eq(Catalog.IsKindShown("containers"), true, "a kind the set does not name is shown")
    ns.db.settings.hiddenKinds = {}
end)
