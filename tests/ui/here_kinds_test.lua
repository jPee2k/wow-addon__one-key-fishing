-- UI/CatchHere.lua with the item kinds of spec 014 (specs/014-catch-filters): the rows under kind headers, the
-- kind menu, the numbers unchanged by a hidden kind, the empty-by-filter message.
-- The tests run in order and share one login: each starts where the previous ended.

local FISH, CHEST, POTION, HERB, UNKNOWN = 6291, 6355, 858, 3820, 90100

player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
load_addon()

local L = ns.L

ns.StatsFrame.Toggle()
local window = _G.OneKeyFishingStatsFrame
local here = window.herePage

-- What the shown rows are: "H:<kind text>" for a header, the item ID for an item.
local function Shown()
    local list = {}
    for _, row in ipairs(list_rows(here.list)) do
        if row:IsShown() then
            if row.itemID then
                table.insert(list, tostring(row.itemID))
            else
                table.insert(list, "H:" .. tostring(row.header.text))
            end
        end
    end
    return table.concat(list, ",")
end

local function RowOf(itemID)
    for _, row in ipairs(list_rows(here.list)) do
        if row:IsShown() and row.itemID == itemID then
            return row
        end
    end
end

test("setup: 60 own catches of five kinds at the spot", function()
    unknown_items[UNKNOWN] = true
    for _ = 1, 20 do fish_cast({ { FISH, 1 } }) end
    for _ = 1, 15 do fish_cast({ { CHEST, 1 } }) end
    for _ = 1, 10 do fish_cast({ { POTION, 1 } }) end
    for _ = 1, 10 do fish_cast({ { HERB, 1 } }) end
    for _ = 1, 5 do fish_cast({ { UNKNOWN, 1 } }) end
    click(L["What can be caught here"], window)
    tick(window)
    eq(here.scope.text, "", "the spot's own numbers")
end)

test("the rows are grouped under kind headers in the fixed order (FR-006, SC-002)", function()
    eq(Shown(), table.concat({ "H:" .. L["Fish"], FISH, "H:" .. L["Containers"], CHEST,
        "H:" .. L["Potions & drinks"], POTION, "H:" .. L["Reagents & herbs"], HERB, "H:" .. L["Other"], UNKNOWN }, ","),
        "rows")
end)

test("a header row has no item, no icon, no numbers, and its scripts do nothing", function()
    local header = list_rows(here.list)[1]
    eq(header.itemID, nil, "no item")
    eq(header.icon:IsShown(), false, "no icon")
    eq(header.chance:IsShown() and header.chance.text ~= "" , false, "no chance")
    eq(header.pieces:IsShown() and header.pieces.text ~= "", false, "no per catch")
    eq(header.price:IsShown() and header.price.text ~= "", false, "no price")
    tooltip_shown = false
    header.scripts.OnEnter(header)
    eq(tooltip_shown, false, "no tooltip")
    local catalog = window.catalogPage
    header.scripts.OnMouseUp(header, "LeftButton")
    assert(not (catalog and catalog:IsShown()), "no catalog opened")
end)

test("an item row keeps its numbers: the chance is the view's", function()
    local view = ns.CatchDB.Query(1415, ns.CatchDB.GetCell(1415), { range = 3, source = "all", water = "all" })
    local chance
    for _, item in ipairs(view.items) do
        if item.itemID == FISH then
            chance = item.chance
        end
    end
    local row = RowOf(FISH)
    eq(row.icon:IsShown(), true, "icon shown")
    eq(row.chance.text, ns.Catalog.ChanceText(chance, view.littleData), "chance")
    eq(row.pieces.text, "1", "per catch: a whole number (spec 020)")
end)

-- US2: the kind menu (FR-007 to FR-011).

-- The row texts of every shown item: "<id>=<chance>|<per catch>|<price>".
local function Numbers()
    local list = {}
    for _, row in ipairs(list_rows(here.list)) do
        if row:IsShown() and row.itemID then
            table.insert(list, ("%d=%s|%s|%s"):format(row.itemID, tostring(row.chance.text), tostring(row.pieces.text),
                tostring(row.price.text)))
        end
    end
    table.sort(list)
    return list
end


test("the kind button reads 'Kinds: all' and opens five checkboxes, all checked", function()
    eq(here.kindButton.text, L["Kinds: All"], "button")
    assert(anchor(here.kindButton, "TOPLEFT"), "in row B, at the slot's place without pool or bonus data (spec 020)")
    here.kindButton.scripts.OnClick(here.kindButton)
    local texts = {}
    for _, entry in ipairs(menu_entries) do
        eq(entry.kind, "checkbox", "a checkbox: " .. tostring(entry.text))
        eq(entry.isSelected(), true, "checked: " .. tostring(entry.text))
        table.insert(texts, entry.text)
    end
    eq(table.concat(texts, ","), table.concat({ L["Fish"], L["Containers"], L["Potions & drinks"],
        L["Reagents & herbs"], L["Other"] }, ","), "the five kinds in order")
end)

test("unticking Containers hides them at once; the other numbers stay (FR-007, FR-010, SC-004)", function()
    local numbers = Numbers()
    local scope, counts = here.scope.text, here.counts.text
    here.kindButton.scripts.OnClick(here.kindButton)
    menu_entry(L["Containers"]).onClick()
    eq(ns.db.settings.hiddenKinds.containers, true, "saved")
    -- No tick: the page follows the click itself.
    assert(not Shown():find("H:" .. L["Containers"], 1, true), "no Containers header: " .. Shown())
    eq(RowOf(CHEST), nil, "no chest row")
    eq(here.kindButton.text, (L["Kinds: %d of %d"]):format(4, 5), "button")
    local after = {}
    for _, line in ipairs(numbers) do
        if not line:find("^" .. CHEST .. "=") then
            table.insert(after, line)
        end
    end
    eq(table.concat(Numbers(), ";"), table.concat(after, ";"), "chance, per catch and price unchanged")
    eq(here.scope.text, scope, "the scope line unchanged")
    eq(here.counts.text, counts, "the counts line (catches, players, misses) unchanged")
    menu_entry(L["Containers"]).onClick()
    assert(Shown():find("H:" .. L["Containers"], 1, true), "back again")
end)

test("every kind hidden: no rows, and the page says the filter hides them (FR-011)", function()
    for _, kind in ipairs(ns.Catalog.KINDS) do
        ns.Catalog.SetKindShown(kind, false)
    end
    tick(window)
    eq(Shown(), "", "no rows")
    eq(here.message.text, L["The kind filter hides every item."], "the filter's text")
    eq(here.kindButton.text, (L["Kinds: %d of %d"]):format(0, 5), "button")
    assert(not here.hint.text:find(L["Click an item to see where else it is caught."], 1, true),
        "no click hint without an item: " .. here.hint.text)
    for _, kind in ipairs(ns.Catalog.KINDS) do
        ns.Catalog.SetKindShown(kind, true)
    end
    tick(window)
    eq(here.message.text, "", "no message with items shown")
    assert(here.hint.text:find(L["Click an item to see where else it is caught."], 1, true), "the hint is back")
end)

test("the filter row keeps its three buttons of 150; Kinds is a separate button of 120", function()
    for _, name in ipairs({ "skillButton", "sourceButton", "waterButton" }) do
        eq(here[name].minWidth, 150, name .. ": the filter row as before spec 014")
    end
    eq(here.kindButton.minWidth, 120, "the Kinds button, at the top right")
end)

test("an item hidden as Other that the game then loads as a fish shows up without another change", function()
    ns.Catalog.SetKindShown("other", false)
    tick(window)
    eq(RowOf(UNKNOWN), nil, "unknown, so Other, so hidden")
    item_classes[UNKNOWN] = { 7, 8 }
    item_loaded(UNKNOWN, true) -- the catalog's name queue asked for it; the game answers
    tick(window)
    assert(RowOf(UNKNOWN), "now a fish, listed: " .. Shown())
    ns.Catalog.SetKindShown("other", true)
    tick(window)
end)

-- Last: the extra items below fill the page for the rest of the file.
test("the list scrolls: every item and header is listed, no 'and N more' (spec 020)", function()
    -- 15 more fish kinds of item: with the headers they no longer fit the old 16 rows.
    for itemID = 91001, 91015 do
        item_classes[itemID] = { 7, 8 }
        fish_cast({ { itemID, 1 } })
    end
    tick(window)
    local items, headers = 0, 0
    for _, row in ipairs(list_rows(here.list)) do
        if row:IsShown() then
            if row.itemID then items = items + 1 else headers = headers + 1 end
        end
    end
    eq(items, 20, "every item")
    eq(here.more, nil, "no 'and N more' line")
end)
