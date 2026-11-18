-- Auction.lua: the scan's pace (specs/018-auction-scan, User Story 1): the item key info before a search, one
-- request at a time on a ready line and not sooner than 0.6 s after the last, pages only while the price is open,
-- no search for items that cannot be sold, the progress, and no scan by itself.

load_addon()
ns.Auction.SetItemSource(nil) -- the own catches only

local L = ns.L
local A, B, C, D = 90001, 90002, 90003, 90004

-- A new visit to the auction house with `items` as the own catches; nothing scanned before.
local function fresh(items)
    fire("AUCTION_HOUSE_CLOSED")
    advance(1) -- past the 0.6 s after the last request of an earlier test
    auction_requests, auction_key_requests, auction_queries, commodity_more_requests = {}, {}, {}, {}
    auction_ready, auction_key_info = true, nil
    commodity_results, commodity_total, commodity_full = {}, {}, {}
    item_quality, item_bind, item_info_missing = {}, {}, {}
    ns.db.prices, ns.db.priceScans = {}, {}
    ns.db.scanGuard = { version = "", items = {} }
    ns.db.fishedItems = {}
    for _, itemID in ipairs(items) do
        ns.db.fishedItems[itemID] = true
        commodity_results[itemID] = { { 100, 10 }, { 110, 10 }, { 120, 10 } }
    end
    chat = {}
    fire("AUCTION_HOUSE_SHOW")
end

local function list(values)
    local texts = {}
    for _, value in ipairs(values) do
        table.insert(texts, tostring(value))
    end
    return table.concat(texts, ",")
end

local function count(values, wanted)
    local n = 0
    for _, value in ipairs(values) do
        if value == wanted then
            n = n + 1
        end
    end
    return n
end

local function requestsOf(kind)
    local n = 0
    for _, request in ipairs(auction_requests) do
        if request.kind == kind then
            n = n + 1
        end
    end
    return n
end

-- The price and the few-lots mark a scan stores for itemID.
local function stored(itemID)
    local entry = ns.db.prices[itemID]
    return entry and entry.price, select(2, ns.Prices.GetAuction(itemID))
end

-- The price and mark of the same item when the first page already holds every listing.
local function withEveryPage(itemID, rows)
    fresh({ itemID })
    commodity_results[itemID] = rows
    ns.Auction.Scan()
    auction_run()
    return stored(itemID)
end

test("no search before the item key info; a late info is searched when it arrives", function()
    fresh({ A, B })
    auction_key_info = { [A] = {} }
    ns.Auction.Scan()
    eq(list(auction_key_requests), tostring(B), "the missing info asked for at the start")
    eq(list(auction_searched()), tostring(A), "only the item with its info searched")
    advance(1)
    auction_answer()
    advance(1)
    eq(#auction_requests, 1, "B waits for its info")
    auction_key_arrives(B)
    eq(list(auction_searched()), A .. "," .. B, "B searched once its info arrived")
    auction_answer()
    advance(1)
    eq((ns.Auction.GetProgress()), false, "finished")
    eq(count(auction_key_requests, B), 1, "B's info asked for once")
end)

test("the info of a missing item is asked for once, however many requests the scan sends meanwhile", function()
    fresh({ A, B, C, D })
    auction_key_info = { [A] = {}, [C] = {}, [D] = {} }
    ns.Auction.Scan()
    eq(auction_run(), 3, "three items searched")
    eq(count(auction_key_requests, B), 1, "B's info asked for once")
end)

test("an item whose info never arrives ends the scan without it, with no scan time", function()
    fresh({ A, B })
    auction_key_info = { [A] = {} }
    ns.Auction.Scan()
    auction_run()
    eq((ns.Auction.GetProgress()), true, "still waiting for B's info")
    advance(4)
    eq((ns.Auction.GetProgress()), false, "ended after the wait")
    assert(chat_contains(L["Auction scan finished: %d of %d price(s) found."]:format(1, 2)), table.concat(chat, "\n"))
    eq(ns.db.priceScans[B], nil, "no scan time for B")
    eq(count(auction_searched(), B), 0, "B never searched")
end)

test("an info that arrives on a busy line just before the info wait ends is still searched", function()
    fresh({ A, B })
    auction_key_info = { [A] = {} }
    ns.Auction.Scan()
    auction_run() -- A done; the wait for B's info runs
    auction_ready = false -- another request (the player's, another addon's) holds the line
    advance(1.5)
    auction_key_arrives(B) -- the scan's turn waits for the line
    advance(1) -- the info wait ends meanwhile
    eq((ns.Auction.GetProgress()), true, "still scanning: B is ready, not dropped")
    auction_ready = true
    fire("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
    eq(count(auction_searched(), B), 1, "B searched once the line is free")
    auction_answer()
    advance(1)
    eq((ns.Auction.GetProgress()), false, "finished")
    eq(select(2, ns.Auction.GetProgress()), 2, "both items done")
end)

test("closing the window after a finished scan keeps the last scan's time in the debug report", function()
    fresh({ A })
    ns.Auction.Scan()
    auction_run()
    local before = ns.Auction.Describe()[1]
    advance(100)
    fire("AUCTION_HOUSE_CLOSED")
    eq(ns.Auction.Describe()[1]:gsub("^auction: %a+", ""), before:gsub("^auction: %a+", ""), "the same counts and time")
end)

test("one request at a time, only on a ready line, not sooner than 0.6 s after the last", function()
    fresh({ A, B, C })
    ns.Auction.Scan()
    eq(#auction_requests, 1, "the first request")
    fire("AUCTION_HOUSE_THROTTLED_MESSAGE_SENT")
    fire("AUCTION_HOUSE_THROTTLED_MESSAGE_QUEUED")
    eq(#auction_requests, 1, "nothing more while it is unanswered")
    auction_answer()
    advance(0.3)
    eq(#auction_requests, 1, "not sooner than 0.6 s after the last request")
    advance(0.4)
    eq(#auction_requests, 2, "the next one after 0.6 s")
    advance(1)
    eq(#auction_requests, 2, "nothing more while the second is unanswered")
    -- answered, but the READY event never comes: the line turns ready later without an event
    auction_requests[2].answered = true
    fire("AUCTION_HOUSE_THROTTLED_MESSAGE_RESPONSE_RECEIVED")
    fire("COMMODITY_SEARCH_RESULTS_UPDATED", B)
    auction_ready = true
    advance(2)
    eq(#auction_requests, 3, "a missed READY event does not stop the scan")
    auction_answer()
    advance(1)
    for index, request in ipairs(auction_requests) do
        eq(request.notReady, false, "request " .. index .. " sent on a ready line")
    end
end)

test("the response and the result on a ready line, without a READY event: the scan goes on", function()
    fresh({ A, B })
    ns.Auction.Scan()
    auction_requests[1].answered = true
    auction_ready = true
    fire("AUCTION_HOUSE_THROTTLED_MESSAGE_RESPONSE_RECEIVED")
    fire("COMMODITY_SEARCH_RESULTS_UPDATED", A)
    advance(1)
    eq(list(auction_searched()), A .. "," .. B, "B searched")
end)

test("paging: no further page once the loaded pieces decide the price", function()
    local price, fewLots = withEveryPage(A, { { 100, 10 }, { 110, 10 }, { 120, 10 }, { 200, 70 } })
    fresh({ A })
    commodity_full[A] = false
    commodity_total[A] = 100 -- the cheapest fifth is 20 pieces, 30 are loaded
    ns.Auction.Scan()
    auction_run()
    eq(#commodity_more_requests, 0, "no page asked for")
    eq(stored(A), price, "the price of every page")
    eq(select(2, stored(A)), fewLots, "the mark of every page")
    eq(price, 105, "the cheapest 20 pieces")
end)

test("paging: the next page through the turn while the loaded pieces are below the cheapest fifth", function()
    local rows = { { 100, 10 }, { 110, 10 }, { 120, 10 }, { 130, 170 } }
    local price, fewLots = withEveryPage(A, rows)
    fresh({ A })
    commodity_full[A] = false
    commodity_total[A] = 1000
    ns.Auction.Scan()
    auction_answer()
    eq(#commodity_more_requests, 0, "not inside the result event")
    advance(0.3)
    eq(#commodity_more_requests, 0, "not sooner than 0.6 s after the search")
    advance(0.4)
    eq(#commodity_more_requests, 1, "the page after 0.6 s")
    eq(ns.db.prices[A], nil, "no price from the first page alone")
    commodity_results[A], commodity_full[A], commodity_total[A] = rows, nil, nil
    auction_answer()
    eq(stored(A), price, "the price of every page")
    eq(select(2, stored(A)), fewLots, "the mark of every page")
end)

test("paging: fewer than 3 rows or 5 pieces loaded ask for the next page; the mark stays the same", function()
    for _, case in ipairs({
        { first = { { 100, 10 }, { 110, 10 } }, all = { { 100, 10 }, { 110, 10 }, { 300, 1 } }, what = "2 rows" },
        { first = { { 100, 2 }, { 110, 1 }, { 120, 1 } }, all = { { 100, 2 }, { 110, 1 }, { 120, 1 } },
            what = "4 pieces" },
    }) do
        local price, fewLots = withEveryPage(A, case.all)
        fresh({ A })
        commodity_results[A] = case.first
        commodity_full[A] = false
        ns.Auction.Scan()
        advance(1)
        auction_answer()
        advance(1)
        eq(#commodity_more_requests, 1, case.what .. ": the next page asked for")
        commodity_results[A], commodity_full[A] = case.all, nil
        auction_answer()
        eq(stored(A), price, case.what .. ": the price of every page")
        eq(select(2, stored(A)), fewLots, case.what .. ": the mark of every page")
    end
end)

test("paging: after 5 pages the loaded ones decide", function()
    fresh({ A })
    commodity_results[A] = { { 100, 1 }, { 110, 1 } }
    commodity_full[A] = false
    commodity_total[A] = 1000
    ns.Auction.Scan()
    auction_run()
    eq(#commodity_more_requests, 5, "five pages")
    eq(stored(A), 105, "the price of what was loaded")
    eq(select(2, stored(A)), true, "few lots")
end)

test("a page request answered without its page: the loaded pages decide after 3 s", function()
    fresh({ A, B })
    commodity_results[A] = { { 100, 1 }, { 110, 1 } }
    commodity_full[A] = false
    commodity_total[A] = 1000
    ns.Auction.Scan()
    auction_answer()
    advance(1)
    eq(#commodity_more_requests, 1, "the next page asked for")
    auction_requests[#auction_requests].answered = true
    auction_ready = true
    fire("AUCTION_HOUSE_THROTTLED_MESSAGE_RESPONSE_RECEIVED") -- the page itself never comes
    advance(2)
    eq(ns.db.prices[A], nil, "still waiting for the page")
    advance(1.5)
    eq(stored(A), 105, "the price of the first page")
    assert(ns.db.priceScans[A], "a scan time: the search was answered")
    eq(list(auction_searched()), A .. "," .. B, "B searched after the wait")
end)

test("a response without a result: the item is skipped after 3 s, nothing stored", function()
    fresh({ A, B })
    ns.Auction.Scan()
    auction_requests[1].answered = true
    auction_ready = true
    fire("AUCTION_HOUSE_THROTTLED_MESSAGE_RESPONSE_RECEIVED")
    advance(2)
    eq(#auction_requests, 1, "still waiting for the result")
    advance(1.5)
    eq(list(auction_searched()), A .. "," .. B, "B searched after the wait")
    eq(ns.db.prices[A], nil, "no price for A")
    eq(ns.db.priceScans[A], nil, "no scan time for A")
end)

test("the line ready again without a response: an answer without a result, the next item after 3 s", function()
    fresh({ A, B })
    ns.Auction.Scan()
    auction_ready = true
    fire("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
    advance(2)
    eq(#auction_requests, 1, "no further request before the wait")
    advance(1.5)
    eq(list(auction_searched()), A .. "," .. B, "B searched after the wait")
    eq(ns.Auction.GetState(), "scanning", "no stall")
end)

test("a ready reading at the scan's own send does not count as an answer", function()
    fresh({ A, B })
    ns.Auction.Scan()
    auction_ready = true
    fire("AUCTION_HOUSE_THROTTLED_MESSAGE_SENT")
    advance(5)
    eq(#auction_requests, 1, "still waiting for A")
    auction_answer()
    eq(stored(A), 100, "A settled with its price")
end)

test("items that cannot be sold are not searched", function()
    local G, Q, P, U, K = 90011, 90012, 90013, 90014, 90015
    fresh({ G, Q, P, U, K })
    item_quality[G] = 0 -- poor
    item_bind[Q] = 4 -- quest
    item_bind[P] = 1 -- bind on pickup
    item_info_missing[U] = true -- not loaded: searched
    auction_key_info = { [U] = {}, [K] = { quality = 0 } } -- K: poor by its item key info
    ns.Auction.Scan()
    assert(chat_contains(L["Scanning auction prices of %d item(s)..."]:format(2)), table.concat(chat, "\n"))
    auction_run()
    eq(list(auction_searched()), tostring(U), "only U searched")
end)

test("the progress goes item by item", function()
    fresh({ A, B })
    local seen, recording = {}, true
    ns.On("AUCTION_STATE", function()
        if recording then
            local scanning, done, total = ns.Auction.GetProgress()
            table.insert(seen, (scanning and "scanning " or "idle ") .. done .. "/" .. total)
        end
    end)
    ns.Auction.Scan()
    auction_run()
    recording = false
    local states = table.concat(seen, ", ")
    assert(states:find("scanning 0/2", 1, true), states)
    assert(states:find("scanning 1/2", 1, true), states)
    eq(seen[#seen], "idle 2/2", "idle at the end")
end)

test("opening the auction house starts nothing", function()
    fresh({ A })
    fire("AUCTION_HOUSE_CLOSED")
    auction_requests, auction_key_requests, auction_key_info = {}, {}, {}
    fire("AUCTION_HOUSE_SHOW")
    advance(30)
    eq(#auction_requests, 0, "no request")
    eq(#auction_key_requests, 0, "no item key info asked for")
end)
