-- UI/CatalogTab.lua: the catalog's Skill button under the cumulative skill filter (specs/021-cumulative-skill-filter,
-- US4): "Skill: All" on open, the own range marked in its menu, "up to" a range sums the ranges below it in the list,
-- an item's zones and its spots; the Skill column keeps the ranges an item was caught in. The tests run in order and
-- share one login.

local LOW, MID, HIGH = 6291, 6303, 6289 -- caught with 0-74, 75-149 and 225-299

local function cell(c, items)
    local out = catch_cell(c, 0, items)
    out.k = 1
    return out
end

player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 180
load_addon(function()
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = {
        ["1415:0:47"] = cell(60, { [LOW] = { 60, 60 } }),
        ["1415:1:11"] = cell(60, { [MID] = { 30, 30 }, [LOW] = { 30, 30 } }),
        ["1415:3:47"] = cell(60, { [HIGH] = { 60, 60 } }),
    } }
end)

local L = ns.L
ns.StatsFrame.Toggle()
local window = _G.OneKeyFishingStatsFrame
local tab = window.catalogPage

local function settle()
    advance(0)
    tick(window)
end

local function listed()
    local ids = {}
    for _, element in ipairs(scroll_elements(tab.list.box)) do
        if element.itemID then
            ids[element.itemID] = true
        end
    end
    return ids
end

local function rows(list)
    local all = list.box and scroll_rows(list.box) or list.rows
    local shown = {}
    for _, row in ipairs(all) do
        if row:IsShown() and not row.kindHeader then
            table.insert(shown, row)
        end
    end
    return shown
end

test("the catalog opens on every skill", function()
    click(L["Catch catalog"], window)
    settle()
    eq(tab.skillButton.text, L["Skill: All"], "the button")
    local ids = listed()
    assert(ids[LOW] and ids[MID] and ids[HIGH], "every item")
end)

test("its menu marks the own range, the one the menu of the other tab marks", function()
    tab.skillButton.scripts.OnClick(tab.skillButton)
    assert(menu_entry((L["Up to %d (yours)"]):format(224)), "150-224 is the own range")
    eq(menu_entry((L["All (%d+)"]):format(300)).isSelected(), true, "all is checked")
end)

test("the tooltip says what the list sums", function()
    tab.skillButton.scripts.OnEnter(tab.skillButton)
    eq(tooltip_lines[2], L["Catches with any skill."], "all")
end)

test("up to 149 sums 0-74 and 75-149 in the list", function()
    tab.skillButton.scripts.OnClick(tab.skillButton)
    menu_entry((L["Up to %d"]):format(149)).onClick()
    settle()
    eq(tab.skillButton.text, (L["Skill: Up to %d"]):format(149), "the button")
    local ids = listed()
    assert(ids[LOW] and ids[MID], "the items of 0-74 and 75-149")
    eq(ids[HIGH], nil, "not the item of 225-299")
end)

test("an item's zone and spots sum the same ranges; the Skill column keeps where it was caught", function()
    ns.CatalogTab.Show(LOW)
    settle()
    local zone = rows(tab.places)[1]
    eq(zone.catches.text, "120", "the zone's catches up to 149: 60 + 60, not the 60 of 225-299")
    eq(zone.skill.text, ns.RangeLabel(0, 1), "0-149")
    zone.scripts.OnClick(zone, "LeftButton")
    -- two spots without a known subzone and nothing else: their one group opens at once (spec 024)
    eq(#rows(tab.places), 3, "the zone and its two spots")
    ns.CatalogTab.Show(nil)
end)
