-- Prices: value of a caught item, in copper.
-- The higher of the vendor price and the auction price (when auction prices are enabled). The auction price has two
-- sources (specs/019-auctionator-prices): Auctionator's public API when that addon is installed and its switch is on,
-- else the addon's own scan (Auction.lua). An item Auctionator has no price for falls back to the own scanned price.
-- An own price based on fewer than FEW_PIECES pieces or FEW_LOTS result rows on sale ("few lots") is shown with a
-- mark but not used for values: one seller's stack alone does not make a market price. Auctionator's price (its
-- cheapest lot) has no such count and is used as it is.
local _, ns = ...

local Prices = {}
ns.Prices = Prices

Prices.FEW_PIECES = 5 -- pieces the price saw
Prices.FEW_LOTS = 3 -- result rows (price points) on sale; both also decide when the scan stops paging (Auction.lua)

---------------------------------------------------------------------------
-- Auctionator (optional): only its public Auctionator.API.v1, every call in pcall, nothing of its data kept
---------------------------------------------------------------------------
local CALLER = "OneKeyFishing" -- the caller's name its API asks for
local NOTICE_DELAY = 0.5 -- seconds: a burst of its update notices gives one PRICES_CHANGED

local failure -- the message of the first failing call this session: Auctionator then counts as not installed
local pending = false -- a PRICES_CHANGED of a notice is on its way

-- Its API table, read at each call (never while the files load): the addon may be missing, disabled for this
-- character, or of another shape.
local function API()
    local addon = Auctionator
    if type(addon) ~= "table" or type(addon.API) ~= "table" or type(addon.API.v1) ~= "table" then
        return nil
    end
    return addon.API.v1
end

-- Both functions the addon needs are there, and none of its calls failed this session.
function Prices.HasAuctionator()
    local api = not failure and API()
    if not api then
        return false
    end
    return type(api.GetAuctionPriceByItemID) == "function" and type(api.RegisterForDBUpdate) == "function"
end

-- The message of the first failing call this session, or nil.
function Prices.GetAuctionatorFailure()
    return failure
end

-- Auction prices come from Auctionator right now.
function Prices.UsesAuctionator()
    local settings = ns.db.settings
    return settings.auctionPrices == true and settings.auctionatorPrices == true and Prices.HasAuctionator()
end

-- "off" (no auction prices), "auctionator" or "own" (the addon's scan).
function Prices.GetSource()
    if not ns.db.settings.auctionPrices then
        return "off"
    end
    return Prices.UsesAuctionator() and "auctionator" or "own"
end

-- The one way to change the two switches (CLAUDE.md): each fires SETTINGS_CHANGED with its key when it changed.
local function SetSetting(key, on)
    on = on == true
    if ns.db.settings[key] == on then
        return
    end
    ns.db.settings[key] = on
    ns.Fire("SETTINGS_CHANGED", key)
end

function Prices.SetAuctionPrices(on)
    SetSetting("auctionPrices", on)
end

function Prices.SetAuctionator(on)
    SetSetting("auctionatorPrices", on)
end

-- A lookup by a number fails only when its API changed or broke, so every later call would fail too: the first
-- failure is logged once, and the addon's own scan and prices are back until the next login. The views follow
-- PRICES_CHANGED, sent on the next frame: a price is often read in the middle of a redraw.
local function Fail(err)
    if failure then
        return
    end
    failure = tostring(err)
    ns.Safe("Auctionator", error, "Auctionator: " .. failure, 0)
    C_Timer.After(0, function() ns.Fire("PRICES_CHANGED") end)
end

-- Its price of an item (the cheapest unit price at its last scan or search, at any age), or nil.
local function AuctionatorPrice(itemID)
    if not Prices.UsesAuctionator() then
        return nil
    end
    local ok, price = pcall(API().GetAuctionPriceByItemID, CALLER, itemID)
    if not ok then
        Fail(price)
        return nil
    end
    return type(price) == "number" and price > 0 and price or nil
end

-- Its notice comes after each of its searches and at the end of its scan, also for the player's own searches.
local function OnNotice()
    if pending or not Prices.UsesAuctionator() then
        return
    end
    pending = true
    C_Timer.After(NOTICE_DELAY, function()
        pending = false
        ns.Fire("PRICES_CHANGED")
    end)
end

-- Its update notice is asked for once: PLAYER_LOGIN comes once per load of the addon (a /reload loads it again),
-- and the registration cannot be removed.
ns.RegisterEvent("PLAYER_LOGIN", function()
    if not Prices.HasAuctionator() then
        return
    end
    local ok, err = pcall(API().RegisterForDBUpdate, CALLER, OnNotice)
    if not ok then
        Fail(err)
        return
    end
    -- Its price database is made at its own PLAYER_LOGIN: whatever read a price before that reads it again.
    C_Timer.After(1, function()
        if Prices.UsesAuctionator() then
            ns.Fire("PRICES_CHANGED")
        end
    end)
end)

---------------------------------------------------------------------------
-- Prices
---------------------------------------------------------------------------
-- The auction price, whether it rests on few lots, and its source ("auctionator" or "own"), or nil. Auctionator's
-- price has no few-lots rule; the own price is the scan's (prices saved by 1.0.0 have neither count).
function Prices.GetAuction(itemID)
    if not ns.db.settings.auctionPrices then
        return nil
    end
    local price = AuctionatorPrice(itemID)
    if price then
        return price, false, "auctionator"
    end
    local auction = ns.db.prices[itemID]
    if auction then
        local fewLots = (auction.quantity ~= nil and auction.quantity < Prices.FEW_PIECES)
            or (auction.lots ~= nil and auction.lots < Prices.FEW_LOTS)
        return auction.price, fewLots, "own"
    end
end

-- The vendor price of an item, 0 when it has none or the client has not loaded it yet.
local function VendorPrice(itemID)
    return select(11, C_Item.GetItemInfo(itemID)) or 0
end

-- The value used in sums: vendor price when the auction price rests on few lots.
function Prices.Get(itemID)
    local vendor = VendorPrice(itemID)
    local price, fewLots = Prices.GetAuction(itemID)
    if price and not fewLots then
        return math.max(price, vendor)
    end
    return vendor
end

-- The value of `count` pieces for item rows, with a mark when the auction price rests on few lots.
function Prices.FormatValue(itemID, count)
    local text = ns.FormatMoney((count or 1) * Prices.Get(itemID))
    if select(2, Prices.GetAuction(itemID)) then
        text = text .. " |cff888888(" .. ns.L["few lots"] .. ")|r"
    end
    return text
end

-- For item tooltips: the addon's own scanned price under its own name (another addon's line may show the cheapest
-- auction, which differs from this average), grey with the mark when it is not used because it rests on few lots.
-- With Auctionator's prices in use the line shows only the own price that fills in for an item Auctionator has
-- none for.
function Prices.AddTooltipLine(tooltip, itemID)
    local price, fewLots, source = Prices.GetAuction(itemID)
    if source == "auctionator" then
        -- VERIFY(V59): Auctionator's own line shows on the addon's row tooltips (GameTooltip:SetItemByID, its
        -- Source/Tooltips/Hooks.lua); if not, add the line with "(Auctionator)"
        return
    end
    if fewLots then
        local text = (ns.L["Auction price (OneKeyFishing): %s (few lots)"]):format(ns.FormatMoney(price))
        tooltip:AddLine(text, 0.6, 0.6, 0.6)
    elseif price then
        tooltip:AddLine((ns.L["Auction price (OneKeyFishing): %s"]):format(ns.FormatMoney(price)), 1, 1, 1)
    end
end

-- Bound items (bind on pickup, quest) cannot be listed at auction (the game's own rule, accepted in spec 018). A
-- poor quality item can (measured 2026-11-18). An item whose data the client has not loaded yet counts as one that
-- can: the scan's filter saves requests, it protects nothing.
function Prices.CanAuction(itemID)
    local name, _, _, _, _, _, _, _, _, _, _, _, _, bindType = C_Item.GetItemInfo(itemID)
    if not name then
        return true
    end
    return not (bindType == 1 or bindType == 4)
end

-- The character's own catches that can be sold at auction, counted by the source of their auction price:
-- { auctionator, own, vendor, none, missing }. An own price on few lots counts as own; `vendor` is no auction price
-- and a vendor price; the four add up to those catches. `missing`: the catches without an Auctionator price that
-- the statistics line advises its scan for, poor quality items left out (nobody lists junk, so no scan would ever
-- price it and the advice would never go). Computed when shown (the settings page, the statistics line, the debug
-- report).
local POOR = 0 -- the item quality of grey junk
function Prices.CountSources()
    local counts = { auctionator = 0, own = 0, vendor = 0, none = 0, missing = 0 }
    for itemID in pairs(ns.Stats.GetTotal().items) do
        if Prices.CanAuction(itemID) then
            local _, _, source = Prices.GetAuction(itemID)
            if not source then
                source = VendorPrice(itemID) > 0 and "vendor" or "none"
            end
            counts[source] = counts[source] + 1
            if source ~= "auctionator" and select(3, C_Item.GetItemInfo(itemID)) ~= POOR then
                counts.missing = counts.missing + 1
            end
        end
    end
    return counts
end

-- The lines of the debug report (English, not localized).
function Prices.Describe()
    local api = API()
    local function Presence(name)
        return name .. (api and type(api[name]) == "function" and " present" or " missing")
    end
    local settings = ns.db.settings
    local names = { off = "off", auctionator = "auctionator", own = "own scan" }
    local lines = {
        ("prices: source %s; auctionPrices %s, auctionatorPrices %s"):format(names[Prices.GetSource()],
            settings.auctionPrices and "on" or "off", settings.auctionatorPrices and "on" or "off"),
        ("Auctionator: %s, %s"):format(Presence("GetAuctionPriceByItemID"), Presence("RegisterForDBUpdate")),
    }
    if failure then
        table.insert(lines, "failed: " .. failure)
    end
    local counts = Prices.CountSources()
    table.insert(lines, ("own catches: %d Auctionator, %d own, %d vendor, %d none"):format(counts.auctionator,
        counts.own, counts.vendor, counts.none))
    -- The age Auctionator gives is nil past its own history limit, while the price stays.
    local oldest
    if Prices.UsesAuctionator() and type(api.GetAuctionAgeByItemID) == "function" then
        for itemID in pairs(ns.Stats.GetTotal().items) do
            if Prices.CanAuction(itemID) and select(3, Prices.GetAuction(itemID)) == "auctionator" then
                local ok, age = pcall(api.GetAuctionAgeByItemID, CALLER, itemID)
                if ok and type(age) == "number" and (not oldest or age > oldest) then
                    oldest = age
                end
            end
        end
    end
    table.insert(lines, "oldest Auctionator price: " .. (oldest and (math.floor(oldest) .. " days") or "unknown"))
    return lines
end

-- time() of the most recent auction scan result, or nil.
function Prices.GetLastScanTime()
    local latest
    for _, entry in pairs(ns.db.prices) do
        if not latest or entry.time > latest then
            latest = entry.time
        end
    end
    -- An answered search without a price (not on sale) is a scan too (Auction.lua, specs/018-auction-scan).
    for _, scanned in pairs(ns.db.priceScans or {}) do
        if not latest or scanned > latest then
            latest = scanned
        end
    end
    return latest
end

-- Copper -> "1g 20s 5c" with coin icons.
function ns.FormatMoney(copper)
    return GetMoneyString(math.floor(copper or 0), true)
end
