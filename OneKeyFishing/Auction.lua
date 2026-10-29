-- Auction: looks up the auction price of every item ever caught while fishing: the average unit price of the
-- cheapest 20% of all listed pieces, so one lot far below or far above the market does not decide it.
-- One search query at a time (the auction house throttles queries); each waits for its result
-- event or times out. Prices are stored account-wide in OneKeyFishingDB.prices.
local _, ns = ...
local L = ns.L

local Auction = {}
ns.Auction = Auction

local QUERY_TIMEOUT = 4
local RETRY_DELAY = 0.5
local CHEAPEST_SHARE = 0.2 -- of all listed pieces
local MAX_MORE_REQUESTS = 5 -- pages of commodity results asked for per item, before the price uses what came

local isOpen = false
local queue = {}
local current -- itemID being searched
local total, scanned = 0, 0
local button

function Auction.IsOpen()
    return isOpen
end

-- The auction house is open and no scan is running.
function Auction.CanScan()
    return isOpen and current == nil
end

local function Sorts()
    if Enum and Enum.AuctionHouseSortOrder then
        return { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }
    end
    return {}
end

local function ItemsToScan()
    local set, list = {}, {}
    for itemID in pairs(ns.db.fishedItems) do
        set[itemID] = true
    end
    for itemID in pairs(ns.charDB.stats.total.items) do
        set[itemID] = true
    end
    for itemID in pairs(set) do
        table.insert(list, itemID)
    end
    table.sort(list)
    return list
end

local function UpdateButton()
    if not button then
        return
    end
    if current then
        button:SetText((L["Scanning %d/%d"]):format(total - #queue, total))
        button:Disable()
    else
        button:SetText(L["Scan fish prices"])
        button:Enable()
    end
end

local function NotifyState()
    UpdateButton()
    ns.Fire("AUCTION_STATE")
end

local Next

-- Pieces loaded / pieces listed of the last result, for /okf debug.
local coverage

function Auction.GetCoverage()
    return coverage
end

-- lots: the auctions the price was taken from; then the results of RobustPrice.
local function Finish(itemID, lots, price, total, loaded)
    if itemID ~= current then
        return
    end
    if loaded then
        coverage = { loaded = loaded, total = total }
    end
    if price and price > 0 then
        -- quantity: the pieces the price could see (listed, but not more than were loaded)
        ns.db.prices[itemID] = { price = price, quantity = loaded, lots = lots, time = time() }
        scanned = scanned + 1
    end
    Next()
end

-- listings: { { unitPrice, quantity }, ... } in any order; total: the pieces listed (more may be listed than
-- loaded). Returns the average unit price of the cheapest CHEAPEST_SHARE of the listed pieces (nil without
-- listings), the pieces listed and the pieces loaded. The price is stored with the pieces it could see
-- (listed, but not more than loaded), so a price from a few loaded pieces is marked as few lots.
local function RobustPrice(listings, total)
    table.sort(listings, function(a, b) return a[1] < b[1] end)
    local loaded = 0
    for _, listing in ipairs(listings) do
        loaded = loaded + listing[2]
    end
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

-- Bumped for every queued item, so a timer left from an earlier query (or scan) cannot finish a later one.
local querySerial = 0
local partial -- { listings, total } of the current item while more commodity results are on their way
local moreRequests = 0
local timeoutToken -- the newest wait; a timer of an earlier one does nothing

-- lots: the result rows on sale (price points; several sellers at one price share a row).
local function Settle(itemID, listings, total)
    Finish(itemID, #listings, RobustPrice(listings, total))
end

-- Waits QUERY_TIMEOUT for the query or the next page of results; then the pages that came decide.
local function StartTimeout(itemID)
    local token = {}
    timeoutToken = token
    C_Timer.After(QUERY_TIMEOUT, function()
        if timeoutToken ~= token or itemID ~= current then
            return
        end
        if partial then
            Settle(itemID, partial.listings, partial.total)
        else
            Finish(itemID, 0, nil)
        end
    end)
end

local function Send(itemID, serial)
    if not isOpen or serial ~= querySerial then
        return
    end
    if C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady() then
        C_Timer.After(RETRY_DELAY, function() Send(itemID, serial) end)
        return
    end
    C_AuctionHouse.SendSearchQuery(C_AuctionHouse.MakeItemKey(itemID), Sorts(), false)
    StartTimeout(itemID)
end

function Next()
    querySerial = querySerial + 1
    partial, moreRequests, timeoutToken = nil, 0, nil
    current = table.remove(queue, 1)
    NotifyState()
    if current then
        Send(current, querySerial)
    else
        ns.Print(L["Auction scan finished: %d of %d price(s) found."], scanned, total)
        ns.Fire("PRICES_CHANGED")
    end
end

function Auction.Scan()
    if not isOpen then
        ns.Print(L["Open the auction house first."])
        return
    end
    if current then
        return
    end
    wipe(queue)
    for _, itemID in ipairs(ItemsToScan()) do
        table.insert(queue, itemID)
    end
    total, scanned = #queue, 0
    if total == 0 then
        ns.Print(L["Nothing to scan yet: catch some fish first."])
        return
    end
    ns.Print(L["Scanning auction prices of %d item(s)..."], total)
    Next()
end

-- Button above the top right corner of the auction house window.
local function EnsureButton()
    if button or not AuctionHouseFrame then
        return
    end
    button = ns.CreateButton(AuctionHouseFrame, "", 150, Auction.Scan)
    -- Wide enough for the longest text it shows, so it keeps its size while the count goes up.
    for _, text in ipairs({ L["Scan fish prices"], (L["Scanning %d/%d"]):format(999, 999) }) do
        button:SetText(text)
        button.minWidth = button:GetWidth() or button.minWidth
    end
    button:SetPoint("BOTTOMRIGHT", AuctionHouseFrame, "TOPRIGHT", -24, 2)
    UpdateButton()
end

ns.RegisterEvent("AUCTION_HOUSE_SHOW", function()
    isOpen = true
    EnsureButton()
    NotifyState()
end)

ns.RegisterEvent("AUCTION_HOUSE_CLOSED", function()
    isOpen = false
    querySerial = querySerial + 1 -- a retry or timeout of the stopped scan must not run after reopening
    local stopped = current ~= nil
    if stopped then
        ns.Print(L["Auction scan stopped: %d of %d price(s) found."], scanned, total)
    end
    wipe(queue)
    current = nil
    NotifyState()
    if stopped then
        ns.Fire("PRICES_CHANGED") -- the prices found so far
    end
end)

-- The results are sorted here: their order is not documented. While the game says more results exist, the next
-- page is asked for (up to MAX_MORE_REQUESTS, each with its own wait, only when the server takes requests); the
-- price uses all pages, or what came when a wait times out. The first results come as UPDATED, later pages as ADDED.
-- VERIFY(V4): each result has unitPrice and quantity; GetCommoditySearchResultsQuantity is the total listed;
-- HasFullCommoditySearchResults / RequestMoreCommoditySearchResults page the results
local function OnCommodityResults(_, itemID)
    if itemID ~= current then
        return
    end
    local listings = {}
    for index = 1, C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0 do
        local info = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, index)
        if info and info.unitPrice and info.quantity and info.quantity > 0 then
            table.insert(listings, { info.unitPrice, info.quantity })
        end
    end
    local total = C_AuctionHouse.GetCommoditySearchResultsQuantity(itemID)
    local ready = not C_AuctionHouse.IsThrottledMessageSystemReady or C_AuctionHouse.IsThrottledMessageSystemReady()
    if C_AuctionHouse.HasFullCommoditySearchResults and not C_AuctionHouse.HasFullCommoditySearchResults(itemID)
        and C_AuctionHouse.RequestMoreCommoditySearchResults and moreRequests < MAX_MORE_REQUESTS and ready then
        partial = { listings = listings, total = total }
        moreRequests = moreRequests + 1
        C_AuctionHouse.RequestMoreCommoditySearchResults(itemID)
        StartTimeout(itemID)
        return
    end
    Settle(itemID, listings, total)
end
ns.RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED", OnCommodityResults)
ns.RegisterEvent("COMMODITY_SEARCH_RESULTS_ADDED", OnCommodityResults)

-- VERIFY(V5): buyoutAmount is the price of the whole auction (all its pieces); bid-only auctions have none
ns.RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED", function(_, itemKey)
    if not itemKey or itemKey.itemID ~= current then
        return
    end
    local listings = {}
    for index = 1, C_AuctionHouse.GetNumItemSearchResults(itemKey) or 0 do
        local info = C_AuctionHouse.GetItemSearchResultInfo(itemKey, index)
        local quantity = info and info.quantity or 0
        if info and info.buyoutAmount and info.buyoutAmount > 0 and quantity > 0 then
            table.insert(listings, { info.buyoutAmount / quantity, quantity })
        end
    end
    Settle(itemKey.itemID, listings)
end)
