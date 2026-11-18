-- Prices.lua: the own catches counted by the source of their auction price (specs/019-auctionator-prices, FR-019),
-- and the "can be sold at auction" rule the scan shares.

local BY_AUCTIONATOR, BY_OWN, BY_VENDOR, NO_PRICE, BOUND, QUEST, UNLOADED = 6291, 13926, 6303, 7974, 6522, 6643, 6308
item_prices[BY_AUCTIONATOR] = 10
item_prices[BY_VENDOR] = 10
item_bind[BOUND] = 1
item_bind[QUEST] = 4

load_addon()

local Prices = ns.Prices

Auctionator = { API = { v1 = {
    GetAuctionPriceByItemID = function(_, itemID)
        return (itemID == BY_AUCTIONATOR or itemID == BOUND) and 500 or nil
    end,
    RegisterForDBUpdate = function() end,
} } }

local function catches(list)
    local items = ns.Stats.GetTotal().items
    for itemID in pairs(items) do
        items[itemID] = nil
    end
    for _, itemID in ipairs(list) do
        items[itemID] = 3
    end
end

local function counts()
    local c = Prices.CountSources()
    return ("%d %d %d %d"):format(c.auctionator, c.own, c.vendor, c.none)
end

test("bound items cannot be sold at auction; an item not loaded yet can", function()
    eq(Prices.CanAuction(BY_VENDOR), true, "bind type 0")
    eq(Prices.CanAuction(BOUND), false, "bind on pickup")
    eq(Prices.CanAuction(QUEST), false, "quest item")
    item_bind[BY_VENDOR] = 2
    eq(Prices.CanAuction(BY_VENDOR), true, "bind on equip")
    item_bind[BY_VENDOR] = 3
    eq(Prices.CanAuction(BY_VENDOR), true, "bind on use")
    item_bind[BY_VENDOR] = nil
    item_info_missing[UNLOADED] = true
    eq(Prices.CanAuction(UNLOADED), true, "not loaded")
    item_info_missing[UNLOADED] = nil
end)

test("the four counts cover the own catches that can be sold and add up to them", function()
    ns.db.prices[BY_OWN] = { price = 300, quantity = 20, lots = 5, time = 1 }
    catches({ BY_AUCTIONATOR, BY_OWN, BY_VENDOR, NO_PRICE, BOUND, QUEST })
    eq(counts(), "1 1 1 1", "auctionator, own, vendor, none")
    local c = Prices.CountSources()
    eq(c.auctionator + c.own + c.vendor + c.none, 4, "the sum: six catches, two bound")
end)

test("an own price on few lots still counts as the addon's own price", function()
    ns.db.prices[BY_OWN] = { price = 300, quantity = 2, lots = 1, time = 1 }
    eq(counts(), "1 1 1 1", "own, though its value is the vendor price")
    ns.db.prices[BY_OWN] = { price = 300, quantity = 20, lots = 5, time = 1 }
end)

test("an item the client has not loaded counts as sellable", function()
    item_info_missing[UNLOADED] = true
    catches({ BY_AUCTIONATOR, UNLOADED })
    eq(counts(), "1 0 0 1", "counted, without a price")
    item_info_missing[UNLOADED] = nil
end)

test("with Auctionator not in use its count is 0", function()
    catches({ BY_AUCTIONATOR, BY_OWN, BY_VENDOR, NO_PRICE, BOUND, QUEST })
    Prices.SetAuctionator(false)
    eq(counts(), "0 1 2 1", "its item falls to the vendor price")
    Prices.SetAuctionator(true)
    Prices.SetAuctionPrices(false)
    eq(counts(), "0 0 2 2", "auction prices off: vendor prices only")
    Prices.SetAuctionPrices(true)
end)

test("the advice's count leaves out grey junk, which no Auctionator scan will ever price (final review)", function()
    local JUNK = 6150
    item_quality[JUNK] = 0
    item_prices[JUNK] = 3
    catches({ BY_AUCTIONATOR, BY_OWN, BY_VENDOR, NO_PRICE, JUNK })
    local c = Prices.CountSources()
    eq(c.vendor, 2, "the junk still counts at its vendor price")
    eq(c.missing, 3, "own, vendor and none without the junk")
    item_quality[JUNK] = nil
    eq(Prices.CountSources().missing, 4, "the same item of common quality counts")
end)
