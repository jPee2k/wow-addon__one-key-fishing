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

-- Spec 012 US2: with another player's catches behind the numbers, the page no longer claims to show only the own
-- catches; a record of another place leaves the claim true.
test("without a seed but with another player's catches here, the hint names only the missing bundled data", function()
    local LONG = L["No bundled data in this version: only your own catches are shown."]
    local SHORT = L["No bundled data in this version."]
    local id = "o0000001"
    local function Record(key)
        ns.db.shared.records[id .. "@0"] = { id = id, epoch = 0, seq = 1, seen = 1, proof = ("a"):rep(16),
            builds = { ["1.60.1"] = { [key] = catch_cell(5, 0, { [FISH] = { 5, 5 } }) } } }
        ns.Fire("SHARED_DATA_CHANGED")
        tick(window)
    end
    Record("1413:3:47") -- another map
    assert(here.hint.text:find(LONG, 1, true), "another place: the full line: " .. here.hint.text)
    Record("1415:3:47")
    assert(here.hint.text:find(SHORT, 1, true), here.hint.text)
    -- Only the other player's catches, on a map the player never fished: not "only your own" either.
    player_map_id = 1413
    fire("ZONE_CHANGED_NEW_AREA")
    Record("1413:3:47")
    assert(here.hint.text:find(SHORT, 1, true), "another player only: " .. here.hint.text)
    player_map_id = 1415
    fire("ZONE_CHANGED_NEW_AREA")
    Record("1415:3:47")
    assert(not here.hint.text:find(LONG, 1, true), "no 'only your own catches': " .. here.hint.text)
    -- The setting itself, not Share.SetEnabled: that would also close the exchange notice a later test reads.
    ns.db.settings.shareDB = false
    ns.Fire("SHARED_DATA_CHANGED")
    tick(window)
    assert(here.hint.text:find(LONG, 1, true), "sharing off: the full line: " .. here.hint.text)
    ns.db.settings.shareDB = true
    ns.db.shared.records[id .. "@0"] = nil
    ns.Fire("SHARED_DATA_CHANGED")
    tick(window)
    assert(here.hint.text:find(LONG, 1, true), "the full line again: " .. here.hint.text)
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

test("another player's record arriving shows on the next tick: N catches from 2 players", function()
    ns.CatchHere.SetRange(3)
    tick(window)
    eq(here.counts.text:sub(1, #"60 catches  "), (L["%d catches"]):format(60) .. "  ", "own catches only")
    local other = prove({ id = "qqqqqqqq", epoch = 0, seq = 2,
        builds = { ["1.60.1"] = { ["1415:3:47"] = catch_cell(30, 0, { [FISH] = { 30, 30 } }) } } })
    eq(ns.Share.Store.Accept(ns.db.shared, other), "new", "stored")
    tick(window)
    local expected = (L["%d catches from %d players"]):format(90, 2)
    eq(here.counts.text:sub(1, #expected), expected, "counts with the other player")
    ns.CatchHere.SetSource("mine")
    eq(here.counts.text:sub(1, #"60 catches  "), (L["%d catches"]):format(60) .. "  ", "Only mine")
    ns.CatchHere.SetSource("all")
end)

test("the status line of the exchange shows under the counts and follows the state on the tick", function()
    eq(here.status.text, ns.Share.StatusLine(), "status line")
    eq(here.status.text, L["Waiting for you to read the notice"], "the notice is still open")
    local version = ns.CatchDB.GetVersion()
    ns.db.shareNotice = true
    tick(window)
    eq(ns.CatchDB.GetVersion(), version, "the data did not change")
    eq(here.status.text, L["Nobody to exchange with right now"], "updated without reopening")
end)

---------------------------------------------------------------------------
-- Items the game client does not know yet (specs/004-public-channel-sync, FR-017a)
---------------------------------------------------------------------------
local function rowOf(itemID)
    for _, row in ipairs(here.rows) do
        if row:IsShown() and row.itemID == itemID then
            return row
        end
    end
end

test("an item the client does not know shows as an Unknown item row with its ID in the tooltip", function()
    unknown_items[88888] = true
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {},
        cells = { ["1415:3:47"] = { c = 40, m = 0, t = 400, k = 2,
            i = { [88888] = { 10, 10 }, [FISH] = { 30, 30 } } } } }
    ns.Fire("SHARED_DATA_CHANGED")
    tick(window)
    local row = assert(rowOf(88888), "a row for the unknown item")
    eq(row.name.text, L["Unknown item"], "its name")
    eq(row.icon.texture, 134400, "the question mark")
    eq(row.price.text, "", "no price")
    eq(item_load_requests[#item_load_requests], 88888, "the game is asked once")
    local asked = #item_load_requests
    ns.Fire("SHARED_DATA_CHANGED")
    tick(window)
    eq(#item_load_requests, asked, "not asked again this session")
    row = rowOf(88888)
    row.scripts.OnEnter(row)
    eq(tooltip_lines[1], L["Unknown item"], "tooltip title")
    eq(tooltip_lines[2], L["The game has not shown this item yet."], "why")
    eq(tooltip_lines[3], L["In the bundled data"], "from the seed")
    eq(tooltip_lines[4], (L["Item ID: %d"]):format(88888), "the item ID")
end)

test("reported by other players, the tooltip counts them; once the game knows the item, the row is a normal one",
    function()
    for i = 1, 3 do
        local id = ("r%07d"):format(i)
        ns.db.shared.records[id .. "@0"] = { id = id, epoch = 0, seq = 1, seen = 1, proof = ("a"):rep(16),
            builds = { ["1.60.1"] = { ["1415:3:47"] = catch_cell(10, 0, { [77777] = { 10, 10 } }) } } }
    end
    unknown_items[77777] = true
    ns.Fire("SHARED_DATA_CHANGED")
    tick(window)
    local row = assert(rowOf(77777), "three reports: listed")
    row.scripts.OnEnter(row)
    eq(tooltip_lines[3], (L["Reported by %d players on this map"]):format(3), "three players")
    item_loaded(88888, true)
    tick(window)
    row = rowOf(88888)
    assert(row.name.text ~= L["Unknown item"], "the game knows it now: " .. tostring(row.name.text))
    row.scripts.OnEnter(row)
    eq(tooltip_item, 88888, "the game's own item tooltip")
    unknown_items[77777] = nil
    ns.SeedData = nil
    ns.Fire("SHARED_DATA_CHANGED")
end)

---------------------------------------------------------------------------
-- The way into the catch catalog (specs/005-catch-catalog, FR-024)
---------------------------------------------------------------------------
test("a click on a known item opens the catalog on it; an Unknown item row does nothing", function()
    click(L["What can be caught here"], window)
    ns.CatchHere.SetRange("all")
    assert(here.hint.text:find(L["Click an item to see where else it is caught."], 1, true), here.hint.text)
    unknown_items[88888] = true
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {},
        cells = { ["1415:3:47"] = { c = 40, m = 0, t = 400, k = 2, i = { [88888] = { 10, 10 } } } } }
    ns.Fire("SHARED_DATA_CHANGED")
    tick(window)
    local unknown = rowOf(88888)
    unknown.scripts.OnMouseUp(unknown, "LeftButton")
    assert(here:IsShown(), "still here")
    local row = assert(rowOf(FISH), "a known row")
    row.scripts.OnMouseUp(row, "LeftButton")
    assert(window.catalogPage:IsShown(), "the catalog")
    eq(ns.db.statsTab, "catalog", "its tab")
    assert(window.catalogPage.itemView:IsShown(), "the item page")
    eq(window.catalogPage.title.text, select(1, ns.ItemDisplay(FISH)), "the item chosen")
    unknown_items[88888] = nil
    ns.SeedData = nil
    ns.Fire("SHARED_DATA_CHANGED")
end)

---------------------------------------------------------------------------
-- The Water filter (specs/005-catch-catalog, US4)
---------------------------------------------------------------------------
test("with pool data the Water button shows; under Pools the pool numbers without the miss line", function()
    click(L["What can be caught here"], window)
    ns.CatchHere.SetRange(3)
    assert(not here.waterButton:IsShown(), "no pool data yet")
    local cell = catch_cell(80, 20, { [FISH] = { 80, 80 } })
    cell.k, cell.p = 2, { c = 60, i = { [FISH] = { 60, 60 } } }
    ns.SeedData = { epoch = 1, absorbed = {}, resets = {}, cells = { ["1415:3:47"] = cell } }
    ns.Fire("SHARED_DATA_CHANGED")
    tick(window)
    assert(here.waterButton:IsShown(), "shown")
    eq(here.waterButton.text, (L["Water: %s"]):format(L["Everywhere"]), "the default")
    assert(here.counts.text:find((L["Nothing caught: %s"]):format(""), 1, true), "the miss line everywhere")
    ns.CatchHere.SetWater("pool")
    eq(here.waterButton.text, (L["Water: %s"]):format(L["Pools"]), "pools")
    eq(here.counts.text, (L["%d catches from %d players"]):format(60, 2), "the seed's pool catches only, no miss line")
    ns.CatchHere.SetWater("open")
    eq(here.waterButton.text, (L["Water: %s"]):format(L["Open water"]), "open water")
    ns.CatchHere.SetWater("all")
    ns.SeedData = nil
    ns.Fire("SHARED_DATA_CHANGED")
end)
