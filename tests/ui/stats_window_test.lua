-- The statistics window: what is redrawn when, and how values are shown.
-- The tests are the steps of one fishing session and run in order: each one starts where the previous ended.

local FISH = 6303
item_prices[FISH] = 5 -- vendor price

load_addon()

-- Row keys of UI/StatsFrame.lua ROWS; columns: 1 session, 2 this zone, 3 all time.
local TIME_FISHING, CASTS, CATCHES, MISSES = "timeFishing", "casts", "catches", "misses"
local CATCHES_PER_HOUR, VALUE, GOLD_PER_HOUR = "catchesPerHour", "value", "goldPerHour"

-- Fishing mode on, one cast that brings two fish worth 50c each at the auction house.
ns.Mode.IsActive = function() return true end
ns.Fire("MODE_CHANGED", true)
ns.Fire("FISHING_CAST_START", 7620)
loot = { fishing = true, items = { { FISH, 2 } } }
fire("LOOT_READY")
loot = nil
ns.db.prices[FISH] = { price = 50, time = os.time({ year = 2026, month = 10, day = 23, hour = 14, min = 5 }) }

ns.StatsFrame.Toggle()
local window = _G.OneKeyFishingStatsFrame

local function cell(row, column)
    return window.cells[row][column or 1].text
end

test("opening the window fills the table", function()
    assert(window:IsShown(), "window shown")
    eq(cell(CASTS), "1", "casts")
    eq(cell(CATCHES), "1", "catches")
    eq(cell(VALUE), "100c", "value: the auction price beats the vendor price")
    eq(cell(TIME_FISHING), "0:00:00", "session time")
    eq(cell(TIME_FISHING, 2), "0m", "zone time")
    eq(cell(TIME_FISHING, 3), "0m", "all-time time")
end)

test("one catch in the zone list reads '1 catch' (spec 010 US5)", function()
    eq(window.zoneLines[1].detail.text, (ns.L["1 catch, %s"]):format("0m"), "singular")
end)

test("the prices line shows the scan date", function()
    assert(window.prices.text:find("2026-10-23 14:05", 1, true), window.prices.text)
end)

test("while fishing only the time rows tick", function()
    local rate = cell(CATCHES_PER_HOUR)
    advance(3725)
    tick(window)
    eq(cell(TIME_FISHING), "1:02:05", "session time with seconds")
    eq(cell(TIME_FISHING, 2), "1h 02m", "zone time in hours and minutes")
    eq(cell(TIME_FISHING, 3), "1h 02m", "all-time time")
    eq(cell(CATCHES_PER_HOUR), rate, "rate unchanged")
end)

test("a new cast shows up on the next tick, with the rates", function()
    ns.Fire("FISHING_CAST_STOP")
    ns.Fire("FISHING_CAST_START", 7620)
    eq(cell(CASTS), "1", "not before the tick")
    tick(window)
    eq(cell(CASTS), "2", "casts")
    eq(cell(CATCHES_PER_HOUR), "1.0", "1 catch in 1:02:05")
end)

test("a cast without loot counts as a miss a moment after it ends", function()
    ns.Fire("FISHING_CAST_STOP")
    advance(2) -- Catch.lua waits for late loot first
    tick(window)
    eq(cell(MISSES), "1", "nothing caught")
end)

test("Refresh recomputes the rates with the current time", function()
    advance(3600)
    tick(window)
    eq(cell(CATCHES_PER_HOUR), "1.0", "unchanged by the tick")
    click(ns.L["Refresh"], window)
    eq(cell(CATCHES_PER_HOUR), "0.5", "1 catch in 2:02:05")
    eq(cell(GOLD_PER_HOUR), "49c", "100c in 2:02:05")
end)

test("the rate uses the game client's decimal separator, whatever the interface language", function()
    DECIMAL_SEPERATOR = ","
    click(ns.L["Refresh"], window)
    eq(ns.language, "enUS", "English interface")
    eq(cell(CATCHES_PER_HOUR), "0,5", "the client's separator")
    DECIMAL_SEPERATOR = "."
    click(ns.L["Refresh"], window)
    eq(cell(CATCHES_PER_HOUR), "0.5", "back to the point")
end)

test("Reset session redraws at once", function()
    click(ns.L["Reset session"], window)
    accept_popup()
    eq(cell(CASTS), "0", "session casts")
    eq(cell(CASTS, 3), "2", "all-time casts kept")
end)

test("short time format", function()
    local format = ns.Stats.FormatShortTime
    eq(format(59), "0m")
    eq(format(3725), "1h 02m")
    eq(format(1123300), "312h 01m")
end)

---------------------------------------------------------------------------
-- The bottom buttons (spec 007, User Story 5): a Scan button that does not fit wraps to the left of a new row.
---------------------------------------------------------------------------

test("button rows: everything fits in one row", function()
    local width, wraps = ns.StatsFrame.ButtonRows(394, 160, 580)
    eq(width, 580, "window width")
    eq(wraps, false, "one row")
end)

test("button rows: the window widens for the left buttons, Scan wraps", function()
    local width, wraps = ns.StatsFrame.ButtonRows(700, 200, 580)
    eq(width, 700, "window width")
    eq(wraps, true, "two rows")
end)

test("button rows: the left buttons fit, Scan does not", function()
    local width, wraps = ns.StatsFrame.ButtonRows(560, 160, 580)
    eq(width, 580, "window width")
    eq(wraps, true, "two rows")
end)

-- Auctionator as the price source (specs/019-auctionator-prices, User Stories 1 and 4). The stub is set after
-- load_addon(): its presence is read at runtime. That its update notice becomes PRICES_CHANGED is proven in
-- tests/catch/prices_update_test.lua; here the window follows PRICES_CHANGED.
local OTHER = 6291
local auctionator = { prices = {} }
auctionator.API = { v1 = {
    GetAuctionPriceByItemID = function(_, itemID) return auctionator.prices[itemID] end,
    RegisterForDBUpdate = function() end,
} }
local FROM_AUCTIONATOR = ns.L["Values: higher of vendor and Auctionator price."]

local function redraw()
    ns.Fire("PRICES_CHANGED")
    tick(window)
end

test("with Auctionator its price gives the values, and a change shows without a reload", function()
    local owned = ns.Stats.GetTotal().items[FISH]
    Auctionator = auctionator
    auctionator.prices[FISH] = 80
    redraw()
    eq(cell(VALUE, 3), ns.FormatMoney(owned * 80), "the all-time value at Auctionator's price")
    auctionator.prices[FISH] = 200
    redraw()
    eq(cell(VALUE, 3), ns.FormatMoney(owned * 200), "the new price after its notice")
    eq(ns.db.prices[FISH].price, 50, "the addon's own price is untouched")
end)

test("the values line names Auctionator; catches without its price are counted with the advice", function()
    eq(window.prices.text, FROM_AUCTIONATOR, "every own catch has its price: no count")
    ns.Stats.GetTotal().items[OTHER] = 1
    chat = {}
    redraw()
    eq(window.prices.text, FROM_AUCTIONATOR .. " " ..
        (ns.L["%d of your catches have no Auctionator price: run its scan."]):format(1), "one catch without it")
    eq(window.prices.text:find("price. 1 of", 1, true) ~= nil, true, "two sentences, the first with its full stop")
    eq(window.nextRank:GetMaxLines(), 2, "the values line may take two lines: the next-rank line keeps two")
    eq(#chat, 0, "nothing in chat")
    auctionator.prices[OTHER] = 30
    redraw()
    eq(window.prices.text, FROM_AUCTIONATOR, "the advice goes once Auctionator priced it")
    item_quality[OTHER] = 0
    auctionator.prices[OTHER] = nil
    redraw()
    eq(window.prices.text, FROM_AUCTIONATOR, "grey junk without its price gives no advice")
    item_quality[OTHER] = nil
    eq(window.nextRank:GetMaxLines(), 3, "one values line: the next-rank line has its three again")
    ns.Stats.GetTotal().items[OTHER] = nil
end)

test("with the Auctionator switch off the line is the addon's own again", function()
    ns.Prices.SetAuctionator(false)
    tick(window)
    eq(window.prices.text, (ns.L["Values: higher of vendor and auction price (scanned %s)"]):format(
        date("%Y-%m-%d %H:%M", ns.Prices.GetLastScanTime())), "the scan's line")
    ns.Prices.SetAuctionator(true)
end)

test("the values line wraps inside the window, as wide as the next-rank line (spec 019 review)", function()
    local width = window.prices:GetWidth()
    assert(width and width > 0, "a width, so the line wraps instead of running past the window's edge")
    eq(width, window.nextRank:GetWidth(), "as wide as the next-rank line, clear of the Pin button")
end)

-- The camp bonus rows (specs/020-camp-buffs FR-035, research R12): the last two rows of "Results", shown in the three
-- columns once the total has a bonus cast, their place kept while hidden; the window two lines taller.
test("the camp bonus rows: hidden without a bonus cast, shown in three columns with one", function()
    local L = ns.L
    eq(window.cells.bonusCasts ~= nil, true, "the row exists")
    local parts = window.rowParts
    assert(not parts.bonusCasts.label:IsShown(), "hidden without a bonus cast")
    assert(not window.cells.bonusCatches[3]:IsShown(), "its cells too")
    eq(parts.bonusCasts.label.text, L["Casts with a camp bonus"], "the label")
    eq(parts.bonusCatches.label.text, L["Bonus catches"], "the label")
    auras[1280341] = { expirationTime = GetTime() + 3000, duration = 3600 }
    fire("UNIT_AURA", "player")
    fish_cast({ { FISH, 1 } })
    ns.StatsFrame.Refresh()
    assert(parts.bonusCasts.label:IsShown(), "shown")
    assert(parts.bonusCatches.label:IsShown(), "bonus catches shown")
    eq(cell("bonusCasts", 1), "1", "session")
    eq(cell("bonusCasts", 2), "1", "this zone")
    eq(cell("bonusCasts", 3), "1", "all time")
    eq(cell("bonusCatches", 3), "0", "0 bonus catches")
    auras[1280341] = nil
    fire("UNIT_AURA", "player")
end)

test("the camp bonus rows end the Results block; the window is 736 high, Top catches two lines lower", function()
    eq(window:GetHeight(), 736, "the height")
    local function y(frame)
        return anchor(frame, "TOPLEFT")[3]
    end
    local parts = window.rowParts
    eq(y(parts.bonusCasts.label), y(parts.catchesPerHour.label) - 18, "after Catches per hour")
    eq(y(parts.bonusCatches.label), y(parts.bonusCasts.label) - 18, "then Bonus catches")
    eq(y(window.itemsHeader), -360 - 36, "Top catches two lines lower than in 1.4.0 (-360)")
end)
