-- UI/CatalogTab.lua and UI/CatchHere.lua with a kind choice saved in an earlier session (spec 014, FR-008): the
-- first draw already hides it.

OneKeyFishingDB = { settings = { hiddenKinds = { containers = true } } }
player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
load_addon(function()
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = {
        ["1415:3:47"] = catch_cell(60, 0, { [6291] = { 40, 40 }, [6355] = { 20, 20 } }),
    } }
end)

local L = ns.L

test("the saved choice is kept and hides containers at the first draw of both tabs", function()
    eq(ns.db.settings.hiddenKinds.containers, true, "kept by the defaults")
    ns.StatsFrame.OpenCatalog()
    local window = _G.OneKeyFishingStatsFrame
    advance(0)
    tick(window)
    local elements = {}
    for _, element in ipairs(scroll_elements(window.catalogPage.list.box)) do
        elements[#elements + 1] = element.header and ("H:" .. element.header) or tostring(element.itemID)
    end
    eq(table.concat(elements, ","), "H:fish,6291", "catalog")
    eq(window.catalogPage.kindButton.text, (L["Kinds: %d of %d"]):format(4, 5), "catalog button")
    click(L["What can be caught here"], window)
    tick(window)
    local here = window.herePage
    eq(here.rows[1].header.text, L["Fish"], "the fish header")
    eq(here.rows[2].itemID, 6291, "the fish")
    assert(not here.rows[3]:IsShown(), "no container")
    eq(here.kindButton.text, (L["Kinds: %d of %d"]):format(4, 5), "catch tab button")
end)
