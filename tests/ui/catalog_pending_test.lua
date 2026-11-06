-- UI/CatalogTab.lua and UI/Toast.lua: an item asked for while the catalog's index is still building, and the map
-- pin's answers with catch notifications off. Its own login, so no index is built when the first test runs. The
-- tests run in order and share that login.

local FISH, TROUT = 6291, 6303
item_names[FISH] = "Deviate Fish"
item_names[TROUT] = "Truite"

player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
load_addon(function()
    local cell = catch_cell(60, 0, { [FISH] = { 30, 30 }, [TROUT] = { 30, 30 } })
    cell.k, cell.px, cell.py = 3, 450 * 60, 720 * 60
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = { ["1415:3:47"] = cell } }
end)

local L = ns.L

test("an item asked for before the index is built opens once it is (FR-024)", function()
    ns.StatsFrame.OpenCatalog(FISH)
    local window = _G.OneKeyFishingStatsFrame
    local tab = window.catalogPage
    assert(tab.listView:IsShown(), "the list while building")
    eq(tab.status.text, L["Counting the catch..."], "building")
    eq(tab.search:GetText() or "", "", "the name is not put into the search")
    advance(0)
    tick(window)
    assert(tab.itemView:IsShown(), "the item page once built")
    eq(tab.title.text, "[Item " .. FISH .. "]", "the item")
end)

test("typing while the index builds drops the request", function()
    local window = _G.OneKeyFishingStatsFrame
    local tab = window.catalogPage
    ns.CatalogTab.Show(nil)
    ns.CatalogTab.SetRange(0) -- a filter not used yet: its own index, building
    ns.StatsFrame.OpenCatalog(TROUT)
    type_text(tab.search, "dev")
    advance(0)
    tick(window)
    assert(tab.listView:IsShown(), "still the list")
    eq(tab.search:GetText(), "dev", "the typed search")
    type_text(tab.search, "")
end)

test("another tab ends the request: coming back later shows the list, not the old item", function()
    local window = _G.OneKeyFishingStatsFrame
    local tab = window.catalogPage
    ns.CatalogTab.SetRange(3) -- another new filter (the seed cell is range 3): its own index, building
    ns.StatsFrame.OpenCatalog(FISH)
    click(L["Statistics"], window)
    advance(0)
    click(L["Catch catalog"], window)
    tick(window)
    assert(tab.listView:IsShown(), "still the list")
end)

test("the search box's clear button ends the request", function()
    local window = _G.OneKeyFishingStatsFrame
    local tab = window.catalogPage
    ns.CatalogTab.SetRange(2)
    ns.StatsFrame.OpenCatalog("deviate")
    eq(tab.search:GetText(), "deviate", "a text fills the search at once")
    tab.search.clearButton.scripts.OnClick(tab.search.clearButton, "LeftButton")
    advance(0)
    tick(window)
    assert(tab.listView:IsShown(), "still the list")
    eq(tab.search:GetText(), "", "cleared")
    ns.CatalogTab.SetRange("all")
end)

local function shown(text, within)
    local frame = find_frame(text, within)
    return frame ~= nil and frame:IsShown()
end

test("the pin answers with catch notifications off; catches stay quiet", function()
    ns.db.settings.toasts = false
    ns.MapPin.Set({ mapID = 1415, x = 0.45, y = 0.72 }, "Here")
    assert(shown((L["Map pin: %s"]):format("Here")), "the pin's name")
    local toasts = find_frame((L["Map pin: %s"]):format("Here")).parent -- the toast lines' frame
    ns.charDB.pin, user_waypoint, waypoint_result = nil, nil, false
    ns.MapPin.Set({ mapID = 1415, x = 0.45, y = 0.72 }, "Here")
    assert(shown(L["The game did not accept the map pin."]), "the refusal")
    waypoint_result = nil
    ns.Fire("FISH_MISSED", 1)
    assert(not shown(L["Nothing caught"], toasts), "a miss still follows the setting")
end)
