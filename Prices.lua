-- Prices: value of a caught item, in copper.
-- The higher of the vendor price and the last scanned auction price (when auction prices are enabled).
local _, ns = ...

local Prices = {}
ns.Prices = Prices

function Prices.Get(itemID)
    local vendor = select(11, C_Item.GetItemInfo(itemID)) or 0
    local auction = ns.db.settings.auctionPrices and ns.db.prices[itemID]
    if auction then
        return math.max(auction.price, vendor)
    end
    return vendor
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

-- Copper -> "1g 20s 5c" with coin icons where the client supports it.
function ns.FormatMoney(copper)
    copper = math.floor(copper or 0)
    if GetMoneyString then
        return GetMoneyString(copper, true)
    end
    return ("%dg %ds %dc"):format(copper / 10000, (copper / 100) % 100, copper % 100)
end
