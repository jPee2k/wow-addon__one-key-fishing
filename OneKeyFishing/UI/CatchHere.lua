-- CatchHere: the "What can be caught here" page of the statistics window. It lists the items of the player's
-- current spot from CatchDB.Query (or of the whole map when the spot has few catches), with a skill filter and
-- a source filter. The filters live in memory only, so every login starts at the defaults: the player's own
-- skill range (followed while the rank grows, until a range is picked by hand) and all sources.
local _, ns = ...
local L = ns.L

local CatchHere = {}
ns.CatchHere = CatchHere

local LABEL_X = 20
local LINE_HEIGHT = 18
local MAX_ROWS = 16
local TOP = -32 -- below the window title
-- The item table: x and width inside a row (a row starts at LABEL_X), and the text alignment.
local COLUMNS = {
    { key = "name", x = 26, width = 220, justify = "LEFT" },
    { key = "chance", x = 250, width = 90, justify = "RIGHT" },
    { key = "pieces", x = 350, width = 70, justify = "RIGHT" },
    { key = "price", x = 430, width = 110, justify = "RIGHT" },
}
local ROWS_TOP = TOP - 116 -- the column headers; the rows follow

local CreateText = ns.CreateText -- UI/Widgets.lua

local page
local pickedRange -- a range (0..4 or "all") picked by hand since login; nil follows the own range
local source = "all"
local water = "all" -- "all" | "open" | "pool": the Water filter, offered once pool data exists (part 4, FR-021)
local shown -- what the page shows now: { version, mapID, ownRange, cell, range }
local dirty = false
-- The map and the skill range change only with these events (zone changes, loading screens, skill-ups); between
-- them the page follows the player's cell with one position lookup per second.
local placeChanged = true

local RangeLabel = ns.RangeLabel -- UI/Widgets.lua: "0-74", ..., "300+"; "All skill levels" for "all"

local function SourceLabel(value)
    return value == "mine" and L["Only mine"] or L["All"]
end

local function WaterLabel(value)
    return value == "pool" and L["Pools"] or (value == "open" and L["Open water"] or L["Everywhere"])
end
-- The catalog's buttons read the same.
CatchHere.SourceLabel, CatchHere.WaterLabel = SourceLabel, WaterLabel

-- The Water filter's menu: choose(value) runs on a click (also the catalog's).
function CatchHere.OpenWaterMenu(owner, current, choose)
    local choices = {}
    for _, value in ipairs({ "all", "open", "pool" }) do
        table.insert(choices, { value = value, text = WaterLabel(value) })
    end
    ns.OpenRadioMenu(owner, choices, function(value) return current() == value end, choose)
end

function CatchHere.SetWater(value)
    water = value
    dirty = true
    CatchHere.Refresh()
end

-- The skill filter: the one picked by hand, else the own range.
local function EffectiveRange(ownRange)
    return pickedRange or ownRange or "all"
end

function CatchHere.SetRange(range)
    pickedRange = range
    dirty = true
    CatchHere.Refresh()
end

function CatchHere.SetSource(value)
    source = value
    dirty = true
    CatchHere.Refresh()
end

-- The skill and source menus, like the Water menu above (also the catalog's): current() is the chosen value.
function CatchHere.OpenSkillMenu(owner, current, choose)
    local choices = {}
    for _, range in ipairs(ns.CatchDB.RANGES) do
        table.insert(choices, { value = range, text = RangeLabel(range) })
    end
    table.insert(choices, { value = "all", text = RangeLabel("all") })
    ns.OpenRadioMenu(owner, choices, function(value) return current() == value end, choose)
end

function CatchHere.OpenSourceMenu(owner, current, choose)
    local choices = { { value = "all", text = SourceLabel("all") }, { value = "mine", text = SourceLabel("mine") } }
    ns.OpenRadioMenu(owner, choices, function(value) return current() == value end, choose)
end

local function CreateRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(540, LINE_HEIGHT)
    row:SetPoint("TOPLEFT", LABEL_X, ROWS_TOP - index * LINE_HEIGHT)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT")
    for _, column in ipairs(COLUMNS) do
        local text = CreateText(row, "GameFontHighlight", column.justify)
        text:SetPoint("LEFT", column.x, 0)
        text:SetWidth(column.width)
        text:SetWordWrap(false)
        row[column.key] = text
    end
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        local unknown = self.unknown
        if unknown then
            -- An item the client does not know yet (specs/004-public-channel-sync, FR-017a): no game tooltip.
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(L["Unknown item"])
            GameTooltip:AddLine(L["The game has not shown this item yet."], 1, 1, 1, true)
            GameTooltip:AddLine(unknown.inSeed and L["In the bundled data"]
                or (L["Reported by %d players on this map"]):format(unknown.reporters), 1, 1, 1, true)
            GameTooltip:AddLine((L["Item ID: %d"]):format(unknown.itemID), 0.6, 0.6, 0.6)
            GameTooltip:Show()
        elseif self.itemID then
            ns.ShowItemTooltip(self, self.itemID, true)
        end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- A known item opens the catalog on it (FR-024); an "Unknown item" has no name to show there.
    row:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and self.itemID and not self.unknown then
            ns.StatsFrame.OpenCatalog(self.itemID)
        end
    end)
    return row
end

-- The page, a child of the statistics window covering the same area (hidden until its tab is chosen).
function CatchHere.Create(parent)
    page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page.place = CreateText(page, "GameFontNormal")
    page.place:SetPoint("TOPLEFT", LABEL_X, TOP)
    page.place:SetWidth(540)
    page.scope = CreateText(page, "GameFontDisableSmall")
    page.scope:SetPoint("TOPLEFT", page.place, "BOTTOMLEFT", 0, -4)
    page.scope:SetWidth(540)
    page.counts = CreateText(page, "GameFontHighlight")
    page.counts:SetPoint("TOPLEFT", LABEL_X, TOP - 40)
    page.counts:SetWidth(540)

    page.skillButton = ns.CreateButton(page, "", 150, function(self)
        CatchHere.OpenSkillMenu(self, function() return shown and shown.range end, CatchHere.SetRange)
    end)
    page.skillButton:SetPoint("TOPLEFT", LABEL_X - 4, TOP - 62)
    page.sourceButton = ns.CreateButton(page, "", 150, function(self)
        CatchHere.OpenSourceMenu(self, function() return source end, CatchHere.SetSource)
    end)
    page.sourceButton:SetPoint("LEFT", page.skillButton, "RIGHT", 8, 0)
    page.waterButton = ns.CreateButton(page, "", 150, function(self)
        CatchHere.OpenWaterMenu(self, function() return water end, CatchHere.SetWater)
    end)
    page.waterButton:SetPoint("LEFT", page.sourceButton, "RIGHT", 8, 0)
    page.waterButton:Hide()

    local headers = { name = L["Item"], chance = L["Chance"], pieces = L["Per catch"], price = L["Price"] }
    for _, column in ipairs(COLUMNS) do
        local header = CreateText(page, "GameFontNormalSmall", column.justify)
        header:SetPoint("TOPLEFT", LABEL_X + column.x, ROWS_TOP)
        header:SetWidth(column.width)
        header:SetText(headers[column.key])
    end

    page.rows = {}
    for i = 1, MAX_ROWS do
        page.rows[i] = CreateRow(page, i)
    end
    page.more = CreateText(page, "GameFontDisableSmall")
    page.more:SetPoint("TOPLEFT", LABEL_X, ROWS_TOP - (MAX_ROWS + 1) * LINE_HEIGHT - 4)
    page.message = CreateText(page, "GameFontDisable")
    page.message:SetPoint("TOPLEFT", LABEL_X, ROWS_TOP - LINE_HEIGHT - 4)
    page.message:SetWidth(540)
    page.hint = CreateText(page, "GameFontDisableSmall")
    page.hint:SetPoint("TOPLEFT", page.more, "BOTTOMLEFT", 0, -6)
    page.hint:SetWidth(540)
    -- The quiet state of the exchange with other players (Share.lua): one line of small text.
    page.status = CreateText(page, "GameFontDisableSmall")
    page.status:SetPoint("TOPLEFT", page.hint, "BOTTOMLEFT", 0, -6)
    page.status:SetWidth(540)
    page:Hide()
    return page
end

local loadAsked = {} -- item IDs asked from the game this session

local function FillRow(row, item, littleData)
    row.itemID = item.itemID
    -- Read when drawn, not from the cached view: the game may have learned the item since (ITEM_DATA_LOAD_RESULT).
    if C_Item.GetItemInfoInstant(item.itemID) ~= nil then
        row.unknown = nil
        local text, icon = ns.ItemDisplay(item.itemID)
        row.icon:SetTexture(icon)
        row.name:SetText(text)
        row.price:SetText(ns.Prices.FormatValue(item.itemID))
    else
        row.unknown = item
        -- GetItemInfoInstant returns nothing for an item the client does not know yet, the question mark icon exists,
        -- and asking the game may make the item known (V27, seen in game)
        row.icon:SetTexture(ns.GameData.Icons.unknownItem)
        row.name:SetText(L["Unknown item"])
        row.price:SetText("")
        if not loadAsked[item.itemID] and C_Item.RequestLoadItemDataByID then
            loadAsked[item.itemID] = true
            C_Item.RequestLoadItemDataByID(item.itemID)
        end
    end
    row.chance:SetText(ns.Catalog.ChanceText(item.chance, littleData))
    row.pieces:SetText(("%.1f"):format(item.pieces))
    row:Show()
end

-- Redraws the page for a place (CatchDB.GetCurrentPlace; read here when not given).
function CatchHere.Refresh(mapID, ownRange, cell)
    if not (page and page:IsShown()) then
        return
    end
    if mapID == nil then
        mapID, ownRange, cell = ns.CatchDB.GetCurrentPlace()
    end
    dirty = false
    page.status:SetText(ns.Share.StatusLine())
    local pools = ns.CatchDB.HasPoolData()
    local filter = { range = EffectiveRange(ownRange), source = source, water = pools and water or "all" }
    shown = { version = ns.CatchDB.GetVersion(), mapID = mapID, ownRange = ownRange, cell = cell,
        range = filter.range }
    page.skillButton:SetText((L["Skill: %s"]):format(RangeLabel(filter.range)))
    page.sourceButton:SetText((L["Source: %s"]):format(SourceLabel(source)))
    page.waterButton:SetText((L["Water: %s"]):format(WaterLabel(filter.water)))
    page.waterButton:SetShown(pools)
    page.more:SetText("")
    page.message:SetText("")
    for _, row in ipairs(page.rows) do
        row.itemID, row.unknown = nil, nil
        row:Hide()
    end
    local hints = {}
    if not mapID then
        page.place:SetText(ns.Skill.Get() and L["The game does not show this place on the map."]
            or L["Fishing is not learned."])
        page.scope:SetText("")
        page.counts:SetText("")
        page.hint:SetText("")
        return
    end
    page.place:SetText(ns.Stats.PlaceName(mapID))
    local view = ns.CatchDB.Query(mapID, cell, filter)
    page.scope:SetText(view.scope == "map" and L["Numbers for the whole map: few catches at this spot."] or "")
    if view.scope == "none" then
        page.counts:SetText("")
        page.message:SetText(L["Nothing has been caught here yet."])
    else
        -- "from K players" once other players are behind the numbers (none under "Only mine").
        local catches = ns.Catalog.CatchesText(view.catches, view.players)
        -- The miss rate is weighted (part 3, research R7), and nil under a water filter: a miss has no source.
        page.counts:SetText(view.missRate and (catches .. "    " ..
            (L["Nothing caught: %s"]):format(ns.Percent(view.missRate))) or catches)
        for i, item in ipairs(view.items) do
            if i > MAX_ROWS then
                page.more:SetText((L["and %d more"]):format(#view.items - MAX_ROWS))
                break
            end
            FillRow(page.rows[i], item, view.littleData)
        end
        table.insert(hints, L["Click an item to see where else it is caught."])
        if view.littleData and filter.range ~= "all" then
            table.insert(hints, L["Try \"All skill levels\": little data for your skill."])
        end
    end
    if source == "all" and not ns.CatchDB.HasSeed() then
        table.insert(hints, L["No bundled data in this version: only your own catches are shown."])
    end
    page.hint:SetText(table.concat(hints, "\n"))
end

-- Every second while the page is shown: a refresh when the data, the place or a filter changed.
function CatchHere.Tick()
    if not (page and page:IsShown()) then
        return
    end
    local mapID, ownRange, cell
    if placeChanged or not shown or not shown.mapID then
        placeChanged = false
        mapID, ownRange, cell = ns.CatchDB.GetCurrentPlace()
    else
        mapID, ownRange, cell = shown.mapID, shown.ownRange, ns.CatchDB.GetCell(shown.mapID)
    end
    if dirty or not shown or shown.version ~= ns.CatchDB.GetVersion() or shown.mapID ~= mapID
        or shown.cell ~= cell or shown.range ~= EffectiveRange(ownRange) then
        CatchHere.Refresh(mapID, ownRange, cell)
    else
        page.status:SetText(ns.Share.StatusLine()) -- the state of the exchange changes with time alone
    end
end

local function PlaceChanged()
    placeChanged = true
end
for _, event in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD",
    "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL" }) do
    ns.RegisterEvent(event, PlaceChanged)
end

-- Prices, the auction price setting and item names change what the rows show; the tick redraws once for a
-- burst of them.
local function MarkDirty()
    dirty = true
end
ns.On("PRICES_CHANGED", MarkDirty)
ns.On("SETTINGS_CHANGED", MarkDirty)

local function ItemArrived(_, itemID, success)
    if success and page and page:IsShown() then
        for _, row in ipairs(page.rows) do
            if row.itemID == itemID then
                dirty = true
            end
        end
    end
end
ns.RegisterEvent("GET_ITEM_INFO_RECEIVED", ItemArrived)
ns.RegisterEvent("ITEM_DATA_LOAD_RESULT", ItemArrived) -- an unknown item the game now knows: its name and icon
