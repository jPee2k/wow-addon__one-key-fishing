-- StatsFrame: session / current zone / all-time statistics, top catches and zones.
-- Everything is recomputed when the data changed (catch, miss, cast, zone change, scan, Refresh);
-- otherwise only the time rows tick.
local _, ns = ...
local L = ns.L

local StatsFrame = {}
ns.StatsFrame = StatsFrame

local WIDTH, HEIGHT = 580, 660
local LABEL_X = 20
local COLUMN_X = { 210, 330, 450 }
local COLUMN_WIDTH = 110
local LINE_HEIGHT = 18
local SECTION_GAP = 6
local TOP_ITEMS = 8
local TOP_ZONES = 5
local TICK_INTERVAL = 1

local frame

local FormatTime = ns.Stats.FormatTime -- Stats.lua loads earlier in the TOC
local FormatShortTime = ns.Stats.FormatShortTime
local CreateButton = ns.CreateButton -- Core.lua

local function PerHour(amount, seconds)
    if seconds < 60 then
        return nil
    end
    return amount / (seconds / 3600)
end

-- The session column ticks visibly, so it keeps the seconds; the totals do not need them.
local function ColumnTime(column, seconds)
    return column == 1 and FormatTime(seconds) or FormatShortTime(seconds)
end

-- Sections and rows; `key` names a row's cells in frame.cells. A row's text(c) gets the column context:
-- c.bucket, c.column, c.liveMode, c.liveCast (seconds not yet in the bucket), c.value (Stats.GetValue).
-- `live` rows are updated every second while the timer runs; the rest only on events.
local ROWS = {
    { section = L["Time"] },
    { key = "timeFishing", label = L["Time fishing"], live = true,
        tip = L["Time in fishing mode. Paused while AFK if that option is on."],
        text = function(c) return ColumnTime(c.column, c.bucket.modeTime + c.liveMode) end },
    { key = "timeCasting", label = L["Time casting"], live = true,
        tip = L["Time with the bobber in the water."],
        text = function(c) return ColumnTime(c.column, c.bucket.castTime + c.liveCast) end },
    { section = L["Results"] },
    { key = "casts", label = L["Casts"], tip = L["Fishing casts made in fishing mode."],
        text = function(c) return tostring(c.bucket.casts) end },
    { key = "catches", label = L["Catches"], tip = L["Casts that brought loot."],
        text = function(c) return tostring(c.bucket.catches) end },
    { key = "misses", label = L["Nothing caught"], tip = L["Casts that ended without loot."],
        text = function(c) return tostring(c.bucket.misses) end },
    { key = "catchesPerHour", label = L["Catches per hour"],
        tip = L["Catches per hour of fishing time. Updated with every cast and with Refresh."],
        text = function(c)
            local value = PerHour(c.bucket.catches, c.bucket.modeTime + c.liveMode)
            return value and ("%.1f"):format(value) or "-"
        end },
    { section = L["Money"] },
    { key = "value", label = L["Value"],
        tip = L["Items caught, at the higher of the vendor price and the last scanned auction price."],
        text = function(c) return ns.FormatMoney(c.value) end },
    { key = "goldPerHour", label = L["Gold per hour"],
        tip = L["Value per hour of fishing time. Updated with every cast and with Refresh."],
        text = function(c)
            local perHour = PerHour(c.value, c.bucket.modeTime + c.liveMode)
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

local function ShowRowTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(self.label)
    GameTooltip:AddLine(self.tip, 1, 1, 1, true)
    GameTooltip:Show()
end

-- Rows and section headers from ROWS; returns the y below the last row.
local function CreateTable(f, headerY)
    f.cells = {} -- row key -> its three cells (session, this zone, all time)
    local y = headerY - 4
    for _, definition in ipairs(ROWS) do
        if definition.section then
            y = y - LINE_HEIGHT - SECTION_GAP
            local header = CreateText(f, "GameFontNormalSmall")
            header:SetPoint("TOPLEFT", LABEL_X, y)
            header:SetText(definition.section)
            local divider = f:CreateTexture(nil, "ARTWORK")
            divider:SetColorTexture(1, 1, 1, 0.15)
            divider:SetHeight(1)
            divider:SetPoint("TOPLEFT", LABEL_X, y - LINE_HEIGHT + 4)
            divider:SetPoint("TOPRIGHT", -LABEL_X, y - LINE_HEIGHT + 4)
        else
            y = y - LINE_HEIGHT
            local label = CreateText(f, "GameFontHighlight")
            label:SetPoint("TOPLEFT", LABEL_X, y)
            label:SetText(definition.label)
            -- Font strings take no mouse input: a frame over the label shows the explanation.
            local hover = CreateFrame("Frame", nil, f)
            hover:SetPoint("TOPLEFT", LABEL_X, y)
            hover:SetSize(COLUMN_X[1] - LABEL_X - 8, LINE_HEIGHT)
            hover:EnableMouse(true)
            hover.label, hover.tip = definition.label, definition.tip
            hover:SetScript("OnEnter", ShowRowTooltip)
            hover:SetScript("OnLeave", function() GameTooltip:Hide() end)
            -- It takes the mouse, so pass dragging on to the window.
            hover:RegisterForDrag("LeftButton")
            hover:SetScript("OnDragStart", function() f:StartMoving() end)
            hover:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
            assert(definition.key and not f.cells[definition.key], "every ROWS row needs its own key")
            local cells = {}
            f.cells[definition.key] = cells
            for column = 1, 3 do
                local cell = CreateText(f, "GameFontHighlight", "RIGHT")
                cell:SetPoint("TOPLEFT", COLUMN_X[column], y)
                cell:SetWidth(COLUMN_WIDTH)
                cells[column] = cell
            end
        end
    end
    return y
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

    local tableBottom = CreateTable(f, headerY)

    -- Top catches
    local itemsY = tableBottom - LINE_HEIGHT - 16
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
    local resetSession = CreateButton(f, L["Reset session"], 130, function()
        Confirm("ONEKEYFISHING_RESET_SESSION", L["Reset the fishing statistics of this session?"], function()
            ns.Stats.ResetSession()
            StatsFrame.Refresh() -- right away: the old buckets are gone
        end)
    end)
    resetSession:SetPoint("BOTTOMLEFT", 14, 12)
    local resetAll = CreateButton(f, L["Reset all"], 130, function()
        Confirm("ONEKEYFISHING_RESET_ALL", L["Delete ALL fishing statistics of this character?"], function()
            ns.Stats.ResetAll()
            StatsFrame.Refresh()
        end)
    end)
    resetAll:SetPoint("LEFT", resetSession, "RIGHT", 8, 0)
    local refresh = CreateButton(f, L["Refresh"], 90, function() StatsFrame.Refresh() end)
    refresh:SetPoint("LEFT", resetAll, "RIGHT", 8, 0)
    f.scan = CreateButton(f, L["Scan auction prices"], 160, function() ns.Auction.Scan() end)
    f.scan:SetPoint("BOTTOMRIGHT", -14, 12)

    local elapsed = 0
    f:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= TICK_INTERVAL then
            elapsed = 0
            StatsFrame.Tick()
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

local function IsShown()
    return frame and frame:IsShown()
end

local function UpdateScanButton()
    frame.scan:SetEnabled(ns.Auction.CanScan())
end

-- The column contexts for ROWS; values come from the last full refresh.
local contexts = { {}, {}, {} }

local function FillCells(liveOnly)
    for _, definition in ipairs(ROWS) do
        if definition.text and (definition.live or not liveOnly) then
            for column, context in ipairs(contexts) do
                frame.cells[definition.key][column]:SetText(definition.text(context))
            end
        end
    end
end

-- The current zone's line in the zone list; its time ticks like the "This zone" column.
local currentZoneLine, currentZoneData

local function ZoneDetail(data, liveMode)
    return (L["%d catches, %s"]):format(data.catches, FormatShortTime(data.modeTime + liveMode))
end

-- Only the time rows: cheap, called every second while the timer runs. A stopping timer flushes its time
-- into the buckets, which bumps the Stats version, so Tick does a full refresh then.
local function RefreshTime()
    local liveMode, liveCast = ns.Stats.GetLiveTime()
    if liveMode == 0 and liveCast == 0 then
        return -- nothing running: the window shows the saved totals
    end
    for _, context in ipairs(contexts) do
        context.liveMode, context.liveCast = liveMode, liveCast
    end
    FillCells(true)
    if currentZoneLine then
        currentZoneLine.detail:SetText(ZoneDetail(currentZoneData, liveMode))
    end
end

-- Set by changes the Stats version does not cover (auction prices, skill, settings, item info).
local dirty = false
local shownVersion

local function MarkDirty()
    dirty = true
end

-- Everything, including values and rates. Called on show, by the Refresh button, and by Tick when the data changed.
function StatsFrame.Refresh()
    if not IsShown() then
        return
    end
    dirty, shownVersion = false, ns.Stats.GetVersion()
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
        frame.prices:SetText((L["Values: higher of vendor and auction price (scanned %s)"]):format(
            date("%Y-%m-%d %H:%M", lastScan)))
    else
        frame.prices:SetText(L["Values: vendor price (scan the auction house for market prices)"])
    end
    UpdateScanButton()

    local liveMode, liveCast = ns.Stats.GetLiveTime()
    for column, bucket in ipairs({ session, zone, total }) do
        local context = contexts[column]
        context.bucket, context.column = bucket, column
        context.liveMode, context.liveCast = liveMode, liveCast
        context.value = ns.Stats.GetValue(bucket)
    end
    FillCells(false)

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
    currentZoneLine, currentZoneData = nil, nil
    for i, line in ipairs(frame.zoneLines) do
        local data = zones[zoneKeys[i]]
        if data and data.catches > 0 then
            line.name:SetText(data.name or "?")
            line.detail:SetText(ZoneDetail(data, data == zone and liveMode or 0))
            if data == zone then
                currentZoneLine, currentZoneData = line, data
            end
        else
            line.name:SetText(i == 1 and ("|cff888888" .. L["No catches yet."] .. "|r") or "")
            line.detail:SetText("")
        end
    end
end

-- Every second: a full refresh when something changed, otherwise just the time rows.
function StatsFrame.Tick()
    if not IsShown() then
        return
    end
    if dirty or shownVersion ~= ns.Stats.GetVersion() then
        StatsFrame.Refresh()
    else
        RefreshTime()
    end
end

function StatsFrame.Toggle()
    frame = frame or Create()
    frame:SetShown(not frame:IsShown())
end

-- Statistics changes are seen through the Stats version; these only mark the window dirty, so a burst
-- of them costs one refresh on the next tick.
ns.On("PRICES_CHANGED", MarkDirty) -- an auction scan finished or stopped
-- Fires for every item of a scan: only the button changes.
ns.On("AUCTION_STATE", function()
    if IsShown() then
        UpdateScanButton()
    end
end)
ns.On("SETTINGS_CHANGED", MarkDirty) -- e.g. auction prices on or off
-- Skill.lua listens to both: either can come first after a skill-up.
ns.RegisterEvent("SKILL_LINES_CHANGED", MarkDirty)
ns.RegisterEvent("CHAT_MSG_SKILL", MarkDirty)
-- Names, icons and vendor prices of caught items the client did not know yet arrive later.
-- Other items (bags, auction house) and failed lookups are ignored.
ns.RegisterEvent("GET_ITEM_INFO_RECEIVED", function(_, itemID, success)
    if success and IsShown() and ns.Stats.GetTotal().items[itemID] then
        MarkDirty()
    end
end)

ns.RegisterCommand("stats", L["show the fishing statistics"], StatsFrame.Toggle)
