-- UI/CatalogTab.lua with an order saved in an earlier session (specs/017-catalog-sort, FR-010): the first draw of the
-- catalog already uses it. The data of tests/ui/catalog_sort_test.lua.

OneKeyFishingDB = { settings = { catalogSort = "price" } }
local FISH1, FISH2, FISH3, BOX1, BOX2, BOX3 = 6291, 6303, 6289, 6355, 21113, 21150
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
        ["1417:3:11"] = catch_cell(10, 0, { [FISH3] = { 10, 10 } }),
    } }
end)

local L = ns.L

test("the saved order is kept and used at the first draw", function()
    eq(ns.db.settings.catalogSort, "price", "kept by the defaults")
    ns.StatsFrame.OpenCatalog()
    local window = _G.OneKeyFishingStatsFrame
    advance(0)
    tick(window)
    local tab = window.catalogPage
    local elements = {}
    for _, element in ipairs(scroll_elements(tab.list.box)) do
        elements[#elements + 1] = element.header and ("H:" .. element.header) or tostring(element.itemID)
    end
    eq(table.concat(elements, ","), table.concat({ "H:fish", FISH1, FISH2, FISH3, "H:containers", BOX2, BOX1, BOX3 },
        ","), "by price")
    for _, row in ipairs(scroll_rows(tab.list.box)) do
        if row.itemID == BOX3 then
            eq(row.zones.text, L["No price"], "no price")
        elseif row.itemID then
            eq(row.zones.text, ns.FormatMoney(ns.Prices.Get(row.itemID)), "price of " .. row.itemID)
        end
    end
    eq(tab.sortButton.text, (L["Sort: %s"]):format(L["Price"]), "the button")
end)
