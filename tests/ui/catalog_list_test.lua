-- UI/CatalogTab.lua: the "Catch catalog" tab (specs/005-catch-catalog, contracts/ui.md). The tests run in order and
-- share one login.

local FISH, TROUT = 6291, 6303
item_names[FISH] = "Deviate Fish"
item_names[TROUT] = "Truite \195\137"
area_names[20] = "Crystal Lake"

local function cell(c, items, x, y, a, k)
    local out = catch_cell(c, 0, items)
    out.k = k or 1
    if x then
        out.px, out.py = math.floor(x * 1000 + 0.5) * c, math.floor(y * 1000 + 0.5) * c
    end
    out.a = a
    return out
end

player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
load_addon(function()
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = {
        ["1415:3:47"] = cell(60, { [FISH] = { 30, 30 }, [TROUT] = { 30, 30 } }, 0.45, 0.72, { [20] = 60 }, 3),
        ["1415:1:12"] = cell(20, { [FISH] = { 5, 5 } }, 0.51, 0.66),
        ["1429:3:11"] = cell(10, { [FISH] = { 4, 4 } }),
    } }
end)

local L = ns.L
ns.StatsFrame.Toggle()
local window = _G.OneKeyFishingStatsFrame
local tab = window.catalogPage

-- The rows the list shows (the scroll list's, made the way the game makes the rows in sight).
local function rows(list)
    if list.box then
        return scroll_rows(list.box)
    end
    local shown = {}
    for _, row in ipairs(list.rows) do
        if row:IsShown() then
            table.insert(shown, row)
        end
    end
    return shown
end

local function names(list)
    local out = {}
    for i, row in ipairs(rows(list)) do
        out[i] = row.name.text
    end
    return table.concat(out, ";")
end

test("the third tab, remembered", function()
    click(L["Catch catalog"], window)
    assert(tab:IsShown(), "shown")
    eq(ns.db.statsTab, "catalog", "saved")
    window:Hide()
    window:Show()
    assert(tab:IsShown(), "reopened on it")
end)

test("the list waits for the index, with the filters at their defaults and no Water button", function()
    eq(tab.status.text, L["Counting the catch..."], "status")
    eq(tab.search.template, "SearchBoxTemplate", "the game's search box")
    eq(tab.search.Instructions.text, L["Search by item name"], "hint")
    eq(tab.skillButton.text, (L["Skill: %s"]):format(L["All skill levels"]), "skill")
    eq(tab.sourceButton.text, (L["Source: %s"]):format(L["All"]), "source")
    assert(not (tab.waterButton and tab.waterButton:IsShown()), "no Water button without pool data")
    advance(0)
    tick(window)
    eq(tab.status.text, "", "ready")
    eq(names(tab.list), "[Item " .. FISH .. "];[Item " .. TROUT .. "]", "the items, by name")
    eq(rows(tab.list)[1].zones.text, (L["Zones: %d"]):format(2), "zones")
end)

test("typing narrows the list on every letter; clearing brings it back", function()
    type_text(tab.search, "tru")
    eq(#rows(tab.list), 1, "one match")
    eq(rows(tab.list)[1].itemID, TROUT, "the trout")
    type_text(tab.search, "zzz")
    eq(#rows(tab.list), 0, "nothing")
    eq(tab.status.text, L["No item matches the search."], "said so")
    type_text(tab.search, "")
    eq(#rows(tab.list), 2, "the full list")
end)

test("a row click opens the item page with its zones; Back keeps the search", function()
    type_text(tab.search, "dev")
    local row = rows(tab.list)[1]
    row.scripts.OnClick(row, "LeftButton")
    assert(tab.itemView:IsShown(), "item page")
    assert(not tab.listView:IsShown(), "list hidden")
    eq(tab.title.text, "[Item " .. FISH .. "]", "the item")
    local zones = rows(tab.places)
    eq(#zones, 2, "two zones")
    eq(zones[1].name.text, "Test Zone", "zone name")
    eq(zones[1].toggle.text, "+", "folded")
    eq(zones[1].skill.text, "75-299", "the skill span: ranges 1 to 3")
    eq(zones[1].chance.text, "44%", "35 of 80")
    eq(zones[1].catches.text, "80", "the zone's catches")
    eq(zones[2].chance.text, L["Little data"], "10 catches")
    click(L["Back"], tab)
    assert(tab.listView:IsShown(), "back at the list")
    eq(tab.search:GetText(), "dev", "the search kept")
    eq(#rows(tab.list), 1, "still narrowed")
end)

test("a zone's + shows its spots, indented; - hides them", function()
    ns.CatalogTab.Show(FISH)
    local zone = rows(tab.places)[1]
    zone.scripts.OnClick(zone, "LeftButton")
    local all = rows(tab.places)
    eq(#all, 4, "the zone, its two spots, the other zone")
    eq(all[1].toggle.text, "-", "expanded")
    eq(all[2].name.text, "Crystal Lake (45, 72)", "the reliable spot")
    eq(all[3].name.text, "51, 66", "the other")
    eq(all[2].toggle.text, "", "no toggle on a spot")
    all[1].scripts.OnClick(all[1], "LeftButton")
    eq(#rows(tab.places), 2, "folded")
end)

test("hover: a zone row says its catches and players; a spot row its subzone and coordinates first", function()
    local zone = rows(tab.places)[1]
    zone.scripts.OnEnter(zone)
    eq(tooltip_lines[1], "Test Zone", "the zone")
    eq(tooltip_lines[2], (L["%d catches from %d players"]):format(80, 3), "from 2 players on: the seed's largest k")
    local other = rows(tab.places)[2]
    other.scripts.OnEnter(other)
    eq(tooltip_lines[2], (L["%d catches"]):format(10), "one player: catches only")
    ns.CatalogTab.Toggle(1415)
    local spot = rows(tab.places)[2]
    spot.scripts.OnEnter(spot)
    eq(tooltip_lines[1], "Crystal Lake", "the subzone")
    eq(tooltip_lines[2], "45, 72", "the coordinates")
    eq(tooltip_lines[3], (L["%d catches from %d players"]):format(60, 3), "the players")
end)

test("a filter that leaves the item no zone says so", function()
    ns.CatalogTab.SetRange(0)
    advance(0)
    tick(window)
    eq(tab.status.text, L["No data for this item under these filters."], "said so")
    ns.CatalogTab.SetRange("all")
    advance(0)
end)

test("new data on the window's tick keeps the item, the expanded zones and the search (FR-028)", function()
    eq(#rows(tab.places), 4, "expanded zone")
    fish_cast({ { FISH, 1 } }) -- a new item of the own catch: every map moves
    tick(window)
    advance(0)
    tick(window)
    local zones = rows(tab.places)
    eq(zones[1].catches.text, "81", "the new catch")
    eq(zones[1].toggle.text, "-", "still expanded")
    eq(tab.title.text, "[Item " .. FISH .. "]", "still the item")
    ns.CatalogTab.Show(nil)
    eq(tab.search:GetText(), "dev", "the search kept")
    type_text(tab.search, "")
end)

test("Only mine without own catches of the filter says so", function()
    ns.CatalogTab.SetRange(0)
    ns.CatalogTab.SetSource("mine")
    advance(0)
    tick(window)
    eq(tab.status.text, L["You have not caught anything yet."], "said so")
    ns.CatalogTab.SetSource("all")
    ns.CatalogTab.SetRange("all")
    advance(0)
    tick(window)
end)

test("with pool data the Water button shows, and Open water builds its own index", function()
    local pooled = cell(60, { [FISH] = { 30, 30 }, [TROUT] = { 30, 30 } }, 0.45, 0.72, nil, 3)
    pooled.p = { c = 30, i = { [TROUT] = { 30, 30 } } }
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = { ["1415:3:47"] = pooled } }
    ns.Fire("SHARED_DATA_CHANGED")
    tick(window)
    assert(tab.waterButton:IsShown(), "shown")
    eq(tab.waterButton.text, (L["Water: %s"]):format(L["Everywhere"]), "the default")
    ns.CatalogTab.SetWater("open")
    advance(0)
    tick(window)
    assert(table.concat(ns.Catalog.Describe(), "\n"):find("index all|all|open: ready", 1, true), "its own index")
    for _, row in ipairs(rows(tab.list)) do
        assert(row.itemID ~= TROUT, "the trout only came from the pool")
    end
    ns.CatalogTab.SetWater("all")
end)

test("the skill range labels of both tabs come from one helper (UI/Widgets.lua)", function()
    eq(ns.RangeLabel(0), "0-74", "one range")
    eq(ns.RangeLabel(1, 2), "75-224", "a span")
    eq(ns.RangeLabel(4), "300+", "the top range")
    eq(ns.RangeLabel(1, 4), "75+", "a span to the top")
    eq(ns.RangeLabel("all"), ns.L["All skill levels"], "all")
end)
