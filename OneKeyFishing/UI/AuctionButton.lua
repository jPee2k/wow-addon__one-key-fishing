-- AuctionButton: the "Scan fish prices" button above the top right corner of the auction house window. The scan
-- itself is Catch/Auction.lua's; the button follows its progress through AUCTION_STATE.
local _, ns = ...
local L = ns.L

local button

local function Update()
    if not button then
        return
    end
    local scanning, done, total = ns.Auction.GetProgress()
    if scanning then
        button:SetText((L["Scanning %d/%d"]):format(done, total))
        button:Disable()
    else
        button:SetText(L["Scan fish prices"])
        button:Enable()
    end
end

-- Made when the auction house first opens.
local function Ensure()
    if button or not AuctionHouseFrame then
        return
    end
    button = ns.CreateButton(AuctionHouseFrame, "", 150, ns.Auction.Scan)
    -- Wide enough for the longest text it shows, so it keeps its size while the count goes up.
    for _, text in ipairs({ L["Scan fish prices"], (L["Scanning %d/%d"]):format(999, 999) }) do
        button:SetText(text)
        button.minWidth = button:GetWidth() or button.minWidth
    end
    button:SetPoint("BOTTOMRIGHT", AuctionHouseFrame, "TOPRIGHT", -24, 2)
    Update()
end

ns.RegisterEvent("AUCTION_HOUSE_SHOW", Ensure)
ns.On("AUCTION_STATE", Update)
