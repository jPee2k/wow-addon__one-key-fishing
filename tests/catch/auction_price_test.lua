-- Auction.lua and Prices.lua: the robust auction price (the cheapest 20% of the listed pieces) and few lots.

local FISH, PEARL = 6291, 13926
item_prices[FISH] = 100 -- vendor price
item_prices[PEARL] = 100

load_addon()

local Prices = ns.Prices

-- One scan of one item, answered with the stub results set before it.
local function scan(itemID, kind)
    ns.db.fishedItems = { [itemID] = true }
    fire("AUCTION_HOUSE_SHOW")
    ns.Auction.Scan()
    if kind == "item" then
        fire("ITEM_SEARCH_RESULTS_UPDATED", { itemID = itemID })
    else
        fire("COMMODITY_SEARCH_RESULTS_UPDATED", itemID)
    end
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
    fire("COMMODITY_SEARCH_RESULTS_UPDATED", FISH)
    fire("COMMODITY_SEARCH_RESULTS_UPDATED", PEARL)
    local states = table.concat(seen, ", ")
    assert(states:find("scanning 1/2, scanning 2/2, idle 2/2", 1, true), "progress while scanning: " .. states)
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

test("items that are not commodities: buyout per piece, bid-only auctions skipped", function()
    item_results[PEARL] = { { 50000, 5 }, { 9000, 1 }, { nil, 1 }, { 60000, 4 } }
    local entry = scan(PEARL, "item")
    eq(entry.quantity, 10, "pieces with a buyout")
    eq(entry.price, 9500, "the cheapest 2 of 10 pieces: 9000 and 10000")
end)

test("item rows mark a value whose auction price rests on few lots", function()
    commodity_results[FISH] = { { 20000, 2 } }
    scan(FISH)
    local text = Prices.FormatValue(FISH, 3)
    assert(text:find("300c", 1, true), "three pieces at the vendor price: " .. text)
    assert(text:find(ns.L["few lots"], 1, true), "the mark: " .. text)
    local lines = {}
    Prices.AddTooltipLine({ AddLine = function(_, line) table.insert(lines, line) end }, FISH)
    eq(lines[1], (ns.L["Auction price: %s (few lots)"]):format("20000c"), "tooltip line")
    commodity_results[FISH] = { { 20000, 20 }, { 20000, 20 }, { 20100, 10 } }
    scan(FISH)
    eq(Prices.FormatValue(FISH, 1), "20000c", "no mark with enough lots")
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

test("more commodity results on their way: the next page is asked for and used", function()
    commodity_results[FISH] = { { 30000, 10 } }
    commodity_full[FISH] = false
    commodity_more_requests = {}
    local before = ns.db.prices[FISH]
    scan(FISH)
    eq(#commodity_more_requests, 1, "the next page asked for")
    eq(ns.db.prices[FISH], before, "no price from the first page alone")
    commodity_results[FISH] = { { 30000, 10 }, { 20000, 30 }, { 25000, 10 } }
    commodity_full[FISH] = nil
    fire("COMMODITY_SEARCH_RESULTS_UPDATED", FISH)
    eq(ns.db.prices[FISH].price, 20000, "price from all pages")
end)

test("when more results never come, the pages that came decide at the timeout", function()
    commodity_results[FISH] = { { 40000, 10 }, { 41000, 10 }, { 42000, 10 } }
    commodity_full[FISH] = false
    scan(FISH)
    advance(5) -- past the query timeout
    eq(ns.db.prices[FISH].price, 40000, "the loaded pages")
    commodity_full[FISH] = nil
end)

test("later pages arrive as COMMODITY_SEARCH_RESULTS_ADDED, each page with its own wait", function()
    commodity_results[FISH] = { { 50000, 10 } }
    commodity_full[FISH] = false
    commodity_more_requests = {}
    scan(FISH)
    advance(3)
    commodity_results[FISH] = { { 50000, 10 }, { 51000, 10 } }
    fire("COMMODITY_SEARCH_RESULTS_ADDED", FISH) -- still more to come
    eq(#commodity_more_requests, 2, "a second page asked for")
    advance(3) -- 6 s after the query: past one timeout, but the second page has its own wait
    commodity_results[FISH] = { { 50000, 10 }, { 51000, 10 }, { 30000, 20 } }
    commodity_full[FISH] = nil
    fire("COMMODITY_SEARCH_RESULTS_ADDED", FISH)
    eq(ns.db.prices[FISH].price, 30000, "the price from all three pages")
    eq(ns.db.prices[FISH].lots, 3, "three price points")
end)
