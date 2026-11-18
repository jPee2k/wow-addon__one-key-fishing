-- The scan buttons and the scan command follow one state (specs/018-auction-scan, User Story 3, FR-014): the button
-- above the auction window, the statistics window's, the settings page's with its hint, the minimap menu's entry
-- and /okf scan.

AuctionHouseFrame = CreateFrame("Frame", "AuctionHouseFrame")
load_addon()
ns.Auction.SetItemSource(nil)
ns.db.fishedItems = { [90001] = true }

local L = ns.L
local WHY_STALLED = L["The auction house does not answer. Log out and back in to bring it back."]
local NOT_ANSWERING = L["Auction house not answering"]

ns.StatsFrame.Toggle()
local statsScan = assert(find_frame(L["Scan auction prices"], _G.OneKeyFishingStatsFrame), "the statistics button")
local page = assert(settings_pages["OneKeyFishing"], "the main settings page")
page:Hide()
page:Show()
local pageScan = assert(find_frame(L["Scan auction prices"], page), "the settings button")
local hint = assert(find_frame(L["(open the auction house first)"], page), "the settings hint")

local function minimapEntry()
    local button = assert(_G.OneKeyFishingMinimapButton, "the minimap button")
    button.scripts.OnClick(button, "RightButton")
    for _, entry in ipairs(menu_entries) do
        if entry.text == L["Scan auction prices"] or entry.text == NOT_ANSWERING then
            return entry
        end
    end
end

local function auctionButton()
    for _, text in ipairs({ L["Scan fish prices"], NOT_ANSWERING, (L["Scanning %d/%d"]):format(0, 1) }) do
        local button = find_frame(text, AuctionHouseFrame)
        if button then
            return button
        end
    end
end

local function hover(button)
    tooltip_lines = {}
    assert(button.scripts.OnEnter, "the button shows its reason on hover")
    button.scripts.OnEnter(button)
    return table.concat(tooltip_lines, "\n")
end

local function stall()
    auction_ready = false
    fire("AUCTION_HOUSE_THROTTLED_MESSAGE_SENT")
    advance(10.5)
    assert(ns.Auction.GetState() == "stalled", "stalled")
end

test("closed: the buttons are disabled, the hint asks to open the auction house", function()
    eq(statsScan:IsEnabled(), false, "statistics")
    eq(pageScan:IsEnabled(), false, "settings")
    eq(hint:IsShown(), true, "hint shown")
    eq(hint.text, L["(open the auction house first)"], "hint text")
    eq(minimapEntry().enabled, false, "minimap entry")
    chat = {}
    SlashCmdList.ONEKEYFISHING("scan")
    eq(chat_count(L["Open the auction house first."]), 1, "/okf scan")
end)

test("open and ready: everything enabled, the hint hidden", function()
    fire("AUCTION_HOUSE_SHOW")
    eq(statsScan:IsEnabled(), true, "statistics")
    eq(pageScan:IsEnabled(), true, "settings")
    eq(hint:IsShown(), false, "hint hidden")
    eq(minimapEntry().enabled, nil, "minimap entry not disabled")
    local button = assert(auctionButton(), "the button above the auction window")
    eq(button.text, L["Scan fish prices"], "its text")
    eq(button:IsEnabled(), true, "enabled")
end)

test("scanning: everything disabled, the button above the auction window counts", function()
    ns.Auction.Scan()
    eq(statsScan:IsEnabled(), false, "statistics")
    eq(pageScan:IsEnabled(), false, "settings")
    local button = auctionButton()
    eq(button.text, (L["Scanning %d/%d"]):format(0, 1), "its text")
    eq(button:IsEnabled(), false, "disabled")
end)

test("stalled: everything disabled and says why", function()
    stall()
    eq(statsScan:IsEnabled(), false, "statistics")
    eq(pageScan:IsEnabled(), false, "settings")
    eq(hint:IsShown(), true, "hint shown")
    eq(hint.text, WHY_STALLED, "hint text")
    assert(hover(statsScan):find(WHY_STALLED, 1, true), "the statistics button's tooltip")
    local entry = minimapEntry()
    eq(entry.text, NOT_ANSWERING, "minimap entry text")
    eq(entry.enabled, false, "minimap entry disabled")
    local button = auctionButton()
    eq(button.text, NOT_ANSWERING, "the button above the auction window")
    eq(button:IsEnabled(), false, "disabled")
    assert(hover(button):find(WHY_STALLED, 1, true), "its tooltip")
    chat = {}
    SlashCmdList.ONEKEYFISHING("scan")
    eq(chat_count(WHY_STALLED), 1, "/okf scan")
end)

test("ready again: everything as before, without a reload", function()
    hover(statsScan)
    eq(tooltip_shown, true, "the pointer rests on the statistics button")
    auction_ready = true
    fire("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
    eq(tooltip_shown, false, "its tooltip with the old reason went away")
    eq(statsScan:IsEnabled(), true, "statistics")
    eq(pageScan:IsEnabled(), true, "settings")
    eq(hint:IsShown(), false, "hint hidden")
    eq(minimapEntry().text, L["Scan auction prices"], "minimap entry text")
    local button = auctionButton()
    eq(button.text, L["Scan fish prices"], "the button above the auction window")
    eq(button:IsEnabled(), true, "enabled")
end)
