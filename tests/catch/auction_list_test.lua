-- Auction.lua: the scan's list (specs/018-auction-scan, User Stories 2 and 4): the own catches, then the bundled
-- database, then other players' records, each item once; which items are left out; fresh prices and the order.

load_addon()

local L = ns.L
local bundled, shared = {}, {}
local function Source()
    return bundled, shared
end

-- A new visit with `own` as the own catches and the two sets of the item source; nothing scanned before.
local function fresh(own, bundledItems, sharedItems)
    fire("AUCTION_HOUSE_CLOSED")
    advance(1)
    auction_requests, auction_key_requests, auction_queries, commodity_more_requests = {}, {}, {}, {}
    auction_ready, auction_key_info = true, nil
    commodity_results, commodity_total, commodity_full = {}, {}, {}
    item_quality, item_bind, item_info_missing, unknown_items = {}, {}, {}, {}
    ns.db.prices, ns.db.priceScans = {}, {}
    ns.db.scanGuard = { version = "", items = {} }
    ns.db.fishedItems = {}
    bundled, shared = {}, {}
    local function fill(target, items)
        for _, itemID in ipairs(items or {}) do
            target[itemID] = true
            if type(itemID) == "number" then
                commodity_results[itemID] = { { 100, 10 }, { 110, 10 }, { 120, 10 } }
            end
        end
    end
    fill(ns.db.fishedItems, own)
    fill(bundled, bundledItems)
    fill(shared, sharedItems)
    ns.Auction.SetItemSource(Source)
    chat = {}
    fire("AUCTION_HOUSE_SHOW")
end

local function scan()
    ns.Auction.Scan()
    auction_run()
    return table.concat(auction_searched(), ",")
end

test("own catches first, then the bundled database, then other players' records, each item once", function()
    fresh({ 90005, 90001 }, { 90004, 90002, 90003 }, { 90003, 90006, 90001 })
    eq(scan(), "90001,90005,90002,90003,90004,90006", "the order")
    assert(chat_contains(L["Scanning auction prices of %d item(s)..."]:format(6)), table.concat(chat, "\n"))
end)

test("IDs that are no item or that the client does not know are never searched", function()
    fresh({ 90001 }, { "x", 0, -5, 1.5, 90020 }, { 90021 })
    unknown_items[90020], unknown_items[90021] = true, true
    eq(scan(), "90001", "the own catch only")
end)

test("a source that fails, returns nothing or is not set leaves the own catches", function()
    fresh({ 90001 })
    ns.Auction.SetItemSource(function() error("broken source") end)
    eq(scan(), "90001", "a failing source")
    eq(#take_errors(), 1, "the failure handed to the game's error handler")
    fresh({ 90001 })
    ns.Auction.SetItemSource(function() end)
    eq(scan(), "90001", "a source that returns nothing")
    fresh({ 90001 })
    ns.Auction.SetItemSource(nil)
    eq(scan(), "90001", "no source")
    ns.db.errors = {}
end)

test("a price found for an item the player never caught is used like a caught one's", function()
    fresh({}, { 90002 })
    scan()
    eq(ns.Prices.Get(90002), 100, "the auction price")
    eq((ns.Prices.GetAuction(90002)), 100, "the auction price of the tooltips")
end)

test("with auction prices turned off a scan still runs and stores; the prices are not used", function()
    fresh({ 90001 })
    ns.db.settings.auctionPrices = false
    eq(scan(), "90001", "searched")
    eq(ns.db.prices[90001].price, 100, "stored")
    eq(ns.Prices.GetAuction(90001), nil, "not used")
    ns.db.settings.auctionPrices = true
end)

test("an item caught after a scan joins the next one in the own group", function()
    fresh({ 90010 }, { 90005 }, { 90000 })
    scan()
    ns.db.fishedItems[90000] = true
    auction_requests = {}
    advance(1)
    local searched = scan()
    eq(searched:match("^(%d+)"), "90000", "the new catch first: " .. searched)
end)

test("a list that is empty after the checks: the present message, no request", function()
    fresh({ 90030, 90031 })
    unknown_items[90030] = true
    item_quality[90031] = 0
    ns.Auction.Scan()
    advance(5)
    eq(#auction_requests, 0, "no request")
    assert(chat_contains(L["Nothing to scan yet: catch some fish first."]), table.concat(chat, "\n"))
end)

-- Fresh prices and the order inside a group (User Story 4).

test("an answered search sets the scan time; an item not on sale keeps its earlier price", function()
    fresh({ 90001, 90002 })
    commodity_results[90002] = {}
    local earlier = { price = 5, quantity = 10, lots = 3, time = 1 }
    ns.db.prices[90002] = earlier
    local before = time()
    scan()
    assert(ns.db.priceScans[90001] >= before, "scan time with a price")
    assert(ns.db.priceScans[90002] >= before, "scan time without one")
    eq(ns.db.prices[90002], earlier, "the earlier price stays")
end)

test("items scanned less than 15 minutes ago are left out; all of them when every item is fresh", function()
    fresh({ 90001, 90002, 90003 })
    ns.db.priceScans[90001] = time() - 100
    eq(scan(), "90002,90003", "the others")
    assert(chat_contains(L["Scanning auction prices of %d item(s)..."]:format(2)), table.concat(chat, "\n"))
    auction_requests = {}
    advance(1)
    eq(scan(), "90001,90002,90003", "every item fresh: all searched again")
end)

test("15 minutes is the limit", function()
    fresh({ 90001, 90002 })
    ns.db.priceScans[90001] = time() - 901
    ns.db.priceScans[90002] = time() - 899
    eq(scan(), "90001", "the older one only")
end)

test("a scan stopped by closing the window goes on with the items it did not reach", function()
    fresh({ 90001, 90002, 90003, 90004, 90005 })
    ns.Auction.Scan()
    auction_answer()
    advance(1)
    auction_answer()
    fire("AUCTION_HOUSE_CLOSED")
    fire("AUCTION_HOUSE_SHOW")
    auction_requests = {}
    advance(1)
    eq(scan(), "90003,90004,90005", "the rest")
end)

test("inside a group: never scanned first, then the oldest, ties by ID; the group order wins", function()
    fresh({ 90001, 90002, 90003, 90009 }, { 90004 })
    ns.db.priceScans[90001] = time() - 2000
    ns.db.priceScans[90009] = time() - 2000
    ns.db.priceScans[90003] = time() - 3000
    eq(scan(), "90002,90003,90001,90009,90004", "the order")
end)

test("a price of an earlier version counts by its own time", function()
    fresh({ 90001, 90002, 90003 })
    ns.db.prices[90001] = { price = 5, time = time() }
    ns.db.prices[90002] = { price = 5, time = time() - 5000 }
    eq(scan(), "90003,90002", "the new price is fresh; never scanned first, then the old one")
end)

test("an item the auction house never answers is never searched, in any group", function()
    ns.GameData.AuctionUnanswered[90011], ns.GameData.AuctionUnanswered[90012] = true, true
    fresh({ 90011, 90001 }, { 90012, 90002 }, { 90003 })
    local order = scan()
    ns.GameData.AuctionUnanswered[90011], ns.GameData.AuctionUnanswered[90012] = nil, nil
    eq(order, "90001,90002,90003", "the listed items left out")
end)
