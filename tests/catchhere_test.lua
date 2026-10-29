-- UI/CatchHere.lua ("What can be caught here") and the tabs of UI/StatsFrame.lua.
-- The tests run in order and share one login: each starts where the previous ended.

local FISH = 6291

player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
load_addon()

local L = ns.L

local cast = fish_cast

ns.StatsFrame.Toggle()
local window = _G.OneKeyFishingStatsFrame
local here = window.herePage

test("two tabs below the window, the statistics first", function()
    assert(find_frame(L["Statistics"], window), "Statistics tab")
    assert(find_frame(L["What can be caught here"], window), "What can be caught here tab")
    eq(window.usesPanelTabs, true, "the game's panel tabs")
    assert(window.statsPage:IsShown(), "statistics page shown")
    assert(not here:IsShown(), "the other page hidden")
end)

test("the second tab shows the page and is remembered", function()
    click(L["What can be caught here"], window)
    assert(here:IsShown(), "page shown")
    assert(not window.statsPage:IsShown(), "statistics hidden")
    eq(ns.db.statsTab, "here", "saved")
end)

test("nothing caught yet", function()
    eq(here.message.text, L["Nothing has been caught here yet."], "empty text")
end)

test("the filters start at the own skill range and all sources", function()
    eq(here.skillButton.text, (L["Skill: %s"]):format("225-299"), "skill filter")
    eq(here.sourceButton.text, (L["Source: %s"]):format(L["All"]), "source filter")
end)

test("without a bundled seed the page says so", function()
    assert(here.hint.text:find(L["No bundled data in this version: only your own catches are shown."], 1, true),
        here.hint.text)
end)

test("60 own catches at the spot: chances in percent", function()
    for _ = 1, 60 do
        cast({ { FISH, 1 } })
    end
    cast(nil)
    tick(window)
    eq(here.counts.text:sub(1, #"60 catches"), (L["%d catches"]):format(60), "catches")
    assert(here.counts.text:find("2%", 1, true), "1 miss of 61 casts: " .. here.counts.text)
    eq(here.rows[1].chance.text, "100%", "chance")
    eq(here.rows[1].pieces.text, "1.0", "pieces per catch")
    eq(here.scope.text, "", "the spot's own numbers")
    assert(not here.rows[2]:IsShown(), "one item")
end)

test("a spot with few catches shows the whole map", function()
    player_map_position = { 0.15, 0.15 }
    for _ = 1, 20 do
        cast({ { FISH, 1 } })
    end
    tick(window)
    eq(here.scope.text, L["Numbers for the whole map: few catches at this spot."], "scope")
    eq(here.counts.text:sub(1, #"80 catches"), (L["%d catches"]):format(80), "the map's catches")
end)

test("the page follows the player", function()
    player_map_position = { 0.43, 0.78 }
    tick(window)
    eq(here.scope.text, "", "back at the spot with enough catches")
end)

test("the skill filter follows the rank until a range is picked by hand", function()
    fishing_rank = 300
    tick(window)
    eq(here.skillButton.text, (L["Skill: %s"]):format("225-299"), "the range is read again only on a skill event")
    fire("SKILL_LINES_CHANGED")
    tick(window)
    eq(here.skillButton.text, (L["Skill: %s"]):format("300+"), "follows the new range")
    eq(here.message.text, L["Nothing has been caught here yet."], "nothing in range 4 yet")
    ns.CatchHere.SetRange("all")
    eq(here.skillButton.text, (L["Skill: %s"]):format(L["All skill levels"]), "picked by hand")
    eq(here.counts.text:sub(1, #"60 catches"), (L["%d catches"]):format(60), "all ranges")
    fishing_rank = 230
    fire("SKILL_LINES_CHANGED")
    tick(window)
    eq(here.skillButton.text, (L["Skill: %s"]):format(L["All skill levels"]), "a hand-picked range stays")
end)

test("little data in a picked range suggests all skill levels", function()
    ns.CatchHere.SetRange(1)
    eq(here.message.text, L["Nothing has been caught here yet."], "nothing in range 1")
    fishing_rank = 100
    cast({ { FISH, 1 } })
    ns.CatchHere.SetRange(1)
    eq(here.rows[1].chance.text, L["Little data"], "no percentage")
    assert(here.hint.text:find(L["Try \"All skill levels\": little data for your skill."], 1, true), here.hint.text)
    fishing_rank = 230
    ns.CatchHere.SetRange(3)
end)

test("turning auction prices off redraws the prices", function()
    ns.db.prices[FISH] = { price = 5000, quantity = 100, time = 1 }
    ns.Fire("PRICES_CHANGED")
    tick(window)
    eq(here.rows[1].price.text, "5000c", "auction price")
    ns.db.settings.auctionPrices = false
    ns.Fire("SETTINGS_CHANGED")
    tick(window)
    eq(here.rows[1].price.text, "0c", "vendor price (none in the test)")
    ns.db.settings.auctionPrices = true
    ns.db.prices[FISH] = nil
    ns.Fire("SETTINGS_CHANGED")
end)

test("the source filter", function()
    ns.CatchHere.SetSource("mine")
    eq(here.sourceButton.text, (L["Source: %s"]):format(L["Only mine"]), "only mine")
    eq(here.counts.text:sub(1, #"60 catches"), (L["%d catches"]):format(60), "own catches")
    assert(not here.hint.text:find(L["No bundled data in this version: only your own catches are shown."], 1, true),
        "no seed note for own catches")
    ns.CatchHere.SetSource("all")
end)

test("the statistics tab is unchanged", function()
    click(L["Statistics"], window)
    assert(window.statsPage:IsShown(), "statistics shown")
    assert(not here:IsShown(), "page hidden")
    eq(ns.db.statsTab, "stats", "saved")
    eq(window.cells.catches[3].text, "81", "all-time catches: 60 + 20 + 1")
end)

test("without a map the page says so", function()
    click(L["What can be caught here"], window)
    player_map_id = nil
    fire("ZONE_CHANGED_NEW_AREA")
    tick(window)
    eq(here.place.text, L["The game does not show this place on the map."], "message")
    player_map_id = 1415
    fire("ZONE_CHANGED_NEW_AREA")
    tick(window)
    eq(here.place.text, "Test Zone", "back on the map")
end)
