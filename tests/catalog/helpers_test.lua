-- Catalog.lua: the texts and the state the tab and the tooltips share (ChanceText, AreaName, State).

load_addon()

test("ChanceText is a percent, or Little data, with the players from 2 on", function()
    eq(ns.Catalog.ChanceText(0.456, false), "46%", "percent")
    eq(ns.Catalog.ChanceText(0.456, true), ns.L["Little data"], "little data")
    eq(ns.Catalog.ChanceText(0.456, false, 1), "46%", "one player is no suffix")
    eq(ns.Catalog.ChanceText(0.456, false, 3), (ns.L["%s (%d players)"]):format("46%", 3), "three players")
end)

test("AreaName is the area's name, or nil without a known one", function()
    area_names[77] = "Crystal Lake"
    eq(ns.Catalog.AreaName({ area = 77 }), "Crystal Lake", "known")
    eq(ns.Catalog.AreaName({ area = 78 }), nil, "no name")
    eq(ns.Catalog.AreaName({}), nil, "no area")
end)

test("State follows the index: building before a complete one, ready after", function()
    local filter = { range = "all", source = "all", water = "all" }
    local state = ns.Catalog.State(filter)
    assert(state == "building" or state == "ready", "a state")
    advance(0)
    eq(ns.Catalog.State(filter), "ready", "ready")
    local _, itemsState = ns.Catalog.Items(filter)
    eq(itemsState, ns.Catalog.State(filter), "the same as Items reports")
end)
