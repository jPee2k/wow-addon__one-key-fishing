-- UI/CatalogTab.lua without the game's scroll templates (V37's fallback): the fixed rows draw the kind headers of
-- spec 014 too (specs/014-catch-filters, T010).

no_scroll_templates = true
player_map_id = 1415
fishing_rank = 230
load_addon(function()
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = {
        ["1415:3:47"] = catch_cell(60, 0, { [6291] = { 40, 40 }, [6355] = { 20, 20 } }),
    } }
end)

local L = ns.L
ns.StatsFrame.OpenCatalog()
local tab = _G.OneKeyFishingStatsFrame.catalogPage

test("the fixed rows show a header before each kind's items", function()
    advance(0)
    tick(_G.OneKeyFishingStatsFrame)
    local shown = {}
    for _, row in ipairs(tab.list.rows) do
        if row:IsShown() then
            shown[#shown + 1] = row.itemID and tostring(row.itemID) or ("H:" .. row.name.text)
        end
    end
    eq(table.concat(shown, ","), table.concat({ "H:" .. L["Fish"], 6291, "H:" .. L["Containers"], 6355 }, ","), "rows")
end)

test("a kind header never takes the last fixed row: its items go to 'and N more'", function()
    local rows = #tab.list.rows
    -- Fish (7 / 8) to fill every row but the last one after the Fish header, then one chest: its header would land on
    -- the last row.
    local items = {}
    for i = 1, rows - 2 do
        item_classes[50000 + i] = { 7, 8 }
        items[50000 + i] = { 5, 5 }
    end
    items[6355] = { 5, 5 }
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = { ["1415:3:47"] = catch_cell(200, 0, items) } }
    ns.Fire("SHARED_DATA_CHANGED")
    tick(_G.OneKeyFishingStatsFrame)
    advance(0)
    tick(_G.OneKeyFishingStatsFrame)
    eq(tab.list.rows[rows - 1]:IsShown(), true, "the last fish")
    eq(tab.list.rows[rows]:IsShown(), false, "no lone header on the last row")
    eq(tab.list.more.text, (L["and %d more"]):format(1), "the chest is counted")
end)
