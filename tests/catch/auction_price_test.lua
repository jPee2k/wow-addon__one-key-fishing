-- Auction.lua and Prices.lua: the robust auction price (the cheapest 20% of the listed pieces) and few lots.

local FISH, PEARL = 6291, 13926
item_prices[FISH] = 100 -- vendor price
item_prices[PEARL] = 100

load_addon()
ns.Auction.SetItemSource(nil) -- the own catches only

local Prices = ns.Prices

-- One scan of one item, answered with the stub results set before it (every price is fresh after a scan, and a
-- scan of fresh prices searches them all again).
local function scan(itemID, kind)
    ns.db.fishedItems = { [itemID] = true }
    fire("AUCTION_HOUSE_SHOW")
    advance(1) -- past the 0.6 s after the last request of an earlier test
    ns.Auction.Scan()
    auction_answer(itemID, kind)
    return ns.db.prices[itemID]
end

test("the scan's progress is told through AUCTION_STATE for the scan button", function()
    ns.db.fishedItems = { [FISH] = true, [PEARL] = true }
    local seen = {}
    ns.On("AUCTION_STATE", function()
        local scanning, done, total = ns.Auction.GetProgress()
        table.insert(seen, (scanning and "scanning " or "idle ") .. done .. "/" .. total)
    end)
    fire("AUCTION_HOUSE_SHOW")
    ns.Auction.Scan()
    auction_run()
    local states = table.concat(seen, ", ")
    assert(states:find("scanning 0/2, scanning 1/2, scanning 2/2, idle 2/2", 1, true), "progress: " .. states)
    local scanning = ns.Auction.GetProgress()
    eq(scanning, false, "idle after the scan")
end)

local function within(actual, expected, share, what)
    assert(math.abs(actual - expected) <= expected * share,
        ("%s: %s is not within %d%% of %s"):format(what, tostring(actual), share * 100, tostring(expected)))
end

test("one lot far below the market moves the price less than 5%", function()
    commodity_results[FISH] = { { 1, 1 }, { 20000, 60 }, { 20100, 40 } }
    local entry = scan(FISH)
    within(entry.price, 20000, 0.05, "price")
    eq(entry.quantity, 101, "pieces listed")
end)

test("one lot far above the market does not count", function()
    commodity_results[FISH] = { { 20000, 60 }, { 20100, 40 }, { 99990000, 1 } }
    eq(scan(FISH).price, 20000, "price")
end)

test("the results are sorted here, whatever order the game gives", function()
    commodity_results[FISH] = { { 20100, 40 }, { 99990000, 1 }, { 20000, 60 } }
    eq(scan(FISH).price, 20000, "price")
end)

test("the total listed counts pieces that were not loaded yet", function()
    commodity_results[FISH] = { { 20000, 10 }, { 30000, 10 } }
    commodity_total[FISH] = 50 -- 20% is 10 pieces: all at 2 gold
    local entry = scan(FISH)
    eq(entry.price, 20000, "price")
    eq(entry.quantity, 20, "the pieces the price could see: 20 loaded of 50 listed")
    eq(ns.Auction.GetCoverage().loaded, 20, "coverage for the debug report")
    commodity_total[FISH] = nil
end)

test("a price from fewer than 5 loaded pieces is few lots, however many are listed", function()
    commodity_results[FISH] = { { 20000, 3 } }
    commodity_total[FISH] = 1000
    eq(scan(FISH).quantity, 3, "the pieces the price saw")
    eq(select(2, Prices.GetAuction(FISH)), true, "few lots")
    commodity_total[FISH] = nil
end)

test("fewer than 5 pieces: marked as few lots, values use the vendor price", function()
    commodity_results[FISH] = { { 20000, 2 }, { 21000, 1 } }
    eq(scan(FISH).quantity, 3, "pieces listed")
    local price, fewLots = Prices.GetAuction(FISH)
    eq(price, 20000, "the auction price is still known")
    eq(fewLots, true, "few lots")
    eq(Prices.Get(FISH), 100, "vendor price for values")
end)

test("an auction price below the vendor price: the vendor price", function()
    commodity_results[FISH] = { { 50, 50 } }
    scan(FISH)
    eq(Prices.Get(FISH), 100, "vendor")
end)

test("a price saved by 1.0.0 (no quantity) is used as before", function()
    ns.db.prices[FISH] = { price = 500, time = 1 }
    local price, fewLots = Prices.GetAuction(FISH)
    eq(price, 500, "price")
    eq(fewLots, false, "not few lots")
    eq(Prices.Get(FISH), 500, "value")
end)

test("prices saved under the old item rule are dropped once at login, later ones kept", function()
    ns.db.priceRule = nil
    ns.db.prices[PEARL] = { price = 812, quantity = 14, lots = 5, time = 1 }
    ns.db.priceScans[PEARL] = 1
    fire("PLAYER_LOGIN")
    eq(ns.db.prices[PEARL], nil, "the old price dropped")
    eq(ns.db.priceScans[PEARL], nil, "its scan time dropped: the next scan searches it first")
    eq(ns.db.priceRule, 2, "the rule saved")
    ns.db.prices[PEARL] = { price = 5683, quantity = 14, lots = 5, time = 2 }
    fire("PLAYER_LOGIN")
    eq(ns.db.prices[PEARL].price, 5683, "a price of the new rule kept")
    ns.db.prices[PEARL] = nil
end)

test("items that are not commodities: a row's buyout is one piece's price, bid-only auctions skipped", function()
    -- The auction house's rows for 53 Pound Yellowtail on 2026-11-18 (V5): the price of a piece, the pieces at it.
    item_results[PEARL] = { { 5680, 1 }, { 5685, 7 }, { 5686, 1 }, { nil, 1 }, { 5687, 3 }, { 6100, 2 } }
    local entry = scan(PEARL, "item")
    eq(entry.quantity, 14, "pieces with a buyout")
    eq(entry.lots, 5, "rows with a buyout")
    eq(entry.price, 5683, "the cheapest 3 of 14 pieces: 5680 and two at 5685")
end)

test("item rows mark a value whose auction price rests on few lots", function()
    commodity_results[FISH] = { { 20000, 2 } }
    scan(FISH)
    local text = Prices.FormatValue(FISH, 3)
    assert(text:find("300c", 1, true), "three pieces at the vendor price: " .. text)
    assert(text:find(ns.L["few lots"], 1, true), "the mark: " .. text)
    local lines = {}
    Prices.AddTooltipLine({ AddLine = function(_, line) table.insert(lines, line) end }, FISH)
    eq(lines[1], ns.ColoredText((ns.L["Auction price (OneKeyFishing): %s (few lots)"]):format("20000c"), 0.6, 0.6, 0.6),
        "tooltip line, its grey as a code too")
    commodity_results[FISH] = { { 20000, 20 }, { 20000, 20 }, { 20100, 10 } }
    scan(FISH)
    eq(Prices.FormatValue(FISH, 1), "20000c", "no mark with enough lots")
    lines = {}
    Prices.AddTooltipLine({ AddLine = function(_, line) table.insert(lines, line) end }, FISH)
    eq(lines[1], (ns.L["Auction price (OneKeyFishing): %s"]):format("20000c"), "the price under the addon's name")
    lines = {}
    Prices.AddTooltipLine({ AddLine = function(_, line) table.insert(lines, line) end }, FISH + 1)
    eq(#lines, 0, "no line without an auction price")
end)

test("one seller's stack is few lots, however many pieces it has", function()
    commodity_results[FISH] = { { 990000, 20 } } -- a single auction of 20 at a made-up price
    local entry = scan(FISH)
    eq(entry.lots, 1, "one auction")
    eq(select(2, Prices.GetAuction(FISH)), true, "few lots")
    eq(Prices.Get(FISH), 100, "values use the vendor price")
    commodity_results[FISH] = { { 20000, 2 }, { 20100, 2 }, { 20200, 2 } }
    scan(FISH)
    eq(select(2, Prices.GetAuction(FISH)), false, "three auctions and six pieces are enough")
end)

test("more commodity results on their way: the next page is asked for after the answer and used", function()
    commodity_results[FISH] = { { 30000, 10 } }
    commodity_full[FISH] = false
    commodity_more_requests = {}
    local before = ns.db.prices[FISH]
    scan(FISH)
    eq(#commodity_more_requests, 0, "not inside the result event")
    advance(1)
    eq(#commodity_more_requests, 1, "the next page asked for at the scan's turn")
    eq(ns.db.prices[FISH], before, "no price from the first page alone")
    commodity_results[FISH] = { { 30000, 10 }, { 20000, 30 }, { 25000, 10 } }
    commodity_full[FISH] = nil
    auction_answer()
    eq(ns.db.prices[FISH].price, 20000, "price from all pages")
end)

test("after the page limit the loaded pages decide", function()
    commodity_results[FISH] = { { 40000, 1 }, { 41000, 1 } }
    commodity_full[FISH] = false
    commodity_total[FISH] = 1000
    commodity_more_requests = {}
    scan(FISH)
    auction_run()
    eq(#commodity_more_requests, 5, "five pages")
    eq(ns.db.prices[FISH].price, 40500, "the loaded pages")
    commodity_full[FISH], commodity_total[FISH] = nil, nil
end)

test("later pages arrive as COMMODITY_SEARCH_RESULTS_ADDED", function()
    commodity_results[FISH] = { { 50000, 10 } }
    commodity_full[FISH] = false
    commodity_more_requests = {}
    scan(FISH)
    advance(1)
    commodity_results[FISH] = { { 50000, 10 }, { 51000, 10 } }
    auction_answer() -- still more to come
    advance(1)
    eq(#commodity_more_requests, 2, "a second page asked for")
    commodity_results[FISH] = { { 50000, 10 }, { 51000, 10 }, { 30000, 20 } }
    commodity_full[FISH] = nil
    auction_answer()
    eq(ns.db.prices[FISH].price, 30000, "the price from all three pages")
    eq(ns.db.prices[FISH].lots, 3, "three price points")
end)
