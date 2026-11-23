-- Catalog.GroupSpots and the grouped spots of both tabs (specs/024-best-places US3, US4, research R2, R6): a subzone
-- appears once per zone (SC-003), a one-spot subzone is that spot's row, spots without a subzone form "No subzone",
-- a group sums its spots and pins its best one; a group's gold per hour is its summed value over its summed time.

local FISH, CHEST = 6291, 6355
item_prices[FISH], item_prices[CHEST] = 10, 100
area_names[101], area_names[102] = "Baradin Bay", "Menethil Harbor"
local function cell(c, t, x, y, area, chests)
    return { c = c, m = 0, t = t, k = 1, px = x * c * 10, py = y * c * 10, a = area and { [area] = c } or nil,
        i = { [FISH] = { c - (chests or 0), c - (chests or 0) }, [CHEST] = chests and { chests, chests } or nil } }
end
waypoint_maps[3200] = true
load_addon(function()
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = {
        ["3200:0:11"] = cell(60, 600, 15, 15, 101, 30), -- Baradin Bay, the best
        ["3200:0:12"] = cell(60, 1200, 15, 25, 101),
        ["3200:0:13"] = cell(60, 600, 15, 35, 101),
        ["3200:0:21"] = cell(60, 600, 25, 15, 102), -- Menethil Harbor alone
        ["3200:0:31"] = cell(60, 600, 35, 15, nil), -- no subzone
        ["3200:0:32"] = cell(10, 100, 35, 25, nil), -- no subzone, little data
    } }
end)

local Catalog, BestPlaces = ns.Catalog, ns.BestPlaces
local FILTER = { range = "all", source = "all", water = "all", bonus = "all" }

local function labels(list)
    local out = {}
    for _, element in ipairs(list) do
        table.insert(out, element.spots and ("G:" .. tostring(element.area) .. "x" .. #element.spots)
            or ("S:" .. element.cell))
    end
    return table.concat(out, ",")
end

test("best places: one group per subzone, a lone spot as its row, the rest under No subzone (SC-003)", function()
    local list = BestPlaces.Spots(3200, FILTER)
    -- Baradin Bay earns the most; No subzone and Menethil Harbor earn the same, No subzone has more catches
    eq(labels(list), "G:101x3,G:falsex2,S:21", "groups and the lone spot, best first")
    eq(Catalog.GroupName(list[1]), "Baradin Bay", "the subzone's name")
    eq(Catalog.GroupName(list[2]), ns.L["No subzone"], "No subzone")
end)

test("a group's gold per hour is its summed value over its summed time, its pin its best spot's", function()
    local group = BestPlaces.Spots(3200, FILTER)[1]
    -- values per spot: 11: 30 x 10 + 30 x 100 = 3300 copper in 600 s; 12: 600 in 1200 s; 13: 600 in 600 s
    near(group.goldPerHour, (3300 + 600 + 600) / (600 + 1200 + 600) * 3600, "summed value over time, not the mean")
    eq(group.catches, 180, "catches")
    eq(group.spots[1].cell, "11", "the best spot first")
    eq(group.pin, group.spots[1].pin, "its pin")
    assert(group.pin, "a pin")
end)

test("the catalog groups an item's spots the same way, chance weighted by catches (US4)", function()
    Catalog.Items(FILTER)
    flush_timers()
    local list = Catalog.SpotGroups(FISH, 3200, FILTER)
    -- by the fish's chance: 1 at Menethil Harbor and without a subzone, 2.5 / 3 at Baradin Bay
    eq(labels(list), "S:21,G:falsex2,G:101x3", "the same groups, by chance")
    near(list[3].chance, (30 / 60 + 1 + 1) / 3, "the item's chance over the group")
    eq(list[3].catches, 180, "catches")
end)

test("a group's share without a price counts pieces, not catches", function()
    local mine = ns.db.shared.mine
    item_prices[6358] = 0
    -- spot A: 100 catches of 0.1 piece of an unpriced item and fish; spot B: 100 catches of 2 fish pieces
    mine["3202:0:11"] = { c = 100, m = 0, t = 1000, px = 1500, py = 1500, a = { [101] = 100 },
        i = { [6358] = { 10, 10 }, [FISH] = { 90, 90 } } }
    mine["3202:0:21"] = { c = 100, m = 0, t = 1000, px = 2500, py = 1500, a = { [101] = 100 },
        i = { [FISH] = { 100, 200 } } }
    mine["3202:0:31"] = { c = 100, m = 0, t = 1000, px = 3500, py = 1500, a = { [102] = 100 },
        i = { [FISH] = { 100, 100 } } }
    area_names[102] = "Menethil Harbor"
    ns.Fire("SHARED_DATA_CHANGED")
    local own = { range = "all", source = "mine", water = "all", bonus = "all" }
    local group
    for _, element in ipairs(BestPlaces.Spots(3202, own)) do
        group = group or (element.spots and element)
    end
    -- pieces: A 0.1 + 0.9 per catch, B 2 per catch; unpriced 0.1 per catch of A only
    near(group.unpriced, (0.1 * 100) / ((0.1 + 0.9) * 100 + 2 * 100), "by pieces")
end)
