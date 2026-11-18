-- Auction.lua: the auction house that stops answering (specs/018-auction-scan, User Stories 3 and 5): ten seconds
-- of a busy line stop the scan with one chat line; the states and the reason for the scan buttons; the items the
-- auction house did not answer for are remembered (the guard).

load_addon()

local L = ns.L
local STALLED =
    L["Auction scan stopped: the auction house does not answer (%d of %d price(s) found). Log out and back in."]
local WHY_STALLED = L["The auction house does not answer. Log out and back in to bring it back."]
local A, B, C = 90001, 90002, 90003
local bundled, shared = {}, {}
ns.Auction.SetItemSource(function() return bundled, shared end)

local pricesChanged = 0
ns.On("PRICES_CHANGED", function() pricesChanged = pricesChanged + 1 end)
local states = 0
ns.On("AUCTION_STATE", function() states = states + 1 end)

-- A new visit with `own` as the own catches and the two sets of the item source; nothing scanned or remembered.
local function fresh(own, bundledItems, sharedItems)
    fire("AUCTION_HOUSE_CLOSED")
    advance(1)
    auction_requests, auction_key_requests, auction_queries, commodity_more_requests = {}, {}, {}, {}
    auction_ready, auction_key_info = true, nil
    commodity_results, commodity_total, commodity_full = {}, {}, {}
    ns.db.prices, ns.db.priceScans = {}, {}
    ns.db.scanGuard = { version = "", items = {} }
    ns.db.fishedItems = {}
    bundled, shared = {}, {}
    local function fill(target, items)
        for _, itemID in ipairs(items or {}) do
            target[itemID] = true
            commodity_results[itemID] = { { 100, 10 }, { 110, 10 }, { 120, 10 } }
        end
    end
    fill(ns.db.fishedItems, own)
    fill(bundled, bundledItems)
    fill(shared, sharedItems)
    chat, pricesChanged = {}, 0
    fire("AUCTION_HOUSE_SHOW")
end

-- Scans until the request for `itemID` is sent, answering every earlier one; leaves that one unanswered.
local function scanUntil(itemID)
    ns.Auction.Scan()
    for _ = 1, 50 do
        local request = auction_requests[#auction_requests]
        if request and request.itemID == itemID and not request.answered then
            return
        end
        if request and not request.answered then
            auction_answer()
        end
        advance(1)
    end
    error("no request for " .. itemID)
end

local function searched(itemID)
    for _, id in ipairs(auction_searched()) do
        if id == itemID then
            return true
        end
    end
    return false
end

test("ten seconds without an answer stop the scan, once, keeping the prices found", function()
    fresh({ A, B, C })
    scanUntil(B)
    advance(9)
    eq(ns.Auction.GetState(), "scanning", "still scanning after 9 s")
    eq(chat_count(STALLED:format(1, 3)), 0, "no line yet")
    advance(1.5)
    eq(ns.Auction.GetState(), "stalled", "stalled")
    eq((ns.Auction.GetProgress()), false, "the scan stopped")
    eq(chat_count(STALLED:format(1, 3)), 1, "one chat line")
    eq(ns.db.prices[A].price, 100, "A's price kept")
    eq(pricesChanged, 1, "PRICES_CHANGED once")
    local sent = #auction_requests
    advance(60)
    eq(#auction_requests, sent, "no further request")
    eq(chat_count(STALLED:format(1, 3)), 1, "still one chat line")
end)

test("while stalled no scan starts; the buttons work again once the line is ready", function()
    eq(ns.Auction.CanScan(), false, "cannot scan")
    eq(ns.Auction.WhyNot(), WHY_STALLED, "the reason")
    chat = {}
    local sent = #auction_requests
    ns.Auction.Scan()
    eq(chat_count(WHY_STALLED), 1, "the command prints the reason")
    eq(#auction_requests, sent, "nothing sent")
    local before = states
    auction_ready = true
    fire("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
    eq(ns.Auction.GetState(), "ready", "ready again")
    assert(states > before, "AUCTION_STATE fired")
    eq(ns.Auction.WhyNot(), nil, "no reason")
    advance(1)
    ns.Auction.Scan()
    eq(ns.Auction.GetState(), "scanning", "a scan starts")
end)

test("a line busy for 10 s without a scan is stalled too, without a chat line", function()
    fresh({ A })
    auction_ready = false
    fire("AUCTION_HOUSE_THROTTLED_MESSAGE_SENT") -- another addon's request
    advance(10.5)
    eq(ns.Auction.GetState(), "stalled", "stalled")
    eq(#chat, 0, "no chat line")
    fire("AUCTION_HOUSE_CLOSED")
    auction_ready = false
    fire("AUCTION_HOUSE_SHOW")
    eq(ns.Auction.GetState(), "stalled", "reopened on the still silent line: stalled at once")
    eq(ns.Auction.CanScan(), false, "no scan")
    auction_ready = true
    fire("AUCTION_HOUSE_CLOSED")
    fire("AUCTION_HOUSE_SHOW")
    eq(ns.Auction.GetState(), "ready", "reopened on a ready line")
    fire("AUCTION_HOUSE_CLOSED")
    auction_ready = false
    fire("AUCTION_HOUSE_SHOW")
    eq(ns.Auction.GetState(), "ready", "without an earlier stall a busy line can still start a scan")
    advance(10.5)
    eq(ns.Auction.GetState(), "stalled", "the window opened on a line that stays busy")
end)

test("a scan started on a busy line waits for it, and stops when it stays busy", function()
    fresh({ A, B })
    auction_ready = false
    ns.Auction.Scan()
    eq(ns.Auction.GetState(), "scanning", "scanning")
    eq(#auction_requests, 0, "no request on a busy line")
    advance(5)
    auction_ready = true
    fire("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
    eq(#auction_requests, 1, "the scan runs once the line is ready")
    fresh({ A, B })
    auction_ready = false
    ns.Auction.Scan()
    advance(10.5)
    eq(ns.Auction.GetState(), "stalled", "stalled")
    eq(chat_count(STALLED:format(0, 2)), 1, "the line with nothing found")
    eq(next(ns.db.scanGuard.items), nil, "nothing remembered: the scan sent nothing")
end)

test("a busy line that recovers starts the clock again", function()
    fresh({ A })
    auction_ready = false
    fire("AUCTION_HOUSE_THROTTLED_MESSAGE_SENT")
    advance(9)
    auction_ready = true
    fire("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
    auction_ready = false
    fire("AUCTION_HOUSE_THROTTLED_MESSAGE_SENT")
    advance(9)
    eq(ns.Auction.GetState(), "ready", "no stall")
end)

test("the clock starts at the scan's own send, whatever the line reads then", function()
    fresh({ A, B })
    ns.Auction.Scan()
    auction_ready = true
    fire("AUCTION_HOUSE_THROTTLED_MESSAGE_SENT")
    auction_ready = false
    advance(10.5)
    eq(ns.Auction.GetState(), "stalled", "stalled")
end)

test("closing the window is not a stall", function()
    fresh({ A, B })
    ns.Auction.Scan()
    fire("AUCTION_HOUSE_CLOSED")
    eq(chat_count(L["Auction scan stopped: %d of %d price(s) found."]:format(0, 2)), 1, "the present stopped line")
    eq(ns.Auction.GetState(), "closed", "closed")
    eq(ns.Auction.WhyNot(), L["Open the auction house first."], "the reason")
    advance(60)
    eq(chat_count(STALLED:format(0, 2)), 0, "no stall line")
    eq(#auction_requests, 1, "nothing more sent")
end)

test("the states: closed, ready, scanning", function()
    fire("AUCTION_HOUSE_CLOSED")
    eq(ns.Auction.GetState(), "closed", "before the window opens")
    fresh({ A })
    eq(ns.Auction.GetState(), "ready", "open")
    ns.Auction.Scan()
    eq(ns.Auction.GetState(), "scanning", "during a scan")
end)

-- The guard: the items the auction house did not answer for (User Story 5).

local function ready()
    auction_ready = true
    fire("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
    advance(1)
end

local function stallAt(itemID)
    scanUntil(itemID)
    advance(10.5)
    assert(ns.Auction.GetState() == "stalled", "stalled at " .. itemID)
end

test("the item of the unanswered request is remembered with its group and not asked about again", function()
    fresh({ A, B, C })
    stallAt(B)
    eq(ns.db.scanGuard.items[B], "own", "B remembered as own")
    eq(ns.db.scanGuard.version, ns.version, "with this version")
    ready()
    auction_requests = {}
    ns.Auction.Scan()
    auction_run()
    eq(searched(B), false, "B not searched")
    eq(searched(C), true, "C searched")
end)

test("a busy line without the scan's own request remembers nothing", function()
    fresh({ A })
    auction_ready = false
    fire("AUCTION_HOUSE_THROTTLED_MESSAGE_SENT")
    advance(10.5)
    eq(next(ns.db.scanGuard.items), nil, "nothing remembered")
end)

test("after a shared item, every item known only from other players' records is left out", function()
    local D, S1, S2 = 90004, 90005, 90006
    fresh({ A }, { D }, { S1, S2 })
    stallAt(S1)
    eq(ns.db.scanGuard.items[S1], "shared", "remembered as shared")
    ready()
    ns.db.priceScans = {}
    auction_requests = {}
    ns.Auction.Scan()
    auction_run()
    eq(searched(A) and searched(D), true, "own and bundled searched")
    eq(searched(S1) or searched(S2), false, "no shared item searched")
end)

test("after a bundled item the shared group stays in", function()
    local D, D2, S1 = 90004, 90007, 90005
    fresh({ A }, { D, D2 }, { S1 })
    stallAt(D)
    eq(ns.db.scanGuard.items[D], "bundled", "remembered as bundled")
    ready()
    auction_requests = {}
    ns.Auction.Scan()
    auction_run()
    eq(searched(S1), true, "the shared item searched")
end)

test("an item of the own catches and of other players' records counts as own", function()
    local S1 = 90005
    fresh({ A }, {}, { A, S1 })
    stallAt(A)
    eq(ns.db.scanGuard.items[A], "own", "remembered as own")
    ready()
    auction_requests = {}
    ns.Auction.Scan()
    auction_run()
    eq(searched(S1), true, "the shared group stays in")
end)

test("a late answer forgets the item and takes the shared group back in", function()
    local S1, S2 = 90005, 90006
    fresh({ A }, {}, { S1, S2 })
    stallAt(S1)
    auction_answer() -- the answer to S1's request arrives after all
    eq(ns.db.scanGuard.items[S1], nil, "forgotten")
    advance(1)
    ns.db.priceScans = {}
    auction_requests = {}
    ns.Auction.Scan()
    auction_run()
    eq(searched(S1) and searched(S2), true, "the shared items searched again")
end)

test("another version of the addon forgets what an earlier one remembered", function()
    local S1 = 90005
    fresh({}, {}, { S1 })
    ns.db.scanGuard = { version = "0.0.1", items = { [S1] = "shared" } }
    ns.Auction.Scan()
    auction_run()
    eq(searched(S1), true, "searched again")
    eq(ns.db.scanGuard.version, ns.version, "the guard is this version's")
    eq(ns.db.scanGuard.items[S1], nil, "nothing remembered")
end)

test("closing the window: remembered only when the reopened auction house stays silent", function()
    fresh({ A, B })
    ns.Auction.Scan() -- A's request stays unanswered
    fire("AUCTION_HOUSE_CLOSED")
    eq(next(ns.db.scanGuard.items), nil, "not remembered at the close")
    auction_ready = true
    fire("AUCTION_HOUSE_SHOW")
    advance(20)
    eq(next(ns.db.scanGuard.items), nil, "a ready line at the opening forgets it")
    fresh({ A, B })
    ns.Auction.Scan()
    fire("AUCTION_HOUSE_CLOSED")
    chat = {}
    fire("AUCTION_HOUSE_SHOW") -- the line is still busy
    advance(10.5)
    eq(ns.Auction.GetState(), "stalled", "stalled")
    eq(ns.db.scanGuard.items[A], "own", "remembered")
    eq(#chat, 0, "no chat line: no scan runs")
end)

test("the debug report's lines", function()
    local S1 = 90005
    fresh({ A }, {}, { S1 })
    stallAt(S1)
    local lines = ns.Auction.Describe()
    local pattern = "^auction: stalled; last scan: 2 item%(s%), 2 request%(s%), %d+ s, 1 price%(s%), "
        .. "0 without item info$"
    assert(lines[1]:find(pattern), lines[1])
    eq(lines[2], "auction list: 1 own, 0 bundled, 1 shared, 0 not sellable, 0 fresh", "the list")
    eq(lines[3], "auction guard (" .. ns.version .. "): " .. S1 .. "=shared; other players' items left out: yes",
        "the guard")
    assert(lines[4]:find("^last price scan: "), lines[4])
    ready()
    ns.db.scanGuard.items = {}
    eq(ns.Auction.Describe()[3], "auction guard (" .. ns.version .. "): none; other players' items left out: no",
        "an empty guard")
end)

test("steady answered traffic of another addon is no stall, however long the line reads busy", function()
    fresh({ A, B })
    ns.Auction.Scan()
    auction_answer()
    auction_ready = false
    for _ = 1, 40 do -- 40 s of another addon's requests, one behind the other: the line never reads ready
        fire("AUCTION_HOUSE_THROTTLED_MESSAGE_SENT")
        advance(0.5)
        fire("AUCTION_HOUSE_THROTTLED_MESSAGE_RESPONSE_RECEIVED")
        advance(0.5)
    end
    eq(ns.Auction.GetState(), "scanning", "still scanning, waiting for its turn")
    eq(next(ns.db.scanGuard.items), nil, "nothing remembered")
    auction_ready = true
    fire("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
    eq(#auction_requests, 2, "the scan goes on once the line is free")
end)

test("after a stall the line comes back without a READY event: the next busy sign reads it free", function()
    fresh({ A })
    auction_ready = false
    fire("AUCTION_HOUSE_THROTTLED_MESSAGE_SENT")
    advance(10.5)
    eq(ns.Auction.GetState(), "stalled", "stalled")
    auction_ready = true -- the line is free again, but no READY event comes
    fire("AUCTION_HOUSE_THROTTLED_MESSAGE_SENT") -- someone's next request
    advance(10.5)
    eq(ns.Auction.GetState(), "ready", "ready again")
end)
