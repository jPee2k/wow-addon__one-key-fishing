-- UI/CatalogTab.lua with the list's order of spec 017 (specs/017-catalog-sort): the Sort button and its menu, the order
-- inside the kind groups, the right column per order ("No price" grey), the redraw on new prices, the list from its top
-- after a new order, and the three rows of buttons. The tests run in order and share one login.
-- No item_names: the stub names the items "Item <id>", compared as text by the order by name.

local FISH1, FISH2, FISH3 = 6291, 6303, 6289 -- fish
local BOX1, BOX2, BOX3 = 6355, 21113, 21150 -- containers; BOX3 has no price
item_prices[FISH1], item_prices[FISH2], item_prices[FISH3] = 300, 200, 100
item_prices[BOX1], item_prices[BOX2] = 50, 80

player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
load_addon(function()
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = {
        ["1415:3:47"] = catch_cell(100, 0, { [FISH1] = { 50, 50 }, [FISH2] = { 30, 30 }, [BOX1] = { 10, 10 },
            [BOX2] = { 10, 10 } }),
        ["1416:3:11"] = catch_cell(60, 0, { [FISH2] = { 50, 50 }, [BOX3] = { 10, 10 } }),
        ["1417:3:11"] = catch_cell(10, 0, { [FISH3] = { 10, 10 } }), -- little data: 10 catches on the map
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

local function join(...)
    local out = {}
    for _, value in ipairs({ ... }) do
        out[#out + 1] = tostring(value)
    end
    return table.concat(out, ",")
end

-- The drawn row of an item (a new frame per call, as scroll_rows makes them).
local function RowOf(itemID)
    for _, row in ipairs(scroll_rows(tab.list.box)) do
        if row.itemID == itemID then
            return row
        end
    end
end

local function Choose(text)
    tab.sortButton.scripts.OnClick(tab.sortButton)
    menu_entry(text).onClick()
end

local function IsGrey(color)
    return color ~= nil and color[1] == color[2] and color[2] == color[3] and color[1] < 1
end

local function IsWhite(color)
    return color ~= nil and color[1] == 1 and color[2] == 1 and color[3] == 1
end

test("setup: the catalog is ready", function()
    click(L["Catch catalog"], window)
    advance(0)
    tick(window)
    eq(tab.status.text, "", "ready")
end)

---------------------------------------------------------------------------
-- By name, the default (T016)
---------------------------------------------------------------------------
test("the default: by name as before, Zones: N in each row (SC-005)", function()
    eq(Elements(), join("H:fish", FISH3, FISH1, FISH2, "H:containers", BOX2, BOX3, BOX1), "by name")
    for _, row in ipairs(scroll_rows(tab.list.box)) do
        if row.itemID then
            local zones = row.itemID == FISH2 and 2 or 1
            eq(row.zones.text, (L["Zones: %d"]):format(zones), "zones of " .. row.itemID)
            assert(IsWhite(row.zones.textColor), "white " .. row.itemID)
        end
    end
end)

---------------------------------------------------------------------------
-- By price (T009)
---------------------------------------------------------------------------
test("the Sort button and its menu: three radio entries, the current one marked", function()
    eq(tab.sortButton.text, (L["Sort: %s"]):format(L["Name"]), "the button")
    tab.sortButton.scripts.OnClick(tab.sortButton)
    eq(#menu_entries, 3, "three entries")
    local texts = {}
    for _, entry in ipairs(menu_entries) do
        eq(entry.kind, "radio", "a radio entry")
        texts[#texts + 1] = entry.text
        eq(entry.isSelected(), entry.text == L["Name"], "marked: " .. entry.text)
    end
    eq(table.concat(texts, "|"), table.concat({ L["Name"], L["Price"], L["Chance"] }, "|"), "the order of SORTS")
end)

test("Price reorders at once inside the kind groups; each row shows its price; no price last and grey", function()
    menu_entry(L["Price"]).onClick()
    -- No tick.
    eq(Elements(), join("H:fish", FISH1, FISH2, FISH3, "H:containers", BOX2, BOX1, BOX3), "by price")
    eq(tab.sortButton.text, (L["Sort: %s"]):format(L["Price"]), "the button")
    for _, itemID in ipairs({ FISH1, FISH2, FISH3, BOX1, BOX2 }) do
        local row = RowOf(itemID)
        eq(row.zones.text, ns.FormatMoney(ns.Prices.Get(itemID)), "price of " .. itemID)
        assert(IsWhite(row.zones.textColor), "white " .. itemID)
    end
    local noPrice = RowOf(BOX3)
    eq(noPrice.zones.text, L["No price"], "no price")
    assert(IsGrey(noPrice.zones.textColor), "grey")
end)

test("a reused row frame turns white again", function()
    local row = RowOf(BOX3)
    assert(IsGrey(row.zones.textColor), "grey first")
    local fish
    for _, element in ipairs(scroll_elements(tab.list.box)) do
        if element.itemID == FISH1 then
            fish = element
        end
    end
    tab.list.box.view.initializer(row, fish)
    eq(row.zones.text, ns.FormatMoney(300), "the fish's price")
    assert(IsWhite(row.zones.textColor), "white again")
end)

test("new prices reorder the list at the next tick (FR-009)", function()
    ns.db.prices[FISH3] = { price = 1000, quantity = 20, lots = 10, time = 1 }
    ns.Fire("PRICES_CHANGED")
    tick(window)
    eq(Elements(), join("H:fish", FISH3, FISH1, FISH2, "H:containers", BOX2, BOX1, BOX3), "the scanned price")
    ns.db.settings.auctionPrices = false
    ns.Fire("SETTINGS_CHANGED", "auctionPrices")
    tick(window)
    eq(Elements(), join("H:fish", FISH1, FISH2, FISH3, "H:containers", BOX2, BOX1, BOX3), "vendor prices again")
    ns.db.settings.auctionPrices = true
    ns.db.prices[FISH3] = nil
    ns.Fire("PRICES_CHANGED")
    tick(window)
end)

---------------------------------------------------------------------------
-- By chance (T013)
---------------------------------------------------------------------------
-- The chance text of the first zone row on an item's page; back to the list after.
local function FirstZoneChance(itemID)
    RowOf(itemID).scripts.OnClick(RowOf(itemID), "LeftButton")
    assert(tab.itemView:IsShown(), "the item's page")
    local first = scroll_rows(tab.places.box)[1]
    local text = first.chance.text
    click(L["Back"], tab.itemView)
    return text
end

test("Chance reorders inside the kind groups; each row shows its best zone's chance", function()
    Choose(L["Chance"])
    eq(Elements(), join("H:fish", FISH2, FISH1, FISH3, "H:containers", BOX3, BOX2, BOX1), "by chance")
    eq(tab.sortButton.text, (L["Sort: %s"]):format(L["Chance"]), "the button")
    eq(RowOf(FISH2).zones.text, ns.Percent(50 / 60), "6303 by its map 1416")
    eq(RowOf(FISH3).zones.text, L["Little data"], "little data only")
    for _, itemID in ipairs({ FISH1, FISH2, FISH3, BOX1, BOX2, BOX3 }) do
        eq(RowOf(itemID).zones.text, FirstZoneChance(itemID), "the first zone of " .. itemID)
    end
end)

test("an item's page keeps its zones by chance whatever the list's order (spec edge case)", function()
    Choose(L["Price"])
    RowOf(FISH2).scripts.OnClick(RowOf(FISH2), "LeftButton")
    local zones = {}
    for _, element in ipairs(scroll_elements(tab.places.box)) do
        zones[#zones + 1] = tostring(element.place.mapID)
    end
    eq(table.concat(zones, ","), "1416,1415", "by chance")
    click(L["Back"], tab.itemView)
end)

---------------------------------------------------------------------------
-- The scroll after a new order (T016)
---------------------------------------------------------------------------
test("a new order shows the list from its top; a kind toggle keeps the scroll", function()
    Choose(L["Chance"])
    eq(tab.list.box.retainScroll, nil, "from the top after a new order (FR-002)")
    Choose(L["Name"])
    eq(tab.list.box.retainScroll, nil, "from the top again")
    ns.Catalog.SetKindShown("containers", false)
    eq(tab.list.box.retainScroll, true, "a kind toggle keeps the scroll")
    ns.Catalog.SetKindShown("containers", true)
end)

---------------------------------------------------------------------------
-- The three rows of buttons (T018)
---------------------------------------------------------------------------
test("the layout: search; status; Skill, Source; Water or Camp bonus, Kinds, Sort; the list (spec 020)", function()
    eq(anchor(tab.search, "TOPLEFT")[3], -32, "the search box")
    eq(anchor(tab.status, "TOPLEFT")[3], -56, "the status line under it")
    eq(anchor(tab.skillButton, "TOPLEFT")[3], -88, "row A: Skill")
    local source = anchor(tab.sourceButton, "LEFT")
    eq(source[2], tab.skillButton, "row A: Source after Skill")
    eq(source[3], "RIGHT", "to its right")
    eq(anchor(tab.waterButton, "TOPLEFT")[3], -114, "row B: the slot of Water or Camp bonus")
    eq(anchor(tab.bonusButton, "TOPLEFT")[3], -114, "the same slot")
    eq(tab.sortButton.minWidth, 150, "Sort is 150 wide")
    local sort = anchor(tab.sortButton, "LEFT")
    eq(sort[2], tab.kindButton, "row B: Sort after Kinds")
    eq(sort[3], "RIGHT", "to its right")
    eq(anchor(tab.list.box, "TOPLEFT")[3], -146, "the list below row B")
end)

---------------------------------------------------------------------------
-- Review fix: the right column holds a price of three coins
---------------------------------------------------------------------------
test("the right column is wide enough for a price in gold, silver and copper, and still fits the row", function()
    local row = RowOf(FISH1)
    assert(row.zones.width >= 140, "a price like 123g 45s 67c with three coin icons needs about 120 px")
    assert(22 + row.name.width <= 520 - 4 - row.zones.width, "the name ends before the right column starts")
end)

test("the stub keeps one anchor per point, as the game: a second SetPoint of a point replaces it", function()
    local frame = CreateFrame("Frame")
    frame:SetPoint("LEFT", tab.skillButton, "RIGHT", 8, 0)
    frame:SetPoint("TOPLEFT", 1, 2)
    frame:SetPoint("LEFT", tab.sortButton, "RIGHT", 8, 0)
    eq(anchor(frame, "LEFT")[2], tab.sortButton, "the anchor in effect")
    eq(#frame.points, 2, "one per point")
end)

---------------------------------------------------------------------------
-- Review fix: a vendor price that arrives after the draw
---------------------------------------------------------------------------
test("by price, item info that arrives later (GET_ITEM_INFO_RECEIVED) redraws the list at the next tick", function()
    Choose(L["Price"])
    tick(window) -- nothing pending
    eq(RowOf(BOX3).zones.text, L["No price"], "no price yet")
    item_prices[BOX3] = 90 -- the client now has the item's full info, its vendor price with it
    fire("GET_ITEM_INFO_RECEIVED", BOX3, true)
    tick(window)
    eq(RowOf(BOX3).zones.text, ns.FormatMoney(90), "the price arrived")
    eq(Elements(), join("H:fish", FISH1, FISH2, FISH3, "H:containers", BOX3, BOX2, BOX1), "and its place")
    item_prices[BOX3] = nil
    fire("GET_ITEM_INFO_RECEIVED", BOX3, true)
    tick(window)
    Choose(L["Name"])
end)

test("by price, item info of an item outside the list does not redraw it (as the other tabs filter by ID)", function()
    Choose(L["Price"])
    tick(window) -- nothing pending
    local provider = tab.list.box.provider
    fire("GET_ITEM_INFO_RECEIVED", 2589, true) -- an item the catalog does not list (bags, the auction house)
    tick(window)
    eq(tab.list.box.provider, provider, "no redraw")
    fire("GET_ITEM_INFO_RECEIVED", BOX3, true) -- a listed item
    tick(window)
    assert(tab.list.box.provider ~= provider, "a listed item redraws")
    Choose(L["Name"])
end)
