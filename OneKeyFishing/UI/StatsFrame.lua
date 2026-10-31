-- StatsFrame: session / current zone / all-time statistics, top catches and zones, on the first of three tabs;
-- the second tab is the "What can be caught here" page (UI/CatchHere.lua), the third the catch catalog
-- (UI/CatalogTab.lua). The last open tab is saved.
-- Everything is recomputed when the data changed (catch, miss, cast, zone change, scan, Refresh);
-- otherwise only the time rows tick.
local _, ns = ...
local L = ns.L

local StatsFrame = {}
ns.StatsFrame = StatsFrame

local WIDTH, HEIGHT = 580, 700
local LABEL_X = 20
local COLUMN_X = { 210, 330, 450 }
local COLUMN_WIDTH = 110
local LINE_HEIGHT = 18
local SECTION_GAP = 6
local TOP_ITEMS = 8
local TOP_ZONES = 5
local TICK_INTERVAL = 1

local frame
-- The window's pages in tab order, built by Create: { key, label, frame, refresh, tick }. The open one is saved
-- in OneKeyFishingDB.statsTab.
local pages

local FormatTime = ns.Stats.FormatTime -- Stats.lua loads earlier in the TOC
local FormatShortTime = ns.Stats.FormatShortTime
local CreateButton = ns.CreateButton -- UI/Widgets.lua

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
-- `live` rows are updated every second while the timer runs; the rest only on events. Built by Create(): the
-- labels need the language, which is set after the files load.
local ROWS
local function BuildRows()
    return {
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
                return value and ns.FormatDecimal(value, 1) or "-"
            end },
        { section = L["Money"] },
        { key = "value", label = L["Value"],
            tip = L["Items caught, at the higher of vendor and auction price; with few lots listed, the vendor price."],
            text = function(c) return ns.FormatMoney(c.value) end },
        { key = "goldPerHour", label = L["Gold per hour"],
            tip = L["Value per hour of fishing time. Updated with every cast and with Refresh."],
            text = function(c)
                local perHour = PerHour(c.value, c.bucket.modeTime + c.liveMode)
                return perHour and ns.FormatMoney(perHour) or "-"
            end },
    }
end

local CreateText = ns.CreateText -- UI/Widgets.lua

local function ShowRowTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(self.label)
    GameTooltip:AddLine(self.tip, 1, 1, 1, true)
    GameTooltip:Show()
end

-- Rows and section headers from ROWS, on the statistics page; returns the y below the last row.
local function CreateTable(f, page, headerY)
    f.cells = {} -- row key -> its three cells (session, this zone, all time)
    local y = headerY - 4
    for _, definition in ipairs(ROWS) do
        if definition.section then
            y = y - LINE_HEIGHT - SECTION_GAP
            local header = CreateText(page, "GameFontNormalSmall")
            header:SetPoint("TOPLEFT", LABEL_X, y)
            header:SetText(definition.section)
            local divider = page:CreateTexture(nil, "ARTWORK")
            divider:SetColorTexture(1, 1, 1, 0.15)
            divider:SetHeight(1)
            divider:SetPoint("TOPLEFT", LABEL_X, y - LINE_HEIGHT + 4)
            divider:SetPoint("TOPRIGHT", -LABEL_X, y - LINE_HEIGHT + 4)
        else
            y = y - LINE_HEIGHT
            local label = CreateText(page, "GameFontHighlight")
            label:SetPoint("TOPLEFT", LABEL_X, y)
            label:SetText(definition.label)
            -- A long translation is cut at the first column; the row tooltip shows it in full.
            label:SetWidth(COLUMN_X[1] - LABEL_X - 8)
            label:SetWordWrap(false)
            -- Font strings take no mouse input: a frame over the label shows the explanation.
            local hover = CreateFrame("Frame", nil, page)
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
                local cell = CreateText(page, "GameFontHighlight", "RIGHT")
                cell:SetPoint("TOPLEFT", COLUMN_X[column], y)
                cell:SetWidth(COLUMN_WIDTH)
                cells[column] = cell
            end
        end
    end
    return y
end

-- The bottom buttons' layout: the window is at least `minWidth` and widens for the left row (its width with the
-- margins); returns that width and whether the Scan button wraps to a second row.
function StatsFrame.ButtonRows(leftWidth, scanWidth, minWidth)
    local width = math.max(minWidth, leftWidth)
    return width, leftWidth + 8 + scanWidth > width
end

-- Shows the page with this key (the first one for an unknown key) and marks its tab.
local function SelectTab(key)
    local selected = 1
    for index, page in ipairs(pages) do
        if page.key == key then
            selected = index
        end
    end
    ns.db.statsTab = pages[selected].key
    for index, page in ipairs(pages) do
        page.frame:SetShown(index == selected)
    end
    if frame.usesPanelTabs then
        PanelTemplates_SetTab(frame, selected)
    else
        for index, tab in ipairs(frame.Tabs) do
            tab:SetEnabled(index ~= selected)
        end
    end
    pages[selected].refresh()
end

-- One tab: the game's panel tab, or nil when the client lacks the template.
local function CreatePanelTab(f, text)
    local ok, tab = pcall(CreateFrame, "Button", nil, f, "PanelTabButtonTemplate")
    if ok and tab then
        tab:SetText(text)
        PanelTemplates_TabResize(tab, 0)
        return tab
    end
end

-- A tab per page below the window: the game's panel tabs, or plain buttons for all of them when the client
-- lacks the template or its functions (one look for every tab).
local function CreateTabs(f)
    -- VERIFY(V6): PanelTabButtonTemplate and PanelTemplates_* render tabs in Forever
    local tabs = {}
    if PanelTemplates_SetNumTabs and PanelTemplates_SetTab and PanelTemplates_TabResize then
        for index, page in ipairs(pages) do
            tabs[index] = CreatePanelTab(f, page.label)
            if not tabs[index] then
                for _, tab in ipairs(tabs) do
                    tab:Hide()
                end
                tabs = {}
                break
            end
        end
    end
    f.usesPanelTabs = #tabs == #pages
    for index, page in ipairs(pages) do
        local tab = tabs[index] or ns.CreateButton(f, page.label, 120, nil)
        tab:SetScript("OnClick", function() SelectTab(page.key) end)
        if index == 1 then
            tab:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 12, 2)
        else
            tab:SetPoint("LEFT", tabs[index - 1], "RIGHT", 4, 0)
        end
        tabs[index] = tab
    end
    f.Tabs = tabs -- what PanelTemplates_* read
    if f.usesPanelTabs then
        PanelTemplates_SetNumTabs(f, #tabs)
    end
end

local function Create()
    ROWS = BuildRows()
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

    -- Three pages over the same area, switched by the tabs below the window: today's statistics,
    -- "What can be caught here" (UI/CatchHere.lua) and the catch catalog (UI/CatalogTab.lua).
    local page = CreateFrame("Frame", nil, f)
    page:SetAllPoints()
    f.statsPage = page
    f.herePage = ns.CatchHere.Create(f)
    f.catalogPage = ns.CatalogTab.Create(f)
    pages = {
        { key = "stats", label = L["Statistics"], frame = page,
            refresh = StatsFrame.Refresh, tick = StatsFrame.TickStatistics },
        { key = "here", label = L["What can be caught here"], frame = f.herePage,
            refresh = ns.CatchHere.Refresh, tick = ns.CatchHere.Tick },
        { key = "catalog", label = L["Catch catalog"], frame = f.catalogPage,
            refresh = ns.CatalogTab.Refresh, tick = ns.CatalogTab.Tick },
    }

    f.skill = CreateText(page, "GameFontNormal")
    f.skill:SetPoint("TOPLEFT", LABEL_X, -32)
    f.prices = CreateText(page, "GameFontDisableSmall")
    f.prices:SetPoint("TOPLEFT", f.skill, "BOTTOMLEFT", 0, -4)
    -- The next Fishing rank (three lines at most) and the map pin for its place
    f.nextRank = CreateText(page, "GameFontHighlightSmall")
    f.nextRank:SetPoint("TOPLEFT", f.prices, "BOTTOMLEFT", 0, -4)
    f.nextRank:SetWidth(WIDTH - 2 * LABEL_X - 90)
    f.nextRank:SetMaxLines(3) -- the table header below leaves room for three
    f.pin = CreateButton(page, L["Pin"], 60, function() ns.Skill.PinNextRank() end)
    f.pin:SetPoint("TOPLEFT", f.nextRank, "TOPRIGHT", 10, 4) -- beside its line, clear of the prices line

    -- Table header
    local headerY = -106
    local headers = { L["Session"], L["This zone"], L["All time"] }
    for i, text in ipairs(headers) do
        local header = CreateText(page, "GameFontNormal", "RIGHT")
        header:SetPoint("TOPLEFT", COLUMN_X[i], headerY)
        header:SetWidth(COLUMN_WIDTH)
        header:SetText(text)
    end
    f.zoneName = CreateText(page, "GameFontDisableSmall")
    f.zoneName:SetPoint("TOPLEFT", LABEL_X, headerY)
    f.zoneName:SetWidth(COLUMN_X[1] - LABEL_X - 8)

    local tableBottom = CreateTable(f, page, headerY)

    -- Top catches
    local itemsY = tableBottom - LINE_HEIGHT - 16
    local itemsHeader = CreateText(page, "GameFontNormal")
    itemsHeader:SetPoint("TOPLEFT", LABEL_X, itemsY)
    itemsHeader:SetText(L["Top catches (all time)"])
    f.itemLines = {}
    for i = 1, TOP_ITEMS do
        local line = CreateFrame("Frame", nil, page)
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
                ns.ShowItemTooltip(self, self.itemID, true)
            end
        end)
        line:SetScript("OnLeave", function() GameTooltip:Hide() end)
        f.itemLines[i] = line
    end

    -- Zones
    local zonesY = itemsY - (TOP_ITEMS + 1) * LINE_HEIGHT - 12
    local zonesHeader = CreateText(page, "GameFontNormal")
    zonesHeader:SetPoint("TOPLEFT", LABEL_X, zonesY)
    zonesHeader:SetText(L["Zones (all time)"])
    f.zoneLines = {}
    for i = 1, TOP_ZONES do
        local name = CreateText(page, "GameFontHighlight")
        name:SetPoint("TOPLEFT", LABEL_X, zonesY - i * LINE_HEIGHT - 2)
        name:SetWidth(320)
        local detail = CreateText(page, "GameFontHighlight", "RIGHT")
        detail:SetPoint("TOPRIGHT", -LABEL_X, zonesY - i * LINE_HEIGHT - 2)
        detail:SetWidth(200)
        f.zoneLines[i] = { name = name, detail = detail }
    end

    -- Buttons
    local resetSession = CreateButton(page, L["Reset session"], 130, function()
        ns.ShowPopup("ONEKEYFISHING_RESET_SESSION", L["Reset the fishing statistics of this session?"], function()
            ns.Stats.ResetSession()
            StatsFrame.Refresh() -- right away: the old buckets are gone
        end)
    end)
    resetSession:SetPoint("BOTTOMLEFT", 14, 12)
    local resetAll = CreateButton(page, L["Reset all"], 130, function()
        ns.ShowPopup("ONEKEYFISHING_RESET_ALL", L["Delete ALL fishing statistics of this character?"], function()
            ns.Stats.ResetAll()
            StatsFrame.Refresh()
        end)
    end)
    resetAll:SetPoint("LEFT", resetSession, "RIGHT", 8, 0)
    local refresh = CreateButton(page, L["Refresh"], 90, function() StatsFrame.Refresh() end)
    refresh:SetPoint("LEFT", resetAll, "RIGHT", 8, 0)
    f.scan = CreateButton(page, L["Scan auction prices"], 160, function() ns.Auction.Scan() end)
    f.scan:SetPoint("BOTTOMRIGHT", -14, 12)
    -- Translated buttons can be too wide: the window widens for the three left buttons, and a Scan button that
    -- does not fit beside them wraps like text: the left three move up a row, Scan starts the row below at the
    -- left (the window grows by that row, so the zone list stays clear of the buttons).
    local leftRow = 14 + (resetSession:GetWidth() or 0) + 8 + (resetAll:GetWidth() or 0) + 8
        + (refresh:GetWidth() or 0) + 14
    local width, wraps = StatsFrame.ButtonRows(leftRow, f.scan:GetWidth() or 0, WIDTH)
    f:SetWidth(width)
    if wraps then
        f:SetHeight(HEIGHT + 28)
        resetSession:ClearAllPoints()
        resetSession:SetPoint("BOTTOMLEFT", 14, 40)
        f.scan:ClearAllPoints()
        f.scan:SetPoint("BOTTOMLEFT", 14, 12)
    end

    CreateTabs(f)

    local elapsed = 0
    f:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= TICK_INTERVAL then
            elapsed = 0
            StatsFrame.Tick()
        end
    end)
    f:SetScript("OnShow", function() SelectTab(ns.db.statsTab) end)
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

-- The "Next rank" line (FR-021) and its pin button (FR-022, only with a place the game allows a pin on).
local function RefreshNextRank()
    local advice = ns.Skill.GetNextRank()
    if not advice then
        frame.nextRank:SetText("")
        frame.pin:Hide()
        return
    end
    frame.nextRank:SetText(ns.Skill.DescribeNextRank(advice))
    frame.pin:SetShown(advice.pin ~= nil)
end

-- Everything, including values and rates. Called on show, by the Refresh button, and by Tick when the data changed.
function StatsFrame.Refresh()
    if not (IsShown() and frame.statsPage:IsShown()) then
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
    RefreshNextRank()

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
            local text, icon = ns.ItemDisplay(itemID)
            line.icon:SetTexture(icon)
            line.name:SetText(text)
            line.count:SetText("x" .. items[itemID])
            line.value:SetText(ns.Prices.FormatValue(itemID, items[itemID]))
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

-- Every second: the open page's tick.
function StatsFrame.Tick()
    if not IsShown() then
        return
    end
    for _, page in ipairs(pages) do
        if page.frame:IsShown() then
            page.tick()
        end
    end
end

-- The statistics page's tick: a full refresh when something changed, otherwise just the time rows.
function StatsFrame.TickStatistics()
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

-- Shows the window on the catch catalog; arg as CatalogTab.Show takes it (an item ID, a search text or nil).
function StatsFrame.OpenCatalog(arg)
    frame = frame or Create()
    frame:Show()
    SelectTab("catalog")
    ns.CatalogTab.Show(arg)
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
-- The next-rank line: the level it may wait for (UnitLevel can lag behind PLAYER_LEVEL_UP), and the names of the
-- book, the quest and the rank spells, which the client loads later. Other items, quests and spells are ignored.
ns.RegisterEvent("PLAYER_LEVEL_UP", function() C_Timer.After(1, MarkDirty) end)
local function MarkDirtyForAdvice(_, id)
    for cap, step in pairs(ns.FishingRanks) do
        if id == step.source.itemID or id == step.source.questID or id == step.next
            or id == ns.FishingRankSpells[cap] then
            MarkDirty()
            return
        end
    end
end
ns.RegisterEvent("ITEM_DATA_LOAD_RESULT", MarkDirtyForAdvice)
ns.RegisterEvent("QUEST_DATA_LOAD_RESULT", MarkDirtyForAdvice)
ns.RegisterEvent("SPELL_DATA_LOAD_RESULT", MarkDirtyForAdvice)
ns.RegisterEvent("SPELL_TEXT_UPDATE", MarkDirtyForAdvice) -- the spell subtext (rank name) arrives with it
-- Names, icons and vendor prices of caught items the client did not know yet arrive later.
-- Other items (bags, auction house) and failed lookups are ignored.
ns.RegisterEvent("GET_ITEM_INFO_RECEIVED", function(_, itemID, success)
    if success and IsShown() and ns.Stats.GetTotal().items[itemID] then
        MarkDirty()
    end
end)
