-- Auction: looks up the lowest auction price of every item ever caught while fishing.
-- One search query at a time (the auction house throttles queries); each waits for its result
-- event or times out. Prices are stored account-wide in OneKeyFishingDB.prices.
local _, ns = ...
local L = ns.L

local Auction = {}
ns.Auction = Auction

local QUERY_TIMEOUT = 4
local RETRY_DELAY = 0.5

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

local function Finish(itemID, price)
    if itemID ~= current then
        return
    end
    if price and price > 0 then
        ns.db.prices[itemID] = { price = price, time = time() }
        scanned = scanned + 1
    end
    Next()
end

-- Bumped for every queued item, so a timer left from an earlier query (or scan) cannot finish a later one.
local querySerial = 0

local function Send(itemID, serial)
    if not isOpen or serial ~= querySerial then
        return
    end
    if C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady() then
        C_Timer.After(RETRY_DELAY, function() Send(itemID, serial) end)
        return
    end
    C_AuctionHouse.SendSearchQuery(C_AuctionHouse.MakeItemKey(itemID), Sorts(), false)
    C_Timer.After(QUERY_TIMEOUT, function()
        if serial == querySerial then
            Finish(itemID, nil)
        end
    end)
end

function Next()
    querySerial = querySerial + 1
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
    button = CreateFrame("Button", nil, AuctionHouseFrame, "UIPanelButtonTemplate")
    button:SetSize(150, 22)
    button:SetPoint("BOTTOMRIGHT", AuctionHouseFrame, "TOPRIGHT", -24, 2)
    button:SetScript("OnClick", Auction.Scan)
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

ns.RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED", function(_, itemID)
    if itemID ~= current then
        return
    end
    local info = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, 1)
    Finish(itemID, info and info.unitPrice)
end)

ns.RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED", function(_, itemKey)
    if not itemKey or itemKey.itemID ~= current then
        return
    end
    local info = C_AuctionHouse.GetItemSearchResultInfo(itemKey, 1)
    Finish(itemKey.itemID, info and info.buyoutAmount)
end)

ns.RegisterCommand("scan", L["scan auction prices of caught items (auction house must be open)"], Auction.Scan)
