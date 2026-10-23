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
