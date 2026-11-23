-- UI/CatalogTab.lua and the trophy collection (specs/023-item-kinds US2): the Trophies header shows how many of the
-- trophies the account caught, and a caught trophy's row carries a check mark; another row clears it.

local FISH, CAUGHT, NOT_CAUGHT = 6291, 6292, 13917
player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
OneKeyFishingDB = { shareNotice = true, shared = { records = {},
    mine = { ["3999:0:x"] = { c = 1, m = 0, t = 10, i = { [CAUGHT] = { 1, 1 } } } } } }
load_addon(function()
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = {
        ["1415:3:47"] = catch_cell(80, 0, { [FISH] = { 40, 40 }, [CAUGHT] = { 20, 20 }, [NOT_CAUGHT] = { 20, 20 } }),
    } }
end)

local L = ns.L
ns.StatsFrame.Toggle()
local window = _G.OneKeyFishingStatsFrame
local tab = window.catalogPage

local function RowOf(key)
    for _, row in ipairs(scroll_rows(tab.list.box)) do
        if (row.kindHeader or row.itemID) == key then
            return row
        end
    end
end

test("setup: the catalog is ready", function()
    click(L["Catch catalog"], window)
    advance(0)
    tick(window)
    eq(tab.status.text, "", "ready")
end)

test("the Trophies header shows the collection's count", function()
    local _, total = ns.Catalog.TrophyCount()
    eq(RowOf("trophies").name.text, L["%s (%d/%d)"]:format(L["Trophies"], 1, total), "1 of the trophies")
    eq(RowOf("fish").name.text, L["Fish"], "other headers unchanged")
end)

test("only a trophy the account caught carries the check mark", function()
    eq(RowOf(CAUGHT).caught:IsShown(), true, "caught trophy")
    eq(RowOf(NOT_CAUGHT).caught:IsShown(), false, "trophy not caught")
    eq(RowOf(FISH).caught:IsShown(), false, "not a trophy")
    eq(RowOf("trophies").caught:IsShown(), false, "a header")
    -- The client knows the atlas (C_Texture.GetAtlasInfo): the mark is the atlas, no texture drawn over it.
    eq(RowOf(CAUGHT).caught.atlas, "common-icon-checkmark", "the atlas")
    eq(RowOf(CAUGHT).caught.texture, nil, "no fallback texture over it")
end)

test("a new trophy moves the count and the mark at the window's next tick", function()
    fish_cast({ { NOT_CAUGHT, 1 } })
    tick(window)
    local _, total = ns.Catalog.TrophyCount()
    eq(RowOf("trophies").name.text, L["%s (%d/%d)"]:format(L["Trophies"], 2, total), "2 now")
    eq(RowOf(NOT_CAUGHT).caught:IsShown(), true, "marked")
end)
