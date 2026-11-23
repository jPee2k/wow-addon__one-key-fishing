-- UI/CatalogTab.lua with the item kinds of spec 014 (specs/014-catch-filters): the list under kind headers, the kind
-- button shared with "What can be caught here", the empty-by-filter texts, a hidden item opened by its ID.
-- The tests run in order and share one login.

local FISH, TROUT, CHEST, TRUNK, POTION = 6291, 6303, 6355, 21113, 858
item_names[FISH] = "Brilliant Smallfish"
item_names[TROUT] = "Slitherskin Mackerel"
item_names[CHEST] = "Sturdy Locked Chest"
item_names[TRUNK] = "Watertight Trunk"
item_names[POTION] = "Lesser Healing Potion"

player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
load_addon(function()
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = {
        ["1415:3:47"] = catch_cell(80, 0, { [FISH] = { 30, 30 }, [TROUT] = { 20, 20 }, [CHEST] = { 10, 10 },
            [TRUNK] = { 10, 10 }, [POTION] = { 10, 10 } }),
    } }
end)

local L = ns.L
ns.StatsFrame.Toggle()
local window = _G.OneKeyFishingStatsFrame
local tab = window.catalogPage

-- The list's elements as "H:<kind>" for a header and the item ID for an item.
local function Elements()
    local out = {}
    for _, element in ipairs(scroll_elements(tab.list.box)) do
        out[#out + 1] = element.header and ("H:" .. element.header) or tostring(element.itemID)
    end
    return table.concat(out, ",")
end

test("setup: the catalog is ready", function()
    click(L["Catch catalog"], window)
    advance(0)
    tick(window)
    eq(tab.status.text, "", "ready")
end)

test("the list is grouped under kind headers, the items by name inside each (FR-006)", function()
    -- Names in the test are "[Item <id>]" (ns.ItemDisplay), so by name means by ID here.
    eq(Elements(), table.concat({ "H:fish", FISH, TROUT, "H:containers", CHEST, TRUNK, "H:potions", POTION }, ","),
        "elements")
end)

test("a header row draws the kind's text, no icon, no zones, and does nothing on hover or click", function()
    local rows = scroll_rows(tab.list.box)
    local header = rows[1]
    eq(header.name.text, L["Fish"], "the kind's text")
    eq(header.icon:IsShown(), false, "no icon")
    eq(header.zones.text, "", "no zones")
    eq(header.itemID, nil, "no item")
    tooltip_shown = false
    header.scripts.OnEnter(header)
    eq(tooltip_shown, false, "no tooltip")
    header.scripts.OnClick(header, "LeftButton")
    assert(tab.listView:IsShown(), "still the list")
    local item = rows[2]
    eq(item.itemID, FISH, "an item row after it")
    eq(item.icon:IsShown(), true, "the item's icon")
    eq(item.zones.text, (L["Zones: %d"]):format(1), "zones")
end)

-- US2: the kind button of the catalog, one choice with "What can be caught here" (FR-007 to FR-011).


test("the catalog has the kind button; the filter row keeps its three buttons of 150", function()
    eq(tab.kindButton.text, L["Kinds: All"], "button")
    for _, name in ipairs({ "skillButton", "sourceButton", "waterButton" }) do
        eq(tab[name].minWidth, 150, name .. ": the filter row as before spec 014")
    end
    eq(tab.kindButton.minWidth, 120, "the Kinds button")
    -- Row B (spec 020): the slot of Water or Camp bonus, Kinds, Sort; without pool or bonus data Kinds starts it.
    assert(anchor(tab.kindButton, "TOPLEFT"), "the Kinds button at the slot's place")
    local sort = anchor(tab.sortButton, "LEFT")
    eq(sort[2], tab.kindButton, "Sort after Kinds")
    eq(sort[3], "RIGHT", "to its right")
end)

test("a toggle from the catalog's own button updates its list at once (FR-007)", function()
    tab.kindButton.scripts.OnClick(tab.kindButton)
    menu_entry(L["Containers"]).onClick()
    -- No tick.
    eq(Elements(), table.concat({ "H:fish", FISH, TROUT, "H:potions", POTION }, ","), "containers gone")
    eq(tab.kindButton.text, (L["Kinds: %d of %d"]):format(6, 7), "button")
    menu_entry(L["Containers"]).onClick()
    eq(Elements(), table.concat({ "H:fish", FISH, TROUT, "H:containers", CHEST, TRUNK, "H:potions", POTION }, ","),
        "back")
end)

test("a kind hidden from the catch tab's menu is hidden in the catalog too (one choice)", function()
    ns.CatchHere.OpenKindMenu(tab.kindButton)
    menu_entry(L["Potions & drinks"]).onClick()
    eq(Elements(), table.concat({ "H:fish", FISH, TROUT, "H:containers", CHEST, TRUNK }, ","), "no potions")
    ns.Catalog.SetKindShown("potions", true)
end)

test("every kind hidden: the filter's text; with a search, the matches text (FR-011)", function()
    for _, kind in ipairs(ns.Catalog.KINDS) do
        ns.Catalog.SetKindShown(kind, false)
    end
    ns.CatalogTab.Refresh()
    eq(Elements(), "", "nothing listed")
    eq(tab.status.text, L["The kind filter hides every item."], "no search")
    type_text(tab.search, "Lesser")
    eq(tab.status.text, L["The kind filter hides the matches."], "with a search")
    type_text(tab.search, "zzz")
    eq(tab.status.text, L["No item matches the search."], "no match at all: the search's own text")
    type_text(tab.search, "")
    ns.CatalogTab.SetSource("mine")
    advance(0)
    tick(window)
    eq(tab.status.text, L["You have not caught anything yet."], "no rows at all: the present text")
    ns.CatalogTab.SetSource("all")
    for _, kind in ipairs(ns.Catalog.KINDS) do
        ns.Catalog.SetKindShown(kind, true)
    end
    ns.CatalogTab.Refresh()
    eq(tab.status.text, "", "items shown again")
end)

test("tooltips are not filtered: a hidden container's Caught in lines stay (spec edge case)", function()
    local before = ns.Catalog.TooltipLines(TRUNK)
    ns.Catalog.SetKindShown("containers", false)
    local after = ns.Catalog.TooltipLines(TRUNK)
    assert(before and after, "lines for the trunk")
    eq(#after, #before, "the same number of lines")
    for i, line in ipairs(before) do
        eq(after[i][1], line[1], "zone " .. i)
        eq(after[i][2], line[2], "right " .. i)
    end
    ns.Catalog.SetKindShown("containers", true)
end)

-- US3: an item asked for by its ID opens whatever its kind (FR-012).

test("with containers hidden, a container opened by ID shows its zones; Back returns to the list without it", function()
    ns.Catalog.SetKindShown("containers", false)
    ns.CatalogTab.Show(TRUNK)
    assert(tab.itemView:IsShown(), "the item page")
    eq(tab.title.text, "[Item " .. TRUNK .. "]", "the trunk")
    eq(#scroll_rows(tab.places.box), 1, "its zone")
    click(L["Back"], tab)
    eq(Elements(), table.concat({ "H:fish", FISH, TROUT, "H:potions", POTION }, ","), "the list still hides containers")
    -- The path of a chat link and of a row of "What can be caught here".
    ns.StatsFrame.OpenCatalog(TRUNK)
    assert(tab.itemView:IsShown(), "opened through the window")
    eq(tab.title.text, "[Item " .. TRUNK .. "]", "the trunk again")
    click(L["Back"], tab)
    -- The command with an item link (Core/Commands.lua: OpenCatalog(CommandArg(rest))).
    ns.StatsFrame.OpenCatalog(ns.Catalog.CommandArg("|cffffffff|Hitem:" .. TRUNK .. "::::::::|h[Watertight Trunk]|h|r"))
    assert(tab.itemView:IsShown(), "opened by the command's link")
    eq(tab.title.text, "[Item " .. TRUNK .. "]", "the trunk by link")
    click(L["Back"], tab)
end)

test("with containers hidden, a container's name searched chooses nothing and says the filter hides it", function()
    ns.CatalogTab.Show("Watertight")
    assert(tab.listView:IsShown(), "the list, not an item page")
    eq(Elements(), "", "nothing listed")
    eq(tab.status.text, L["The kind filter hides the matches."], "said why")
    type_text(tab.search, "")
    ns.Catalog.SetKindShown("containers", true)
end)

test("a name matching one shown item and one hidden one opens the shown one (R9)", function()
    -- "Sturdy Locked Chest" (container) and "Lesser Healing Potion" (potion) both contain "es".
    ns.Catalog.SetKindShown("containers", false)
    ns.CatalogTab.Show("es")
    assert(tab.itemView:IsShown(), "the one match the filter shows is opened")
    eq(tab.title.text, "[Item " .. POTION .. "]", "the potion")
    click(L["Back"], tab)
    type_text(tab.search, "")
    ns.Catalog.SetKindShown("containers", true)
end)
