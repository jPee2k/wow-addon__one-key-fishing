-- UI/Settings.lua: the "Auction prices" page (specs/019-auctionator-prices, User Story 3, FR-015 to FR-018): the
-- auction price switch moved here, the nested Auctionator switch, the source in use and the counts of the own
-- catches. The addon is loaded without Auctionator; the stub is set afterwards (its presence is read at runtime).

local PRICED, UNPRICED = 6291, 6303
item_prices[UNPRICED] = 10

load_addon()

local L = ns.L
local Prices = ns.Prices
local MAIN, NESTED = L["Use scanned auction prices for catch value"], L["Take prices from Auctionator"]
local NOT_INSTALLED = L["Auctionator is not installed."]
local FAILED = L["Auctionator failed this session: the addon's own scan is in use."]
local FROM_AUCTIONATOR = L["Prices come from Auctionator."]
local OFF = L["Auction prices are off: catch values use vendor prices."]
local page = settings_pages[L["Auction prices"]]

ns.Stats.GetTotal().items[PRICED] = 2
ns.Stats.GetTotal().items[UNPRICED] = 5

local function reopen()
    page:Hide()
    page:Show()
end

local function checkbox_of(text)
    return assert(find_frame(text, page), "the label " .. text).parent
end

local function shows(text)
    local line = find_frame(text, page)
    return line ~= nil and line:IsShown()
end

local function counts_text()
    local c = Prices.CountSources()
    return (L["Your catches: %d priced by Auctionator, %d by the addon's scan, %d at vendor price, " ..
        "%d without a price."]):format(c.auctionator, c.own, c.vendor, c.none)
end

local function click(box, checked)
    box:SetChecked(checked)
    box.scripts.OnClick(box)
end

test("the page holds the auction price switch, which left the main page; it has no button", function()
    assert(page, "registered as a subcategory")
    reopen()
    eq(checkbox_of(MAIN):GetChecked(), true, "on by default")
    eq(find_frame(MAIN, settings_pages["OneKeyFishing"]), nil, "no longer on the main page")
    eq(find_frame(L["Scan auction prices"], page), nil, "no scan button")
    eq(find_frame(L["Scan fish prices"], page), nil, "nor the auction window's")
end)

test("without Auctionator: its switch is inactive with a note, the source is the addon's own scan", function()
    reopen()
    eq(checkbox_of(NESTED):IsEnabled(), false, "inactive")
    eq(shows(NOT_INSTALLED), true, "the note")
    eq(shows(L["Prices come from the addon's own scan (no scan yet)."]), true, "no scan yet")
    eq(shows(counts_text()), true, "the counts")
    ns.db.prices[PRICED] = { price = 300, quantity = 20, lots = 5, time = 1700000000 }
    reopen()
    eq(shows((L["Prices come from the addon's own scan (last scan %s)."]):format(
        date("%Y-%m-%d %H:%M", 1700000000))), true, "the last scan's time")
    eq(shows(counts_text()), true, "the counts follow")
    ns.db.prices[PRICED] = nil
end)

local stub = { prices = { [PRICED] = 500 } }
stub.API = { v1 = {
    GetAuctionPriceByItemID = function(_, itemID) return stub.prices[itemID] end,
    RegisterForDBUpdate = function() end,
} }

test("with Auctionator: both switches usable, the source and the four counts", function()
    Auctionator = stub
    reopen()
    eq(checkbox_of(NESTED):IsEnabled(), true, "usable")
    eq(checkbox_of(NESTED):GetChecked(), true, "on by default")
    eq(shows(NOT_INSTALLED), false, "no note")
    eq(shows(FROM_AUCTIONATOR), true, "the source")
    local c = Prices.CountSources()
    eq(c.auctionator .. " " .. c.own .. " " .. c.vendor .. " " .. c.none, "1 0 1 0", "the counts themselves")
    eq(shows(counts_text()), true, "the counts line")
end)

test("the page redraws while shown when the prices change", function()
    stub.prices[UNPRICED] = 700
    ns.Fire("PRICES_CHANGED")
    eq(Prices.CountSources().auctionator, 2, "two priced now")
    eq(shows(counts_text()), true, "the counts line follows")
    stub.prices[UNPRICED] = nil
    ns.Fire("PRICES_CHANGED")
end)

test("the auction price switch off: the Auctionator switch is inactive, values are vendor prices", function()
    local changed
    ns.On("SETTINGS_CHANGED", function(key) changed = key end)
    click(checkbox_of(MAIN), false)
    eq(ns.db.settings.auctionPrices, false, "written")
    eq(changed, "auctionPrices", "through the setter: SETTINGS_CHANGED")
    eq(checkbox_of(NESTED):IsEnabled(), false, "inactive")
    eq(shows(NOT_INSTALLED), false, "no note: Auctionator is there")
    eq(shows(OFF), true, "the source line")
    click(checkbox_of(MAIN), true)
    eq(checkbox_of(NESTED):IsEnabled(), true, "usable again")
    eq(shows(FROM_AUCTIONATOR), true, "the source again")
end)

test("the Auctionator switch off: the addon's own scan is the source", function()
    local changed
    ns.On("SETTINGS_CHANGED", function(key) changed = key end)
    click(checkbox_of(NESTED), false)
    eq(ns.db.settings.auctionatorPrices, false, "written")
    eq(changed, "auctionatorPrices", "through the setter: SETTINGS_CHANGED")
    eq(shows(L["Prices come from the addon's own scan (no scan yet)."]), true, "the source line")
    eq(checkbox_of(NESTED):IsEnabled(), true, "still usable")
    click(checkbox_of(NESTED), true)
    eq(shows(FROM_AUCTIONATOR), true, "back")
end)

test("after a failing call the page says that Auctionator failed, not that it is not installed", function()
    stub.API.v1.GetAuctionPriceByItemID = function() error("broken") end
    Prices.Get(PRICED)
    eq(#take_errors(), 1, "the failure, handed on once")
    advance(0.1) -- its PRICES_CHANGED, which the shown page follows
    eq(checkbox_of(NESTED):IsEnabled(), false, "inactive")
    eq(shows(FAILED), true, "the failure note")
    eq(shows(NOT_INSTALLED), false, "not the other note")
    eq(shows(L["Prices come from the addon's own scan (no scan yet)."]), true, "the own scan is the source")
end)
