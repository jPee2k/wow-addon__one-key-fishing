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
