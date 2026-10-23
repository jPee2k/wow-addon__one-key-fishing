-- StatsFrame: session / current zone / all-time statistics, top catches and zones.
local _, ns = ...
local L = ns.L

local StatsFrame = {}
ns.StatsFrame = StatsFrame

local WIDTH, HEIGHT = 580, 560
local LABEL_X = 20
local COLUMN_X = { 210, 330, 450 }
local COLUMN_WIDTH = 110
local LINE_HEIGHT = 18
local TOP_ITEMS = 8
local TOP_ZONES = 5
local REFRESH_INTERVAL = 1

local frame

local FormatTime = ns.Stats.FormatTime -- Stats.lua loads earlier in the TOC

local function PerHour(amount, seconds)
    if seconds < 60 then
        return nil
    end
    return amount / (seconds / 3600)
end

-- Each row: label, function(bucket, liveMode, liveCast, value) -> text; value is Stats.GetValue(bucket)
local ROWS = {
    { L["Time fishing"], function(b, live) return FormatTime(b.modeTime + live) end },
    { L["Time casting"], function(b, _, liveCast) return FormatTime(b.castTime + liveCast) end },
    { L["Casts"], function(b) return tostring(b.casts) end },
    { L["Catches"], function(b) return tostring(b.catches) end },
    { L["Nothing caught"], function(b) return tostring(b.misses) end },
    { L["Catches per hour"], function(b, live)
        local value = PerHour(b.catches, b.modeTime + live)
        return value and ("%.1f"):format(value) or "-"
    end },
    { L["Value"], function(_, _, _, value) return ns.FormatMoney(value) end },
    { L["Gold per hour"], function(b, live, _, value)
        local perHour = PerHour(value, b.modeTime + live)
        return perHour and ns.FormatMoney(perHour) or "-"
    end },
}

local function CreateText(parent, template, justify)
    local fontString = parent:CreateFontString(nil, "OVERLAY", template)
    fontString:SetJustifyH(justify or "LEFT")
    return fontString
end

local function Confirm(key, text, onAccept)
    StaticPopupDialogs[key] = {
        text = text,
        button1 = YES,
        button2 = NO,
        OnAccept = onAccept,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    StaticPopup_Show(key)
end

local function Create()
    local ok, f = pcall(CreateFrame, "Frame", nil, UIParent, "BasicFrameTemplateWithInset")
    if not ok then
        f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    end
    _G.OneKeyFishingStatsFrame = f
    table.insert(UISpecialFrames, "OneKeyFishingStatsFrame")
    f:SetSize(WIDTH, HEIGHT)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    local title = CreateText(f, "GameFontHighlight", "CENTER")
    title:SetPoint("TOP", 0, -6)
    title:SetText(L["OneKeyFishing - Statistics"])

    f.skill = CreateText(f, "GameFontNormal")
    f.skill:SetPoint("TOPLEFT", LABEL_X, -32)
    f.prices = CreateText(f, "GameFontDisableSmall")
    f.prices:SetPoint("TOPLEFT", f.skill, "BOTTOMLEFT", 0, -4)

    -- Table header
    local headerY = -66
    local headers = { L["Session"], L["This zone"], L["All time"] }
    for i, text in ipairs(headers) do
        local header = CreateText(f, "GameFontNormal", "RIGHT")
        header:SetPoint("TOPLEFT", COLUMN_X[i], headerY)
        header:SetWidth(COLUMN_WIDTH)
        header:SetText(text)
    end
    f.zoneName = CreateText(f, "GameFontDisableSmall")
    f.zoneName:SetPoint("TOPLEFT", LABEL_X, headerY)
    f.zoneName:SetWidth(COLUMN_X[1] - LABEL_X - 8)

    f.cells = {}
    for row, definition in ipairs(ROWS) do
        local y = headerY - row * LINE_HEIGHT - 4
        local label = CreateText(f, "GameFontHighlight")
        label:SetPoint("TOPLEFT", LABEL_X, y)
        label:SetText(definition[1])
        f.cells[row] = {}
        for column = 1, 3 do
            local cell = CreateText(f, "GameFontHighlight", "RIGHT")
            cell:SetPoint("TOPLEFT", COLUMN_X[column], y)
            cell:SetWidth(COLUMN_WIDTH)
            f.cells[row][column] = cell
        end
    end

    -- Top catches
    local itemsY = headerY - (#ROWS + 1) * LINE_HEIGHT - 16
    local itemsHeader = CreateText(f, "GameFontNormal")
    itemsHeader:SetPoint("TOPLEFT", LABEL_X, itemsY)
    itemsHeader:SetText(L["Top catches (all time)"])
    f.itemLines = {}
    for i = 1, TOP_ITEMS do
        local line = CreateFrame("Frame", nil, f)
        line:SetSize(WIDTH - 2 * LABEL_X, LINE_HEIGHT)
        line:SetPoint("TOPLEFT", LABEL_X, itemsY - i * LINE_HEIGHT - 2)
        line.icon = line:CreateTexture(nil, "ARTWORK")
        line.icon:SetSize(16, 16)
        line.icon:SetPoint("LEFT")
        line.name = CreateText(line, "GameFontHighlight")
        line.name:SetPoint("LEFT", line.icon, "RIGHT", 6, 0)
        line.name:SetWidth(300)
        line.count = CreateText(line, "GameFontHighlight", "RIGHT")
        line.count:SetPoint("LEFT", line.name, "RIGHT", 4, 0)
        line.count:SetWidth(60)
        line.value = CreateText(line, "GameFontHighlight", "RIGHT")
        line.value:SetPoint("RIGHT")
        line.value:SetWidth(140)
        line:EnableMouse(true)
        line:SetScript("OnEnter", function(self)
            if self.itemID then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(self.itemID)
                GameTooltip:Show()
            end
        end)
        line:SetScript("OnLeave", function() GameTooltip:Hide() end)
        f.itemLines[i] = line
    end

    -- Zones
    local zonesY = itemsY - (TOP_ITEMS + 1) * LINE_HEIGHT - 12
    local zonesHeader = CreateText(f, "GameFontNormal")
    zonesHeader:SetPoint("TOPLEFT", LABEL_X, zonesY)
    zonesHeader:SetText(L["Zones (all time)"])
    f.zoneLines = {}
    for i = 1, TOP_ZONES do
        local name = CreateText(f, "GameFontHighlight")
        name:SetPoint("TOPLEFT", LABEL_X, zonesY - i * LINE_HEIGHT - 2)
        name:SetWidth(320)
        local detail = CreateText(f, "GameFontHighlight", "RIGHT")
        detail:SetPoint("TOPRIGHT", -LABEL_X, zonesY - i * LINE_HEIGHT - 2)
        detail:SetWidth(200)
        f.zoneLines[i] = { name = name, detail = detail }
    end

    -- Buttons
    local resetSession = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    resetSession:SetSize(130, 22)
    resetSession:SetPoint("BOTTOMLEFT", 14, 12)
    resetSession:SetText(L["Reset session"])
    resetSession:SetScript("OnClick", function()
        Confirm("ONEKEYFISHING_RESET_SESSION", L["Reset the fishing statistics of this session?"],
            ns.Stats.ResetSession)
    end)
    local resetAll = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    resetAll:SetSize(130, 22)
    resetAll:SetPoint("LEFT", resetSession, "RIGHT", 8, 0)
    resetAll:SetText(L["Reset all"])
    resetAll:SetScript("OnClick", function()
        Confirm("ONEKEYFISHING_RESET_ALL", L["Delete ALL fishing statistics of this character?"], ns.Stats.ResetAll)
    end)
    f.scan = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.scan:SetSize(160, 22)
    f.scan:SetPoint("BOTTOMRIGHT", -14, 12)
    f.scan:SetText(L["Scan auction prices"])
    f.scan:SetScript("OnClick", function() ns.Auction.Scan() end)

    local elapsed = 0
    f:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= REFRESH_INTERVAL then
            elapsed = 0
            StatsFrame.Refresh()
        end
    end)
    f:SetScript("OnShow", function() StatsFrame.Refresh() end)
    -- New frames are shown; start hidden so the first Toggle opens it.
    f:Hide()
    return f
end

local function SortedKeys(tbl, compare)
    local keys = {}
    for key in pairs(tbl) do
        table.insert(keys, key)
    end
    table.sort(keys, compare)
    return keys
end

function StatsFrame.Refresh()
    if not frame or not frame:IsShown() then
        return
    end
    local session, zone, total = ns.Stats.GetSession(), ns.Stats.GetCurrentZone(), ns.Stats.GetTotal()

    local rank, maxRank = ns.Skill.Get()
    if rank then
        local gained = session.skillStart and rank - session.skillStart or 0
        frame.skill:SetText((L["Fishing skill: %d/%d %s%s"]):format(rank, maxRank, ns.Skill.GetRankName(maxRank),
            gained > 0 and ("  |cff55ff55" .. L["(+%d this session)"]:format(gained) .. "|r") or ""))
    else
        frame.skill:SetText(L["Fishing is not learned."])
    end
    frame.zoneName:SetText(zone.name or "")

    local lastScan = ns.Prices.GetLastScanTime()
    if ns.db.settings.auctionPrices and lastScan then
        frame.prices:SetText((L["Values: higher of vendor and auction price (last scan %s ago)"]):format(
            SecondsToTime and SecondsToTime(time() - lastScan) or (time() - lastScan) .. "s"))
    else
        frame.prices:SetText(L["Values: vendor price (scan the auction house for market prices)"])
    end
    frame.scan:SetEnabled(ns.Auction.IsOpen() and not ns.Auction.IsScanning())

    local liveMode, liveCast = ns.Stats.GetLiveTime()
    local buckets = { session, zone, total }
    local values = {}
    for column, bucket in ipairs(buckets) do
        values[column] = ns.Stats.GetValue(bucket)
    end
    for row, definition in ipairs(ROWS) do
        for column, bucket in ipairs(buckets) do
            frame.cells[row][column]:SetText(definition[2](bucket, liveMode, liveCast, values[column]))
        end
    end

    local items = total.items
    local itemIDs = SortedKeys(items, function(a, b) return items[a] > items[b] end)
    for i, line in ipairs(frame.itemLines) do
        local itemID = itemIDs[i]
        line.itemID = itemID
        if itemID then
            local name, link, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
            line.icon:SetTexture(icon or C_Item.GetItemIconByID(itemID))
            line.name:SetText(link or name or ("item:" .. itemID))
            line.count:SetText("x" .. items[itemID])
            line.value:SetText(ns.FormatMoney(items[itemID] * ns.Prices.Get(itemID)))
            line:Show()
        else
            line:Hide()
        end
    end

    local zones = ns.Stats.GetZones()
    local zoneKeys = SortedKeys(zones, function(a, b) return zones[a].catches > zones[b].catches end)
    for i, line in ipairs(frame.zoneLines) do
        local data = zones[zoneKeys[i]]
        if data and data.catches > 0 then
            line.name:SetText(data.name or "?")
            line.detail:SetText((L["%d catches, %s"]):format(data.catches, FormatTime(data.modeTime)))
        else
            line.name:SetText(i == 1 and ("|cff888888" .. L["No catches yet."] .. "|r") or "")
            line.detail:SetText("")
        end
    end
end

function StatsFrame.Toggle()
    frame = frame or Create()
    frame:SetShown(not frame:IsShown())
end

ns.On("STATS_CHANGED", StatsFrame.Refresh)
ns.On("AUCTION_STATE", StatsFrame.Refresh)
ns.RegisterCommand("stats", L["show the fishing statistics"], StatsFrame.Toggle)
