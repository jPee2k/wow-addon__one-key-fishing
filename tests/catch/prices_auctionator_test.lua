-- Prices.lua: Auctionator as a second source of auction prices (specs/019-auctionator-prices). The addon is loaded
-- without Auctionator; the stubs are set afterwards, since its presence is checked at runtime.

local FISH, CHEAP, OWN, FEW, NONE = 6291, 6303, 13926, 6522, 7974
item_prices[FISH] = 100 -- vendor prices
item_prices[CHEAP] = 100
item_prices[OWN] = 100
item_prices[FEW] = 100

load_addon()

local Prices = ns.Prices

-- A stand-in for Auctionator's public API: `prices` and `ages` by item ID, the calls counted.
local function Stub(prices, ages)
    local stub = { prices = prices or {}, ages = ages or {}, priceCalls = 0, registered = 0 }
    stub.API = { v1 = {
        GetAuctionPriceByItemID = function(callerID, itemID)
            stub.priceCalls = stub.priceCalls + 1
            assert(callerID == "OneKeyFishing", "the caller's name")
            assert(type(itemID) == "number", "an item ID")
            return stub.prices[itemID]
        end,
        GetAuctionAgeByItemID = function(_, itemID)
            return stub.ages[itemID]
        end,
        RegisterForDBUpdate = function(_, callback)
            stub.registered = stub.registered + 1
            stub.callback = callback
        end,
    } }
    Auctionator = stub
    return stub
end

local fired = {}
ns.On("SETTINGS_CHANGED", function(key) table.insert(fired, "SETTINGS " .. tostring(key)) end)
ns.On("PRICES_CHANGED", function() table.insert(fired, "PRICES") end)
local function took()
    local list = table.concat(fired, ", ")
    fired = {}
    return list
end

test("without Auctionator the source is the addon's own scan, and the login registered nothing", function()
    -- The harness's default: an undefined global is a permissive stub (indexable, callable), not nil.
    eq(Prices.HasAuctionator(), false, "the permissive stub is not Auctionator")
    eq(Prices.UsesAuctionator(), false, "not in use")
    eq(Prices.GetSource(), "own", "source")
    eq(Prices.GetAuctionatorFailure(), nil, "no failure")
end)

test("Auctionator counts as installed only with both functions", function()
    local stub = Stub()
    eq(Prices.HasAuctionator(), true, "both functions")
    eq(Prices.GetSource(), "auctionator", "source")
    stub.API.v1.RegisterForDBUpdate = nil
    eq(Prices.HasAuctionator(), false, "no update notice")
    eq(Prices.GetSource(), "own", "source without the notice")
    stub = Stub()
    stub.API.v1.GetAuctionPriceByItemID = nil
    eq(Prices.HasAuctionator(), false, "no price query")
    Auctionator = { API = {} }
    eq(Prices.HasAuctionator(), false, "no v1")
    Auctionator = { }
    eq(Prices.HasAuctionator(), false, "no API")
end)

test("the two switches are written by their setters, which tell of a change once", function()
    Stub()
    took()
    Prices.SetAuctionPrices(false)
    eq(ns.db.settings.auctionPrices, false, "written")
    eq(Prices.GetSource(), "off", "source")
    eq(Prices.UsesAuctionator(), false, "not in use while off")
    Prices.SetAuctionPrices(false)
    eq(took(), "SETTINGS auctionPrices", "one message for one change")
    Prices.SetAuctionPrices(true)
    took()
    Prices.SetAuctionator(false)
    eq(ns.db.settings.auctionatorPrices, false, "written")
    eq(Prices.GetSource(), "own", "source")
    eq(Prices.UsesAuctionator(), false, "not in use")
    Prices.SetAuctionator(false)
    eq(took(), "SETTINGS auctionatorPrices", "one message for one change")
    Prices.SetAuctionator(true)
    eq(Prices.GetSource(), "auctionator", "back")
    took()
end)

test("Auctionator's price is the auction price; the vendor price stays the floor", function()
    Stub({ [FISH] = 500, [CHEAP] = 50 }, { [FISH] = 400 })
    local price, fewLots, source = Prices.GetAuction(FISH)
    eq(price, 500, "price")
    eq(fewLots, false, "no few-lots rule")
    eq(source, "auctionator", "source")
    eq(Prices.Get(FISH), 500, "value, at any age")
    eq(Prices.Get(CHEAP), 100, "below the vendor price: the vendor price")
end)

test("an item Auctionator has no price for takes the addon's own price, with its few-lots rule", function()
    local stub = Stub({ [FISH] = 500 })
    ns.db.prices[OWN] = { price = 300, quantity = 20, lots = 5, time = 1 }
    ns.db.prices[FEW] = { price = 900, quantity = 2, lots = 1, time = 1 }
    local price, fewLots, source = Prices.GetAuction(OWN)
    eq(price, 300, "own price")
    eq(fewLots, false, "enough lots")
    eq(source, "own", "source")
    eq(Prices.Get(OWN), 300, "value")
    eq(select(2, Prices.GetAuction(FEW)), true, "few lots")
    eq(Prices.Get(FEW), 100, "few lots: the vendor price")
    eq(Prices.FormatValue(FEW):find(ns.L["few lots"], 1, true) ~= nil, true, "the mark")
    eq(Prices.GetAuction(NONE), nil, "no price anywhere")
    eq(Prices.Get(NONE), 0, "no vendor price either")
    stub.prices[OWN] = 0
    eq(select(3, Prices.GetAuction(OWN)), "own", "a zero is no price")
    stub.prices[OWN] = "12"
    eq(select(3, Prices.GetAuction(OWN)), "own", "a string is no price")
    stub.prices[OWN] = 700
    eq(Prices.Get(OWN), 700, "Auctionator's price wins over the own one")
    eq(ns.db.prices[OWN].price, 300, "the own price is untouched")
    eq(ns.db.prices[FISH], nil, "nothing of Auctionator's is stored")
end)

test("a switch off gives the own prices, or none", function()
    Stub({ [OWN] = 700 })
    Prices.SetAuctionator(false)
    eq(Prices.Get(OWN), 300, "the own price again")
    Prices.SetAuctionator(true)
    Prices.SetAuctionPrices(false)
    eq(Prices.GetAuction(OWN), nil, "no auction price")
    eq(Prices.Get(OWN), 100, "the vendor price only")
    Prices.SetAuctionPrices(true)
    took()
end)

test("a failing call is logged once and turns Auctionator off for the session", function()
    local stub = Stub({ [OWN] = 700 })
    stub.API.v1.GetAuctionPriceByItemID = function()
        stub.priceCalls = stub.priceCalls + 1
        error("its API changed")
    end
    local before = #ns.GetErrors()
    took()
    eq(Prices.Get(OWN), 300, "the fallback for the failing call")
    eq(took(), "", "no message inside the read")
    local errors = take_errors()
    eq(#errors, 1, "one error handed on")
    eq(errors[1]:find("Auctionator", 1, true) ~= nil, true, "it names Auctionator")
    eq(#ns.GetErrors(), before + 1, "one entry in the error log")
    eq(Prices.HasAuctionator(), false, "off for the session")
    eq(Prices.GetSource(), "own", "the own scan is back")
    eq(tostring(Prices.GetAuctionatorFailure()):find("its API changed", 1, true) ~= nil, true, "the reason")
    eq(Prices.Get(OWN), 300, "still the own price")
    eq(stub.priceCalls, 1, "no further call")
    eq(#ns.GetErrors(), before + 1, "nothing more logged")
    advance(0.1)
    eq(took(), "PRICES", "one PRICES_CHANGED on the next frame, no SETTINGS_CHANGED")
    eq(#take_errors(), 0, "no further error")
end)
