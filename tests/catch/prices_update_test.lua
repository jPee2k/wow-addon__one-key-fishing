-- Prices.lua: Auctionator's update notice becomes PRICES_CHANGED (specs/019-auctionator-prices, FR-006). Auctionator
-- is there at the login, so the addon registers its notice.

local stub = { registered = 0 }
stub.API = { v1 = {
    GetAuctionPriceByItemID = function() return nil end,
    RegisterForDBUpdate = function(callerID, callback)
        assert(callerID == "OneKeyFishing", "the caller's name")
        stub.registered = stub.registered + 1
        stub.callback = callback
    end,
} }
Auctionator = stub

load_addon()

local changes = 0
ns.On("PRICES_CHANGED", function() changes = changes + 1 end)

test("the login registers one notice and refreshes once Auctionator's prices are ready", function()
    eq(stub.registered, 1, "one registration")
    eq(type(stub.callback), "function", "the callback")
    advance(1.1)
    eq(changes, 1, "one refresh after the login")
end)

test("a burst of notices gives one PRICES_CHANGED", function()
    changes = 0
    for _ = 1, 5 do
        stub.callback()
        advance(0.02)
    end
    eq(changes, 0, "not inside the burst")
    advance(0.6)
    eq(changes, 1, "one for the burst")
    stub.callback()
    advance(0.6)
    eq(changes, 2, "the next notice gives the next one")
end)

test("with the switch off the notices change nothing", function()
    changes = 0
    ns.Prices.SetAuctionator(false)
    stub.callback()
    advance(1)
    eq(changes, 0, "nothing")
    ns.Prices.SetAuctionator(true)
    ns.Prices.SetAuctionPrices(false)
    stub.callback()
    advance(1)
    eq(changes, 0, "nothing with auction prices off")
    ns.Prices.SetAuctionPrices(true)
end)
