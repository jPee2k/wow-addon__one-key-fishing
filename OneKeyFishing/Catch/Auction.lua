-- Auction: looks up the auction price of the items the player can catch: the average unit price of the cheapest
-- 20% of all listed pieces, so one lot far below or far above the market does not decide it. Prices are stored
-- account-wide in OneKeyFishingDB.prices (specs/018-auction-scan).
-- The scan sends one request at a time, only while the game's request line is ready and not sooner than
-- MIN_INTERVAL after its previous one; it searches an item only once the game holds the item's key info, asks for
-- further result pages only while the price is still open, and leaves out items that cannot be sold.
-- What the game showed (docs/forever-api.md, "The auction house's request system"): a request is answered in 0.2 s
-- and the line is ready 0.5 s after the send; a request the server never answers keeps the line busy until the
-- character logs out and in. Never call C_AuctionHouse.SearchForItemKeys: the server does not answer it.
local _, ns = ...
local L = ns.L

local Auction = {}
ns.Auction = Auction

local CHEAPEST_SHARE = 0.2 -- of all listed pieces
local MAX_MORE_REQUESTS = 5 -- result pages asked for per item, before the price uses what came
-- A request every 0.6 s, the documented 100 a minute, is answered (V57, measured 2026-11-18: scans of 68 and 72
-- items in a row, every request answered, no stall).
local MIN_INTERVAL = 0.6 -- seconds between two requests of the scan (search or page)
local INFO_WAIT = 3 -- seconds the scan waits for missing item key infos once nothing else is left
local RESULT_WAIT = 3 -- seconds an answered request may take for its result before its item is skipped
local RECHECK = 1 -- seconds between two readings of a busy line while the scan waits (a missed READY event)
local ANSWER_TIMEOUT = 10 -- seconds of a busy line before the auction house counts as not answering
local FRESH_SECONDS = 15 * 60 -- a price scanned this recently is not searched again (unless every price is)

local isOpen = false
local itemSource -- set by CatchDB (layer 2): returns the bundled database's items and other players' items

-- The scan in memory (data-model.md "The scan in memory"); nothing of it survives a reload.
local scanning = false
local queue = {} -- the item IDs left, in the scan's order
local info = {} -- itemID -> the item key info, asked once at the start and read again only on the item's event
local total, done, found = 0, 0, 0
local current -- the item whose request is in flight or whose result is awaited
local unanswered = false -- the scan's request got neither its response nor its result yet
local wantsMore = false -- current needs its next result page, asked at the next turn
local partial -- { listings, total } of current while further pages are on their way
local moreRequests = 0
local lastSendAt = -math.huge
local turnToken, waitToken, infoToken -- the newest timer of each kind; an older one does nothing
local stats = { searched = 0, requests = 0, started = 0, seconds = 0, found = 0, noInfo = 0 }

-- The line, followed while the window is open, scan or no scan (research R3; data-model.md "States").
local busySince -- GetTime() when the line was first marked busy; nil while it is free
local busyToken -- the newest 10 s timer
local stalled = false -- busy for ANSWER_TIMEOUT without a break: the auction house does not answer
local outstanding -- { itemID, group } of the scan's request without an answer; kept after the scan stops

function Auction.IsOpen()
    return isOpen
end

-- "closed", "ready" (a scan can start; the line may be busy for less than ANSWER_TIMEOUT), "scanning" or
-- "stalled" (the auction house does not answer).
function Auction.GetState()
    if not isOpen then
        return "closed"
    elseif stalled then
        return "stalled"
    end
    return scanning and "scanning" or "ready"
end

-- The one "can scan now" rule of every scan button and the scan command. Never while the prices come from
-- Auctionator (specs/019-auctionator-prices): the addon then sends no auction request at all.
function Auction.CanScan()
    return Auction.GetState() == "ready" and not ns.Prices.UsesAuctionator()
end

-- The reason a scan cannot start, in the addon's language; nil when it can or one is running.
function Auction.WhyNot()
    if ns.Prices.UsesAuctionator() then
        return L["Prices come from Auctionator."]
    end
    local state = Auction.GetState()
    if state == "closed" then
        return L["Open the auction house first."]
    elseif state == "stalled" then
        return L["The auction house does not answer. Log out and back in to bring it back."]
    end
end

-- The scan's progress for the scan buttons: scanning, items done, items in all.
function Auction.GetProgress()
    return scanning, done, total
end

-- fn() returns two sets (itemID -> true): the items of the bundled catch database and the items of other players'
-- records. Set by CatchDB/Views.lua; nil: the own catches only.
function Auction.SetItemSource(fn)
    itemSource = fn
end

local function NotifyState()
    ns.Fire("AUCTION_STATE")
end

-- Pieces loaded / pieces listed of the last result, for /okf debug.
local coverage

function Auction.GetCoverage()
    return coverage
end

local function Sorts()
    if Enum and Enum.AuctionHouseSortOrder then
        return { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }
    end
    return {}
end

local function IsItemID(value)
    return type(value) == "number" and value > 0 and math.floor(value) == value
end

-- The groups of the scan's list, in their order (FR-006): the own catches, the bundled catch database, the items
-- known only from other players' records.
local GROUP_RANK = { own = 1, bundled = 2, shared = 3 }
local groupOf = {} -- itemID -> its group in the last list
local listCounts = { own = 0, bundled = 0, shared = 0, unsellable = 0, fresh = 0 }

-- The items the auction house did not answer for (research R8): itemID -> its group, kept for the account until the
-- addon runs as another version; one of other players' records leaves all of their items out.
local function Guard()
    local guard = ns.db.scanGuard
    if type(guard) ~= "table" then
        guard = {}
        ns.db.scanGuard = guard
    end
    if type(guard.items) ~= "table" then
        guard.items = {}
    end
    if guard.version ~= ns.version then
        guard.version = ns.version
        wipe(guard.items)
    end
    return guard
end

local function LeavesOutShared(guard)
    for _, group in pairs(guard.items) do
        if group == "shared" then
            return true
        end
    end
    return false
end

-- When the item was last answered: the later of its scan time and its stored price's time (prices of earlier
-- versions have only the second); 0 for never.
local function ScanTime(itemID)
    local price = ns.db.prices[itemID]
    return math.max(ns.db.priceScans[itemID] or 0, type(price) == "table" and tonumber(price.time) or 0)
end

-- The bundled database's items and other players' items from the item source; empty sets when it fails.
local function SourceItems()
    if not itemSource then
        return {}, {}
    end
    local ok, bundled, shared = ns.Safe("Auction item source", itemSource)
    if not ok then
        return {}, {}
    end
    return type(bundled) == "table" and bundled or {}, type(shared) == "table" and shared or {}
end

-- The items one scan searches, in its order (data-model.md "The scan list").
local function BuildList()
    wipe(groupOf)
    local function Add(set, group)
        for itemID in pairs(set) do
            if groupOf[itemID] == nil and IsItemID(itemID) then
                groupOf[itemID] = group
            end
        end
    end
    Add(ns.db.fishedItems, "own")
    Add(ns.Stats.GetTotal().items, "own")
    local bundled, shared = SourceItems()
    Add(bundled, "bundled")
    Add(shared, "shared")
    local list = {}
    listCounts.own, listCounts.bundled, listCounts.shared, listCounts.unsellable = 0, 0, 0, 0
    local guard = Guard()
    local skipShared = LeavesOutShared(guard)
    for itemID, group in pairs(groupOf) do
        if ns.GameData.AuctionUnanswered[itemID] then
            groupOf[itemID] = nil -- the server never answers a search for it (GameData/AuctionUnanswered.lua)
        elseif guard.items[itemID] or (group == "shared" and skipShared) then
            groupOf[itemID] = nil -- left out (FR-017, FR-018)
        elseif C_Item.GetItemInfoInstant(itemID) ~= nil then
            -- Bound items cannot be listed (V54, accepted); a poor quality item and one not loaded yet are searched:
            -- the rule is Prices.CanAuction, shared with the counts of the own catches.
            if not ns.Prices.CanAuction(itemID) then
                listCounts.unsellable = listCounts.unsellable + 1
            else
                table.insert(list, itemID)
                listCounts[group] = listCounts[group] + 1
            end
        end
    end
    local times = {}
    for _, itemID in ipairs(list) do
        times[itemID] = ScanTime(itemID)
    end
    -- The group, then the oldest scan first (never scanned before all), then the item ID.
    table.sort(list, function(a, b)
        local rankA, rankB = GROUP_RANK[groupOf[a]], GROUP_RANK[groupOf[b]]
        if rankA ~= rankB then
            return rankA < rankB
        elseif times[a] ~= times[b] then
            return times[a] < times[b]
        end
        return a < b
    end)
    local now, stale = time(), {}
    for _, itemID in ipairs(list) do
        if now - times[itemID] >= FRESH_SECONDS then
            table.insert(stale, itemID)
        end
    end
    listCounts.fresh = #list - #stale
    if #stale == 0 then
        return list -- every price is fresh: the press scans them all again
    end
    return stale
end

-- The pieces of the loaded listings.
local function Loaded(listings)
    local loaded = 0
    for _, listing in ipairs(listings) do
        loaded = loaded + listing[2]
    end
    return loaded
end

-- listings: { { unitPrice, quantity }, ... } in any order; total: the pieces listed (more may be listed than
-- loaded). Returns the average unit price of the cheapest CHEAPEST_SHARE of the listed pieces (nil without
-- listings), the pieces listed and the pieces loaded. The price is stored with the pieces it could see
-- (listed, but not more than loaded), so a price from a few loaded pieces is marked as few lots.
local function RobustPrice(listings, total)
    table.sort(listings, function(a, b) return a[1] < b[1] end)
    local loaded = Loaded(listings)
    total = math.max(total or 0, loaded)
    local wanted = math.max(1, math.ceil(total * CHEAPEST_SHARE))
    local taken, sum = 0, 0
    for _, listing in ipairs(listings) do
        local take = math.min(listing[2], wanted - taken)
        if take <= 0 then
            break
        end
        sum = sum + take * listing[1]
        taken = taken + take
    end
    if taken == 0 then
        return nil, total, loaded
    end
    return math.floor(sum / taken + 0.5), total, loaded
end

-- True when the loaded listings decide the price and its few-lots mark as every page would (research R4): they
-- cover the cheapest share of the listed pieces, and hold enough pieces and rows not to be few lots. With every page
-- loaded both counts can only grow, so a price that would be marked is never decided early.
-- With the price sort a later page holds no cheaper row than the loaded ones (V55, measured 2026-11-18: 4750
-- pieces in 48 rows, ascending to the end; the price equal to the one of the whole list).
local function PriceDecided(listings, listed)
    local loaded = Loaded(listings)
    local wanted = math.max(1, math.ceil(math.max(listed or 0, loaded) * CHEAPEST_SHARE))
    return loaded >= wanted and loaded >= ns.Prices.FEW_PIECES and #listings >= ns.Prices.FEW_LOTS
end

local Pump, MarkBusy

-- The scan's next turn in `delay` seconds; only the newest such timer acts.
local function ScheduleTurn(delay)
    local token = {}
    turnToken = token
    C_Timer.After(delay, function()
        if turnToken == token then
            turnToken = nil
            Pump()
        end
    end)
end

-- The item is done: its result decided (with or without a price) or it was skipped (no result: no scan time).
local function NextItem()
    current, partial, wantsMore, moreRequests, waitToken = nil, nil, false, 0, nil
    done = done + 1
    NotifyState()
    Pump()
end

-- lots: the result rows the price was taken from (price points; several sellers at one price share a row).
local function Settle(itemID, listings, listed)
    local price, seen, loaded = RobustPrice(listings, listed)
    if loaded then
        coverage = { loaded = loaded, total = seen }
    end
    if price and price > 0 then
        -- quantity: the pieces the price could see (listed, but not more than were loaded)
        ns.db.prices[itemID] = { price = price, quantity = loaded, lots = #listings, time = time() }
        found = found + 1
    end
    ns.db.priceScans[itemID] = time() -- answered, with a price or not on sale: an earlier price stays
    NextItem()
end

-- No result for the answered request within RESULT_WAIT: the pages that came decide, else the item is skipped.
local function StartResultWait()
    local token, itemID = {}, current
    waitToken = token
    C_Timer.After(RESULT_WAIT, function()
        if waitToken ~= token or current ~= itemID or not scanning then
            return
        end
        if partial then
            Settle(itemID, partial.listings, partial.total)
        else
            NextItem()
        end
    end)
end

-- Ends the scan's state; the last scan's time and count are taken only from a scan that ran, so closing the window
-- after a finished scan keeps them.
local function StopScan()
    if scanning then
        stats.seconds = math.floor(GetTime() - stats.started + 0.5)
        stats.found = found
    end
    scanning, unanswered, wantsMore, partial = false, false, false, nil
    current, turnToken, waitToken, infoToken = nil, nil, nil, nil
    wipe(queue)
end

local function Finish()
    StopScan()
    ns.Print(L["Auction scan finished: %d of %d price(s) found."], found, total)
    NotifyState()
    ns.Fire("PRICES_CHANGED")
end

local function Send(itemID, request)
    lastSendAt = GetTime()
    stats.requests = stats.requests + 1
    unanswered, waitToken = true, nil
    outstanding = { itemID = itemID, group = groupOf[itemID] or "own" }
    MarkBusy(true) -- the line was ready a moment ago: the clock starts at this send, without a reading
    request(itemID)
end

local function SendSearch(itemID)
    C_AuctionHouse.SendSearchQuery(C_AuctionHouse.MakeItemKey(itemID), Sorts(), false)
end

local function SendMore(itemID)
    C_AuctionHouse.RequestMoreCommoditySearchResults(itemID)
end

-- The first queued item with its item key info, removed from the queue.
local function TakeReady()
    local index = 1
    while queue[index] do
        local itemID = queue[index]
        local keyInfo = info[itemID]
        if keyInfo then
            table.remove(queue, index)
            return itemID
        else
            index = index + 1
        end
    end
end

-- True when a queued item has its item key info (TakeReady would take it); removes nothing.
local function HasReady()
    for _, itemID in ipairs(queue) do
        if info[itemID] then
            return true
        end
    end
    return false
end

-- Only items without their info are left: they get INFO_WAIT, then the scan ends without them.
local function StartInfoWait()
    if infoToken then
        return
    end
    local token = {}
    infoToken = token
    C_Timer.After(INFO_WAIT, function()
        if infoToken ~= token or not scanning then
            return
        end
        infoToken = nil
        if current == nil and not HasReady() then
            stats.noInfo = #queue
            done = done + #queue
            wipe(queue)
            Finish()
        else
            Pump()
        end
    end)
end

-- The scan's turn: sends its next request when the line is free for it (research R2).
function Pump()
    if not (isOpen and scanning) or unanswered or stalled then
        return
    end
    if current and not wantsMore then
        return -- the result of the answered request is on its way
    end
    if not C_AuctionHouse.IsThrottledMessageSystemReady() then
        MarkBusy()
        ScheduleTurn(RECHECK) -- the READY event comes as a rule; this covers one that was missed
        return
    end
    local wait = MIN_INTERVAL - (GetTime() - lastSendAt)
    if wait > 0.001 then -- a timer may fire a hair early
        ScheduleTurn(wait)
        return
    end
    if current then
        wantsMore = false
        moreRequests = moreRequests + 1
        Send(current, SendMore)
        return
    end
    local itemID = TakeReady()
    if itemID then
        infoToken = nil
        current = itemID
        stats.searched = stats.searched + 1
        Send(itemID, SendSearch)
    elseif queue[1] then
        StartInfoWait()
    else
        Finish()
    end
end

function Auction.Scan()
    local why = Auction.WhyNot()
    if why then
        ns.Print("%s", why)
        return
    end
    if scanning then
        return
    end
    queue = BuildList()
    if #queue == 0 then
        ns.Print(L["Nothing to scan yet: catch some fish first."])
        return
    end
    total, done, found = #queue, 0, 0
    current, unanswered, wantsMore, partial, moreRequests = nil, false, false, nil, 0
    stats.searched, stats.requests, stats.noInfo, stats.started = 0, 0, 0, GetTime()
    wipe(info)
    -- The item key info of the whole list is asked at once and arrives without a throttled message (V56, measured
    -- 2026-11-18: 68 and 72 items, one request per item, none without its info).
    -- A call for a missing key asks the server again, so it is made once per item here and again only on the
    -- item's ITEM_KEY_ITEM_INFO_RECEIVED.
    for _, itemID in ipairs(queue) do
        info[itemID] = C_AuctionHouse.GetItemKeyInfo(C_AuctionHouse.MakeItemKey(itemID))
    end
    scanning = true
    ns.Print(L["Scanning auction prices of %d item(s)..."], total)
    NotifyState()
    Pump()
end

-- The scan's request got its answer.
local function Answered()
    if scanning and unanswered then
        unanswered = false
        if current and not wantsMore then
            StartResultWait()
        end
    end
end

-- The line is free (a ready reading at READY, a response, DROPPED, the window's opening or the 10 s timer).
local function FreeLine()
    busySince, busyToken = nil, nil
    if stalled then
        stalled = false
        NotifyState()
    end
end

-- The scan's request was answered for real (a response or its result): nothing to blame, and an item remembered
-- for it was only slow (FR-017).
local function Responded()
    if outstanding then
        Guard().items[outstanding.itemID] = nil
        outstanding = nil
    end
    Answered()
end

-- The line has been busy for ANSWER_TIMEOUT: the auction house does not answer. The scan stops and keeps its
-- prices; the item of the scan's unanswered request is the one to blame (research R3).
local function Stall()
    stalled = true
    if outstanding then
        Guard().items[outstanding.itemID] = outstanding.group
    end
    if not scanning then
        NotifyState()
        return
    end
    StopScan()
    ns.Print(
        L["Auction scan stopped: the auction house does not answer (%d of %d price(s) found). Log out and back in."],
        found, total)
    NotifyState()
    ns.Fire("PRICES_CHANGED") -- the prices found so far
end

-- Marks the line busy and starts its clock (restart: the scan's own send starts it again). The timer reads the line
-- when it fires: busy, the auction house does not answer; ready, the line came back without an event, and a request
-- of the scan still without its response counts as answered without a result.
function MarkBusy(restart)
    if busySince and not restart then
        return
    end
    busySince = GetTime()
    local token = {}
    busyToken = token
    C_Timer.After(ANSWER_TIMEOUT, function()
        if busyToken ~= token or not isOpen then
            return
        end
        if C_AuctionHouse.IsThrottledMessageSystemReady() then
            FreeLine()
            outstanding = nil
            Answered()
            Pump()
        else
            -- The clock is spent: the next busy sign starts a new one, whose reading can end the stall even when
            -- the game misses its READY event.
            busySince, busyToken = nil, nil
            Stall()
        end
    end)
end

-- Lines for /okf debug (English, item IDs and counts only).
function Auction.Describe()
    -- Read only: an earlier version's guard counts as empty here and is emptied by the next scan.
    local saved = ns.db.scanGuard
    local valid = type(saved) == "table" and saved.version == ns.version and type(saved.items) == "table"
    local guard = { items = valid and saved.items or {} }
    local ids = {}
    for itemID in pairs(guard.items) do
        table.insert(ids, itemID)
    end
    table.sort(ids)
    local remembered = {}
    for _, itemID in ipairs(ids) do
        table.insert(remembered, itemID .. "=" .. tostring(guard.items[itemID]))
    end
    -- While a scan runs, its own time and prices so far, like its items and requests.
    local seconds, prices = stats.seconds, stats.found
    if scanning then
        seconds, prices = math.floor(GetTime() - stats.started + 0.5), found
    end
    return {
        ("auction: %s; last scan: %d item(s), %d request(s), %d s, %d price(s), %d without item info"):format(
            Auction.GetState(), stats.searched, stats.requests, seconds, prices, stats.noInfo),
        ("auction list: %d own, %d bundled, %d shared, %d not sellable, %d fresh"):format(listCounts.own,
            listCounts.bundled, listCounts.shared, listCounts.unsellable, listCounts.fresh),
        ("auction guard (%s): %s; other players' items left out: %s"):format(tostring(ns.version),
            #remembered > 0 and table.concat(remembered, ", ") or "none", LeavesOutShared(guard) and "yes" or "no"),
        ("last price scan: %s of %s listed pieces loaded"):format(tostring(coverage and coverage.loaded),
            tostring(coverage and coverage.total)),
    }
end

ns.RegisterEvent("AUCTION_HOUSE_SHOW", function()
    isOpen = true
    if C_AuctionHouse.IsThrottledMessageSystemReady() then
        FreeLine()
        outstanding = nil -- a request left from a closed window was answered after all
    else
        MarkBusy() -- a stall seen before the window closed stays: a jam outlives the window (docs/forever-api.md)
    end
    NotifyState()
end)

-- Prices saved before rule 2 divided a non-commodity's price by the pieces of its row (V5, found wrong 2026-11-18);
-- a saved price does not say which kind of item it was, so every one is dropped once and the next scan brings
-- them back. An item not on sale at that scan would otherwise keep its wrong price for good.
local PRICE_RULE = 2
ns.RegisterEvent("PLAYER_LOGIN", function()
    if ns.db.priceRule ~= PRICE_RULE then
        wipe(ns.db.prices)
        wipe(ns.db.priceScans)
        ns.db.priceRule = PRICE_RULE
    end
end)

ns.RegisterEvent("AUCTION_HOUSE_CLOSED", function()
    isOpen = false
    busySince, busyToken = nil, nil -- stalled stays until a ready reading at the next opening
    local stopped = scanning
    StopScan()
    if stopped then
        ns.Print(L["Auction scan stopped: %d of %d price(s) found."], found, total)
    end
    NotifyState()
    if stopped then
        ns.Fire("PRICES_CHANGED") -- the prices found so far
    end
end)

ns.RegisterEvent("ITEM_KEY_ITEM_INFO_RECEIVED", function(_, itemID)
    if scanning and info[itemID] == nil then
        for _, queued in ipairs(queue) do
            if queued == itemID then
                info[itemID] = C_AuctionHouse.GetItemKeyInfo(C_AuctionHouse.MakeItemKey(itemID))
                Pump()
                return
            end
        end
    end
end)

-- The line's events (research R2, R3). A ready reading counts only at READY, a response and DROPPED (besides the
-- window's opening and MarkBusy's timer): whether the game switches the line inside the send or a moment later was
-- not measured, so SENT and QUEUED never free it.
ns.RegisterEvent("AUCTION_HOUSE_THROTTLED_MESSAGE_RESPONSE_RECEIVED", function()
    if C_AuctionHouse.IsThrottledMessageSystemReady() then
        FreeLine()
    elseif isOpen then
        -- The server answers: the clock starts again. A jam sends no response, while steady answered traffic
        -- (another addon's queue, Auctionator's scan) may never let the line read ready between its requests.
        MarkBusy(true)
    end
    Responded()
    Pump()
end)

local function LineTookBack()
    if C_AuctionHouse.IsThrottledMessageSystemReady() then
        FreeLine()
        -- Ready again while the scan's request has no response: an answer without a result, nothing to blame.
        outstanding = nil
        Answered()
        Pump()
    elseif isOpen then
        MarkBusy()
    end
end
ns.RegisterEvent("AUCTION_HOUSE_THROTTLED_SYSTEM_READY", LineTookBack)
ns.RegisterEvent("AUCTION_HOUSE_THROTTLED_MESSAGE_DROPPED", LineTookBack)

-- A request is on its way (the scan's own, another addon's, the player's): the line is busy, whatever it reads,
-- since the game may not have switched it yet.
local function LineTaken()
    if isOpen then
        MarkBusy()
    end
end
ns.RegisterEvent("AUCTION_HOUSE_THROTTLED_MESSAGE_SENT", LineTaken)
ns.RegisterEvent("AUCTION_HOUSE_THROTTLED_MESSAGE_QUEUED", LineTaken)

-- The results are sorted here: their order is not documented. While the price is open and the game says more
-- results exist, the next page is asked for at the scan's turn (up to MAX_MORE_REQUESTS). The first results come as
-- UPDATED, later pages as ADDED. Each result has unitPrice and quantity; GetCommoditySearchResultsQuantity is the
-- total listed; HasFullCommoditySearchResults / RequestMoreCommoditySearchResults page the results (V4, seen in game)
local function OnCommodityResults(_, itemID)
    if not scanning or itemID ~= current or wantsMore then
        return
    end
    Responded()
    local listings = {}
    for index = 1, C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0 do
        local result = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, index)
        if result and result.unitPrice and result.quantity and result.quantity > 0 then
            table.insert(listings, { result.unitPrice, result.quantity })
        end
    end
    local listed = C_AuctionHouse.GetCommoditySearchResultsQuantity(itemID)
    local full = not C_AuctionHouse.HasFullCommoditySearchResults
        or C_AuctionHouse.HasFullCommoditySearchResults(itemID)
    if full or moreRequests >= MAX_MORE_REQUESTS or PriceDecided(listings, listed) then
        Settle(itemID, listings, listed)
        return
    end
    partial = { listings = listings, total = listed }
    wantsMore, waitToken = true, nil
    Pump()
end
ns.RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED", OnCommodityResults)
ns.RegisterEvent("COMMODITY_SEARCH_RESULTS_ADDED", OnCommodityResults)

-- A result row is a group of equal auctions of one piece each: buyoutAmount is the price of one piece and quantity
-- the number of them (V5, measured 2026-11-18: 53 Pound Yellowtail, 7 at 56s 85c in one row). Bid-only auctions
-- have no buyoutAmount.
ns.RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED", function(_, itemKey)
    if not scanning or not itemKey or itemKey.itemID ~= current then
        return
    end
    Responded()
    local listings = {}
    for index = 1, C_AuctionHouse.GetNumItemSearchResults(itemKey) or 0 do
        local result = C_AuctionHouse.GetItemSearchResultInfo(itemKey, index)
        local quantity = result and result.quantity or 0
        if result and result.buyoutAmount and result.buyoutAmount > 0 and quantity > 0 then
            table.insert(listings, { result.buyoutAmount, quantity })
        end
    end
    Settle(itemKey.itemID, listings)
end)
