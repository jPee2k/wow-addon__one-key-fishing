-- CatalogTab: the "Catch catalog" page of the statistics window (specs/005-catch-catalog, contracts/ui.md). The list
-- of every item of the database with a search over the client's own names and the filters; choosing an item shows
-- its zones, and each zone expands into its spots. Everything shown comes from Catalog.lua. The search, the
-- filters, the chosen item and the expanded zones live in memory only, so every login starts at the defaults.
local _, ns = ...
local L = ns.L

local CatalogTab = {}
ns.CatalogTab = CatalogTab

local LABEL_X = 20
local LINE_HEIGHT = 18
local ROW_WIDTH = 520
local TOP = -32 -- below the window title
local LIST_TOP = TOP - 62 -- the item list, below the search box and the filter buttons
local ITEM_LIST_TOP = TOP - 46 -- the zone rows, below the item header and the column headers
local BOTTOM = 40 -- the lists end above the status line
local WINDOW_HEIGHT = 660 -- the statistics window (UI/StatsFrame.lua)
local MAX_ROWS = 26 -- rows of the fixed list when the scroll templates are missing
local INDENT = 16 -- spot rows under their zone
-- The zone and spot rows: x and width inside a row, and the text alignment.
local COLUMNS = {
    { key = "name", x = 16, width = 270, justify = "LEFT" },
    { key = "skill", x = 290, width = 70, justify = "LEFT" },
    { key = "chance", x = 360, width = 70, justify = "RIGHT" },
    { key = "catches", x = 435, width = 60, justify = "RIGHT" },
}

local CreateText = ns.CreateText -- Core.lua

local page
local search = ""
local filter = { range = "all", source = "all", water = "all" }
local chosen -- the item ID of the item page, or nil for the list
local expanded = {} -- map ID -> true: zones of the chosen item that show their spots
local drawn -- what the page shows now: { version, state }
local dirty = false

local function Percent(value)
    return ("%d%%"):format(math.floor(value * 100 + 0.5))
end

-- The span of skill an item was caught with ({ min, max } ranges): "0-74", "75-224", "300+", "75+".
local function SpanLabel(ranges)
    if not ranges then
        return ""
    end
    if ranges.min == ranges.max then
        return ns.CatchHere.RangeLabel(ranges.min)
    end
    local from = ranges.min * ns.CatchDB.RANGE_STEP
    if ranges.max == ns.CatchDB.MAX_RANGE then
        return from .. "+"
    end
    return from .. "-" .. ((ranges.max + 1) * ns.CatchDB.RANGE_STEP - 1)
end

-- "N catches from K players" from 2 players on (part 3, FR-025), else "N catches".
local function CatchesLine(catches, players)
    if players >= 2 then
        return (L["%d catches from %d players"]):format(catches, players)
    end
    return (L["%d catches"]):format(catches)
end

local function MarkDirty()
    dirty = true
end

---------------------------------------------------------------------------
-- Lists: the game's scroll list, or a fixed pool of rows with "and N more" when the client lacks the templates
---------------------------------------------------------------------------
local function CreateList(parent, top, initialize)
    local list = { initialize = initialize }
    -- VERIFY(V37): the scroll list, the scroll bar and the search box render inside the statistics window
    local ok = pcall(function()
        local box = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
        box:SetPoint("TOPLEFT", LABEL_X, top)
        box:SetPoint("BOTTOMRIGHT", -LABEL_X - 18, BOTTOM)
        local bar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
        bar:SetPoint("TOPLEFT", box, "TOPRIGHT", 6, 0)
        bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 6, 0)
        local view = CreateScrollBoxListLinearView()
        view:SetElementExtent(LINE_HEIGHT)
        view:SetElementInitializer("Button", initialize)
        ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)
        list.box = box
    end)
    if not ok then
        list.box, list.rows = nil, {}
        local rows = math.min(MAX_ROWS, math.floor((WINDOW_HEIGHT + top - BOTTOM) / LINE_HEIGHT) - 1)
        for i = 1, rows do
            local row = CreateFrame("Button", nil, parent)
            row:SetSize(ROW_WIDTH, LINE_HEIGHT)
            row:SetPoint("TOPLEFT", LABEL_X, top - (i - 1) * LINE_HEIGHT)
            list.rows[i] = row
        end
        list.more = CreateText(parent, "GameFontDisableSmall")
        list.more:SetPoint("TOPLEFT", LABEL_X, top - rows * LINE_HEIGHT - 2)
    end
    -- Shows the elements; retain keeps the scroll position (new data, FR-028).
    function list.Show(elements, retain)
        if list.box then
            list.box:SetDataProvider(CreateDataProvider(elements), retain and true or nil)
            return
        end
        for i, row in ipairs(list.rows) do
            if elements[i] then
                list.initialize(row, elements[i])
                row:Show()
            else
                row:Hide()
            end
        end
        local more = #elements - #list.rows
        list.more:SetText(more > 0 and (L["and %d more"]):format(more) or "")
    end
    return list
end

---------------------------------------------------------------------------
-- The item list
---------------------------------------------------------------------------
local function InitItemRow(row, element)
    if not row.name then
        row:SetSize(ROW_WIDTH, LINE_HEIGHT)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(16, 16)
        row.icon:SetPoint("LEFT")
        row.name = CreateText(row, "GameFontHighlight")
        row.name:SetPoint("LEFT", 22, 0)
        row.name:SetWidth(380)
        row.name:SetWordWrap(false)
        row.zones = CreateText(row, "GameFontHighlight", "RIGHT")
        row.zones:SetPoint("RIGHT", -4, 0)
        row.zones:SetWidth(110)
        row:SetScript("OnEnter", function(self)
            ns.ShowItemTooltip(self, self.itemID, true) -- with its own "Caught in" lines (UI/ItemHooks.lua)
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:SetScript("OnClick", function(self) CatalogTab.Show(self.itemID) end)
    end
    row.itemID = element.itemID
    local text, icon = ns.ItemDisplay(element.itemID)
    row.icon:SetTexture(icon)
    row.name:SetText(text)
    row.zones:SetText((L["Zones: %d"]):format(element.zones))
end

---------------------------------------------------------------------------
-- The item page: zone rows and their spot rows
---------------------------------------------------------------------------
local function ShowPlaceTooltip(self)
    local element = self.element
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if element.kind == "zone" then
        GameTooltip:AddLine(element.place.name)
    else
        local spot = element.place
        local area = spot.area and C_Map.GetAreaInfo(spot.area)
        GameTooltip:AddLine(type(area) == "string" and area ~= "" and area or element.zone)
        if spot.point then
            GameTooltip:AddLine(("%d, %d"):format(math.floor(spot.point.x * 100 + 0.5),
                math.floor(spot.point.y * 100 + 0.5)), 1, 1, 1)
        end
    end
    GameTooltip:AddLine(CatchesLine(element.place.catches, element.place.players), 1, 1, 1)
    GameTooltip:Show()
end

local function InitPlaceRow(row, element)
    if not row.name then
        row:SetSize(ROW_WIDTH, LINE_HEIGHT)
        row.toggle = CreateText(row, "GameFontNormal")
        row.toggle:SetPoint("LEFT", 2, 0)
        for _, column in ipairs(COLUMNS) do
            local text = CreateText(row, "GameFontHighlight", column.justify)
            text:SetPoint("LEFT", column.x, 0)
            text:SetWidth(column.width)
            text:SetWordWrap(false)
            row[column.key] = text
        end
        row:SetScript("OnEnter", ShowPlaceTooltip)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:SetScript("OnClick", function(self)
            if self.element.kind == "zone" then
                CatalogTab.Toggle(self.element.place.mapID)
            end
        end)
    end
    row.element = element
    local place = element.place
    local zone = element.kind == "zone"
    row.toggle:SetText(zone and (expanded[place.mapID] and "-" or "+") or "")
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", COLUMNS[1].x + (zone and 0 or INDENT), 0)
    row.name:SetWidth(COLUMNS[1].width - (zone and 0 or INDENT))
    row.name:SetText(place.name)
    row.skill:SetText(SpanLabel(place.ranges))
    row.chance:SetText(place.littleData and L["Little data"] or Percent(place.chance))
    row.catches:SetText(tostring(place.catches))
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------
local function OpenSkillMenu(owner)
    local choices = {}
    for _, range in ipairs(ns.CatchDB.RANGES) do
        table.insert(choices, { value = range, text = ns.CatchHere.RangeLabel(range) })
    end
    table.insert(choices, { value = "all", text = ns.CatchHere.RangeLabel("all") })
    ns.OpenRadioMenu(owner, choices, function(value) return filter.range == value end, CatalogTab.SetRange)
end

local function OpenSourceMenu(owner)
    local choices = { { value = "all", text = ns.CatchHere.SourceLabel("all") },
        { value = "mine", text = ns.CatchHere.SourceLabel("mine") } }
    ns.OpenRadioMenu(owner, choices, function(value) return filter.source == value end, CatalogTab.SetSource)
end

function CatalogTab.SetRange(range)
    filter.range = range
    CatalogTab.Refresh()
end

function CatalogTab.SetSource(value)
    filter.source = value
    CatalogTab.Refresh()
end

-- A search box: the game's SearchBoxTemplate, or a plain input box without it.
local function CreateSearchBox(parent)
    local ok, box = pcall(CreateFrame, "EditBox", nil, parent, "SearchBoxTemplate")
    if not (ok and box) then
        box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    end
    box:SetSize(300, 20)
    box:SetAutoFocus(false)
    if box.Instructions then
        box.Instructions:SetText(L["Search by item name"])
    end
    -- Hooked, not set: the template's own handler shows and hides the hint and the clear button.
    box:HookScript("OnTextChanged", function(self)
        search = self:GetText() or ""
        CatalogTab.Refresh()
    end)
    return box
end

-- The page, a child of the statistics window covering the same area (hidden until its tab is chosen).
function CatalogTab.Create(parent)
    page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()

    page.listView = CreateFrame("Frame", nil, page)
    page.listView:SetAllPoints()
    page.search = CreateSearchBox(page.listView)
    page.search:SetPoint("TOPLEFT", LABEL_X + 6, TOP)
    page.skillButton = ns.CreateButton(page.listView, "", 150, function(self) OpenSkillMenu(self) end)
    page.skillButton:SetPoint("TOPLEFT", LABEL_X - 4, TOP - 28)
    page.sourceButton = ns.CreateButton(page.listView, "", 150, function(self) OpenSourceMenu(self) end)
    page.sourceButton:SetPoint("LEFT", page.skillButton, "RIGHT", 8, 0)
    page.list = CreateList(page.listView, LIST_TOP, InitItemRow)

    page.itemView = CreateFrame("Frame", nil, page)
    page.itemView:SetAllPoints()
    page.back = ns.CreateButton(page.itemView, L["Back"], 80, function() CatalogTab.Show(nil) end)
    page.back:SetPoint("TOPLEFT", LABEL_X - 4, TOP + 2)
    page.icon = page.itemView:CreateTexture(nil, "ARTWORK")
    page.icon:SetSize(18, 18)
    page.icon:SetPoint("LEFT", page.back, "RIGHT", 10, 0)
    page.title = CreateText(page.itemView, "GameFontNormal")
    page.title:SetPoint("LEFT", page.icon, "RIGHT", 6, 0)
    page.title:SetWidth(400)
    local headers = { name = L["Place"], skill = L["Skill"], chance = L["Chance"], catches = L["Catches"] }
    for _, column in ipairs(COLUMNS) do
        local header = CreateText(page.itemView, "GameFontNormalSmall", column.justify)
        header:SetPoint("TOPLEFT", LABEL_X + column.x, ITEM_LIST_TOP + LINE_HEIGHT + 4)
        header:SetWidth(column.width)
        header:SetText(headers[column.key])
    end
    page.places = CreateList(page.itemView, ITEM_LIST_TOP, InitPlaceRow)
    page.itemView:Hide()

    page.status = CreateText(page, "GameFontDisable")
    page.status:SetPoint("BOTTOMLEFT", LABEL_X, BOTTOM - 26)
    page.status:SetWidth(540)
    page:Hide()
    return page
end

local function StatusText(items, state)
    if state == "building" then
        return L["Counting the catch..."]
    elseif #items > 0 then
        return ""
    elseif search ~= "" then
        return L["No item matches the search."]
    elseif filter.source == "mine" then
        return L["You have not caught anything yet."]
    end
    return L["Nothing has been caught yet."] .. "\n"
        .. L["The catalog fills with your catches, the bundled data and, with sharing on, other players' catches."]
end

local function ShowList(retain)
    local items, state = ns.Catalog.Items(filter, search)
    page.list.Show(items, retain)
    page.status:SetText(StatusText(items, state))
    return state
end

local function ShowItem(retain)
    local text, icon = ns.ItemDisplay(chosen)
    page.icon:SetTexture(icon)
    page.title:SetText(text)
    local elements = {}
    local places = ns.Catalog.Places(chosen, filter)
    for _, place in ipairs(places) do
        table.insert(elements, { kind = "zone", place = place })
        if expanded[place.mapID] then
            for _, spot in ipairs(ns.Catalog.Spots(chosen, place.mapID, filter)) do
                table.insert(elements, { kind = "spot", place = spot, zone = place.name, mapID = place.mapID })
            end
        end
    end
    page.places.Show(elements, retain)
    page.status:SetText(#places == 0 and L["No data for this item under these filters."] or "")
end

-- Redraws the page; retain (the tick, new data) keeps the scroll positions.
function CatalogTab.Refresh(retain)
    if not (page and page:IsShown()) then
        return
    end
    dirty = false
    page.skillButton:SetText((L["Skill: %s"]):format(ns.CatchHere.RangeLabel(filter.range)))
    page.sourceButton:SetText((L["Source: %s"]):format(ns.CatchHere.SourceLabel(filter.source)))
    page.listView:SetShown(chosen == nil)
    page.itemView:SetShown(chosen ~= nil)
    local state
    if chosen then
        ShowItem(retain)
    else
        state = ShowList(retain)
    end
    drawn = { version = ns.Catalog.GetVersion(), state = state }
end

-- Every second while the page is shown: a read brings the catalog up to date, and the page redraws when it moved.
function CatalogTab.Tick()
    if not (page and page:IsShown()) then
        return
    end
    local _, state = ns.Catalog.Items(filter, search)
    if dirty or not drawn or drawn.version ~= ns.Catalog.GetVersion() or (not chosen and drawn.state ~= state) then
        CatalogTab.Refresh(true)
    end
end

-- Expands or folds a zone of the chosen item.
function CatalogTab.Toggle(mapID)
    expanded[mapID] = not expanded[mapID] or nil
    CatalogTab.Refresh(true)
end

-- arg: an item ID chooses that item (or, outside the catalog, puts its name into the search); a text fills the
-- search and chooses the item when exactly one matches; nil shows the list (FR-024, FR-025).
function CatalogTab.Show(arg)
    if type(arg) == "number" then
        if #ns.Catalog.Places(arg, filter) > 0 then
            chosen, expanded = arg, {}
        else
            chosen = nil
            CatalogTab.SetSearch(C_Item.GetItemNameByID(arg) or tostring(arg))
        end
    elseif type(arg) == "string" then
        chosen = nil
        CatalogTab.SetSearch(arg)
        local found = ns.Catalog.Find(arg)
        if #found == 1 then
            chosen, expanded = found[1], {}
        end
    else
        chosen = nil
    end
    CatalogTab.Refresh()
end

function CatalogTab.SetSearch(text)
    search = text
    if page then
        page.search:SetText(text)
    end
end

ns.On("PRICES_CHANGED", MarkDirty) -- the item tooltips' prices
ns.On("SETTINGS_CHANGED", MarkDirty)
