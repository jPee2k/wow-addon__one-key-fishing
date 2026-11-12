-- Prices: value of a caught item, in copper.
-- The higher of the vendor price and the last scanned auction price (when auction prices are enabled). An auction
-- price based on fewer than FEW_PIECES pieces or FEW_LOTS result rows on sale ("few lots") is shown with a mark but
-- not used for values: one seller's stack alone does not make a market price.
local _, ns = ...

local Prices = {}
ns.Prices = Prices

local FEW_PIECES = 5 -- pieces the price saw
local FEW_LOTS = 3 -- result rows (price points) on sale

-- The scanned auction price and whether it rests on few lots, or nil. Prices saved by 1.0.0 have neither count.
function Prices.GetAuction(itemID)
    local auction = ns.db.settings.auctionPrices and ns.db.prices[itemID]
    if auction then
        local fewLots = (auction.quantity ~= nil and auction.quantity < FEW_PIECES)
            or (auction.lots ~= nil and auction.lots < FEW_LOTS)
        return auction.price, fewLots
    end
end

-- The value used in sums: vendor price when the auction price rests on few lots.
function Prices.Get(itemID)
    local vendor = select(11, C_Item.GetItemInfo(itemID)) or 0
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

-- For item tooltips: the auction price that is not used because it rests on few lots.
function Prices.AddTooltipLine(tooltip, itemID)
    local price, fewLots = Prices.GetAuction(itemID)
    if fewLots then
        tooltip:AddLine((ns.L["Auction price: %s (few lots)"]):format(ns.FormatMoney(price)), 0.6, 0.6, 0.6)
    end
end

-- time() of the most recent auction scan result, or nil.
function Prices.GetLastScanTime()
    local latest
    for _, entry in pairs(ns.db.prices) do
        if not latest or entry.time > latest then
            latest = entry.time
        end
    end
    return latest
end

-- Copper -> "1g 20s 5c" with coin icons.
function ns.FormatMoney(copper)
    return GetMoneyString(math.floor(copper or 0), true)
end
