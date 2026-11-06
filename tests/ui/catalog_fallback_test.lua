-- UI/CatalogTab.lua without the game's scroll and search templates (V37's fallback), and with an empty database.

no_scroll_templates = true
player_map_id = 1415
fishing_rank = 230
load_addon(function()
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = {} }
end)

local L = ns.L
ns.StatsFrame.OpenCatalog()
local tab = _G.OneKeyFishingStatsFrame.catalogPage

local function shown(list)
    local out = {}
    for _, row in ipairs(list.rows) do
        if row:IsShown() then
            table.insert(out, row)
        end
    end
    return out
end

test("an empty database shows the two empty lines", function()
    advance(0)
    tick(_G.OneKeyFishingStatsFrame)
    eq(tab.status.text, L["Nothing has been caught yet."] .. "\n"
        .. L["The catalog fills with your catches, the bundled data and, with sharing on, other players' catches."],
        "the empty state")
end)

test("without the templates: fixed rows with 'and N more', a plain search box that still narrows", function()
    eq(tab.list.box, nil, "no scroll list")
    assert(tab.search.template ~= "SearchBoxTemplate", "a plain input box")
    local cells = {}
    for i = 1, 40 do
        local cell = catch_cell(5, 0, { [40000 + i] = { 5, 5 } })
        cell.k = 1
        cells[(6000 + i) .. ":3:11"] = cell
    end
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = cells }
    ns.Fire("SHARED_DATA_CHANGED")
    tick(_G.OneKeyFishingStatsFrame)
    advance(0)
    tick(_G.OneKeyFishingStatsFrame)
    local rows = #tab.list.rows
    assert(rows >= 20, "a page of rows: " .. rows)
    eq(#shown(tab.list), rows, "every fixed row in use")
    eq(tab.list.more.text, (L["and %d more"]):format(40 - rows), "the rest counted")
    type_text(tab.search, "Item 4001")
    eq(#shown(tab.list), 10, "40010 to 40019")
    eq(tab.list.more.text, "", "nothing more")
end)
