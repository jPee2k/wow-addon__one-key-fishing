-- The camp bonus in the catalog (specs/020-camp-buffs FR-019, FR-020, data-model.md "A catalog place, spot and row"):
-- a tagged item's places, spots and rows take the bonus's chance, catches and players; the texts and the icon of the
-- tag; the tooltip lines. The tests run in order and share one login.

local FISH, BLOATED = 6291, 6643
item_names[FISH] = "Deviate Fish"
item_names[BLOATED] = "Bloated Brilliant Smallfish"

local function cell(c, items, k, q)
    local out = catch_cell(c, 0, items)
    out.k, out.q = k, q
    out.px, out.py = 450 * c, 720 * c
    return out
end

player_map_id = 3001
player_map_position = { 0.45, 0.72 }
fishing_rank = 230
load_addon(function()
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = {
        -- ordinary chance 10 %, under the Rack 20 %
        ["3001:3:47"] = cell(100, { [FISH] = { 90, 90 }, [BLOATED] = { 10, 10 } }, 3,
            { ["1"] = { c = 50, m = 0, k = 3, i = { [FISH] = { 40, 40 }, [BLOATED] = { 10, 10 } } } }),
        -- no data under the Rack
        ["3002:3:x"] = cell(20, { [FISH] = { 18, 18 }, [BLOATED] = { 2, 2 } }, 2),
        -- ordinary chance 7.5 %, under the Rack 30 %
        ["3003:3:x"] = cell(200, { [FISH] = { 185, 185 }, [BLOATED] = { 15, 15 } }, 2,
            { ["1"] = { c = 50, m = 0, k = 2, i = { [FISH] = { 35, 35 }, [BLOATED] = { 15, 15 } } } }),
    } }
end)

local Catalog, L = ns.Catalog, ns.L
local ALL = Catalog.DefaultFilter()

local function settle(filter)
    Catalog.Items(filter or ALL)
    advance(0)
end

local function rowOf(itemID, filter)
    for _, row in ipairs((Catalog.Items(filter or ALL))) do
        if row.itemID == itemID then
            return row
        end
    end
end

test("the default filter has bonus \"all\"", function()
    eq(ALL.bonus, "all", "bonus")
    settle()
end)

test("a tagged item's zones take the bonus's numbers, and the order by chance uses them", function()
    local places = Catalog.Places(BLOATED, ALL)
    eq(#places, 3, "three zones")
    eq(places[1].mapID, 3003, "30 % with the bonus first (7.5 % without)")
    near(places[1].chance, 0.3, "the bonus chance")
    eq(places[1].littleData, false, "50 catches under the Rack")
    eq(places[1].catches, 50, "the Rack's catches")
    eq(places[1].players, 2, "the Rack's players")
    eq(places[1].bonus.key, "rack", "the bonus table")
    eq(places[2].mapID, 3001, "then 20 %")
    eq(places[3].mapID, 3002, "the zone without data last")
    eq(places[3].littleData, true, "little data")
    eq(places[3].catches, 0, "0 catches, not nil")
    eq(places[3].players, 0, "0 players, not nil")
    eq(places[3].chance, nil, "no chance")
    eq(Catalog.ChanceText(places[3].chance, places[3].littleData, places[3].players), L["Little data"], "its text")
    eq(Catalog.CatchesText(places[3].catches, places[3].players), (L["%d catches"]):format(0), "its catches text")
end)

test("a list row carries the best place's bonus and players", function()
    local row = rowOf(BLOATED)
    eq(row.bonus.key, "rack", "bonus")
    eq(row.players, 2, "players")
    near(row.chance, 0.3, "chance")
    eq(rowOf(FISH).bonus, nil, "an ordinary fish")
end)

test("a spot row takes the bonus's numbers", function()
    local spots = Catalog.Spots(BLOATED, 3001, ALL)
    eq(#spots, 1, "one spot")
    near(spots[1].chance, 0.2, "the bonus chance")
    eq(spots[1].catches, 50, "catches")
    eq(spots[1].players, 3, "players")
    eq(spots[1].bonus.key, "rack", "bonus")
    local none = Catalog.Spots(BLOATED, 3002, ALL)
    eq(none[1].littleData, true, "no data: little data")
    eq(none[1].catches, 0, "0 catches")
    eq(none[1].players, 0, "0 players")
end)

test("ChanceText with the bonus, and a nil chance", function()
    eq(Catalog.ChanceText(0.0047, false, 3), (L["%s (%d players)"]):format("0.47%", 3), "plain")
    eq(Catalog.ChanceText(0.0047, false, 3, true),
        (L["%s (%d players)"]):format((L["%s with the bonus"]):format("0.47%"), 3), "with the bonus")
    eq(Catalog.ChanceText(0.0047, false, 3, true), "0.47% with the bonus (3 players)", "in English")
    eq(Catalog.ChanceText(nil, true), L["Little data"], "little data")
    eq(Catalog.ChanceText(nil, false), L["Little data"], "no chance")
    eq(Catalog.ChanceText(nil, true, 0, true), L["Little data"], "little data with the bonus")
end)

test("the tag's texts and icon", function()
    eq(Catalog.BonusTag("rack"), L["Fishing Rack bonus"], "Rack tag")
    eq(Catalog.BonusTag("hut"), L["Fishing Hut bonus"], "Hut tag")
    eq(Catalog.BonusTip("rack"), L["Bonus catch: comes only with the buff of a Fishing Rack (Uncommon Fishing)."],
        "Rack tip")
    eq(Catalog.BonusTip("hut"), L["Bonus catch: comes only with the buff of a Fishing Hut (Rare Fishing)."], "Hut tip")
    eq(Catalog.BonusLabel("all"), L["All catches"], "all")
    eq(Catalog.BonusLabel("none"), L["No camp bonus"], "none")
    eq(Catalog.BonusLabel("rack"), L["Fishing Rack"], "rack")
    eq(Catalog.BonusLabel("hut"), L["Fishing Hut"], "hut")
    item_icons[279965] = 777
    eq(Catalog.BonusIcon("rack"), 777, "the Fishing Rack's item icon")
    eq(Catalog.BonusIcon("nothing"), nil, "no bonus")
end)

test("TooltipLines: the bonus form for a tagged place, and the best place's bonus second", function()
    local lines, bonus = Catalog.TooltipLines(BLOATED)
    eq(#lines, 2, "the two zones with enough data")
    eq(lines[1].right, Catalog.ChanceText(0.3, false, 2, true), "the bonus form")
    eq(bonus.key, "rack", "the best place's bonus")
    local _, none = Catalog.TooltipLines(FISH)
    eq(none, nil, "an untagged item")
end)

test("under \"rack\" the view's own numbers; under \"none\" the ordinary ones, plain", function()
    local rack = { range = "all", source = "all", water = "all", bonus = "rack" }
    settle(rack)
    local places = Catalog.Places(BLOATED, rack)
    eq(places[1].mapID, 3003, "the Rack's best zone")
    near(places[1].chance, 0.3, "the view's chance")
    eq(places[1].bonus.key, "rack", "rack")
    local none = { range = "all", source = "all", water = "all", bonus = "none" }
    settle(none)
    local plain = Catalog.Places(BLOATED, none)
    eq(#plain, 1, "only the zone without data has Bloated fish outside the parts")
    eq(plain[1].mapID, 3002, "3002")
    eq(plain[1].bonus.plain, true, "plain")
    eq(plain[1].catches, 20, "the view's ordinary catches")
    eq(rowOf(BLOATED, none), nil, "the list leaves the tagged item out under \"none\" (decision 35)")
    assert(rowOf(FISH, none), "an untagged item stays")
    assert(rowOf(BLOATED), "listed under \"all\"")
end)

test("BonusShown: \"bonusOnly\" keeps tagged rows, \"none\" untagged ones, any other value all", function()
    local tagged, plain = { key = "rack" }, { key = "rack", plain = true }
    eq(Catalog.BonusShown(tagged, "bonusOnly"), true, "bonusOnly: tagged")
    eq(Catalog.BonusShown(plain, "bonusOnly"), false, "bonusOnly: plain")
    eq(Catalog.BonusShown(nil, "bonusOnly"), false, "bonusOnly: untagged")
    eq(Catalog.BonusShown(tagged, "none"), false, "none: tagged")
    eq(Catalog.BonusShown(plain, "none"), false, "none: plain")
    eq(Catalog.BonusShown(nil, "none"), true, "none: untagged")
    eq(Catalog.BonusShown(plain, "rack"), true, "a key: every row")
    eq(Catalog.BonusShown(nil, "all"), true, "all: every row")
end)

test("MinimapLines: a tagged item's chance in the bonus form", function()
    local active = ns.Mode.IsActive
    ns.Mode.IsActive = function() return true end
    local lines = Catalog.MinimapLines()
    local found
    for _, entry in ipairs(lines.items) do
        if entry.name == item_names[BLOATED] then
            found = entry
        end
    end
    assert(found, "the Bloated fish is listed")
    eq(found.right, Catalog.ChanceText(0.2, false, nil, true), "20% with the bonus")
    ns.Mode.IsActive = active
end)

test("best places under Bonus catches only count a tagged item with its chance under the bonus (spec 024)", function()
    item_prices[BLOATED] = 100
    local filter = { range = "all", source = "all", water = "all", bonus = "bonusOnly" }
    ns.BestPlaces.SetSafe(false)
    ns.BestPlaces.Zones(filter)
    flush_timers()
    local spot = ns.BestPlaces.Spots(3001, filter)[1]
    -- 20 % under the Rack (10 % over every cast), 100 copper, 100 catches in 1000 s
    near(spot.goldPerHour, 0.20 * 100 * 3600 * 100 / 1000, "the chance under the bonus")
    item_prices[BLOATED] = nil
end)

test("under Bonus catches only an item without data under its bonus earns nothing (spec 024)", function()
    item_prices[BLOATED] = 100
    local filter = { range = "all", source = "all", water = "all", bonus = "bonusOnly" }
    ns.BestPlaces.Zones(filter)
    flush_timers()
    -- 3002: BLOATED is known to the Rack but was never caught under it here
    local spot = ns.BestPlaces.Spots(3002, filter)[1]
    eq(spot.goldPerHour, 0, "no plain chance stands in for the missing bonus chance")
    item_prices[BLOATED] = nil
end)

test("a tagged item's subzone sums the chances under the bonus and carries the tag with its numbers", function()
    area_names[101] = "Baradin Bay"
    local mine = ns.db.shared.mine
    local function tagged(x)
        return { c = 100, m = 0, t = 1000, px = x * 1000, py = 30000, a = { [101] = 100 },
            i = { [FISH] = { 90, 90 }, [BLOATED] = { 10, 10 } },
            q = { ["1"] = { c = 50, m = 0, i = { [FISH] = { 40, 40 }, [BLOATED] = { 10, 10 } } } } }
    end
    mine["3009:3:11"], mine["3009:3:21"] = tagged(15), tagged(25)
    mine["3009:3:31"] = { c = 800, m = 0, t = 8000, px = 35 * 800, py = 30 * 800, a = { [101] = 800 },
        i = { [FISH] = { 800, 800 } } } -- the same subzone, no bonus, no BLOATED
    area_names[102] = "Menethil Harbor"
    mine["3009:3:51"] = { c = 100, m = 0, t = 1000, px = 55 * 100, py = 3000, a = { [102] = 100 },
        i = { [FISH] = { 99, 99 }, [BLOATED] = { 1, 1 } } } -- another subzone: two groups, none folded away
    ns.Fire("SHARED_DATA_CHANGED")
    local own = { range = "all", source = "mine", water = "all", bonus = "all" }
    Catalog.Items(own)
    flush_timers()
    local group
    for _, element in ipairs(Catalog.SpotGroups(BLOATED, 3009, own)) do
        group = group or (element.spots and element)
    end
    assert(group, "one group of the two tagged spots")
    near(group.chance, group.spots[1].chance, "the chance under the bonus, as its spots")
    eq(group.bonus.key, group.spots[1].bonus.key, "the spots' tag")
    eq(group.bonus.chance, group.chance, "the tooltip's chance is the group's")
    eq(group.bonus.players, group.players, "and its players")
    -- one more spot of the same subzone that caught BLOATED without the bonus: BLOATED is a bonus item there too
    -- (no data under the bonus), so it adds no catch under the bonus and the group's chance stays its tagged spots'
    mine["3009:3:41"] = { c = 100, m = 0, t = 1000, px = 45 * 100, py = 3000, a = { [101] = 100 },
        i = { [FISH] = { 90, 90 }, [BLOATED] = { 10, 10 } } }
    ns.Fire("SHARED_DATA_CHANGED")
    Catalog.Items(own)
    flush_timers()
    local whole
    for _, element in ipairs(Catalog.SpotGroups(BLOATED, 3009, own)) do
        whole = whole or (element.spots and element)
    end
    eq(#whole.spots, 3, "three spots")
    near(whole.chance, group.chance, "the chance under the bonus, not blended with a plain one")
end)

test("under Bonus catches only a place whose numbers under the bonus are little data is not ranked", function()
    local mine = ns.db.shared.mine
    item_prices[BLOATED] = 100
    -- 2000 ordinary catches, 3 casts under the Rack, one BLOATED
    mine["3010:3:11"] = { c = 2000, m = 0, t = 20000, px = 1500 * 2000, py = 0, i = { [FISH] = { 2000, 2000 } },
        q = { ["1"] = { c = 3, m = 0, i = { [BLOATED] = { 1, 1 }, [FISH] = { 2, 2 } } } } }
    ns.Fire("SHARED_DATA_CHANGED")
    local filter = { range = "all", source = "mine", water = "all", bonus = "bonusOnly" }
    ns.BestPlaces.Zones(filter)
    flush_timers()
    for _, zone in ipairs(ns.BestPlaces.Zones(filter)) do
        assert(zone.mapID ~= 3010, "three casts under the bonus carry no zone into the top 10")
    end
    item_prices[BLOATED] = nil
end)

test("under Bonus catches only a group of spots without reliable bonus numbers is little data too", function()
    local mine = ns.db.shared.mine
    item_prices[BLOATED] = 100
    area_names[103] = "Bay"
    for n, x in ipairs({ 15, 25, 35 }) do
        mine["3011:3:" .. n .. "1"] = { c = 20, m = 0, t = 200, px = x * 200, py = 0, a = { [103] = 20 },
            i = { [FISH] = { 20, 20 } },
            q = { ["1"] = { c = 2, m = 0, i = { [BLOATED] = { 1, 1 }, [FISH] = { 1, 1 } } } } }
    end
    mine["3011:3:91"] = { c = 20, m = 0, t = 200, px = 95 * 200, py = 0, i = { [FISH] = { 20, 20 } } } -- elsewhere
    ns.Fire("SHARED_DATA_CHANGED")
    local filter = { range = "all", source = "mine", water = "all", bonus = "bonusOnly" }
    local group
    for _, element in ipairs(ns.BestPlaces.Spots(3011, filter)) do
        group = group or (element.spots and element)
    end
    assert(group, "the three spots of the Bay")
    eq(group.catches >= 50, true, "60 catches in all")
    eq(group.littleData, true, "but no reliable number under the bonus")
    item_prices[BLOATED] = nil
end)
