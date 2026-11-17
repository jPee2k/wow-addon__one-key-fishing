-- CatchHere: the "What can be caught here" page of the statistics window. It lists the items of the player's
-- current spot from CatchDB.Query (or of the whole map when the spot has few catches), with a skill filter and
-- a source filter. The filters live in memory only, so every login starts at the defaults: the player's own
-- skill range (followed while the rank grows, until a range is picked by hand) and all sources. The items are
-- grouped under kind headers, and a kind menu hides kinds (specs/014-catch-filters); that choice is saved
-- (settings.hiddenKinds, through Catalog.SetKindShown) and shared with the catalog tab.
local _, ns = ...
local L = ns.L

local CatchHere = {}
ns.CatchHere = CatchHere

local LABEL_X = 20
local LINE_HEIGHT = 18
local MAX_ROWS = 16
-- The Kinds button (spec 014) sits at the top right of both tabs, on the row of the place (here) or of the search
-- box (the catalog), so the filter row keeps its width in every language.
local KIND_WIDTH = 120
CatchHere.KIND_WIDTH = KIND_WIDTH
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

-- The kind menu (spec 014), also the catalog's: one checkbox per kind; a click saves the choice, and its
-- SETTINGS_CHANGED("hiddenKinds") redraws each tab at once (FR-007; the handler at the end of each tab's file).
function CatchHere.OpenKindMenu(owner)
    local choices = {}
    for _, kind in ipairs(ns.Catalog.KINDS) do
        table.insert(choices, { value = kind, text = ns.Catalog.KindText(kind) })
    end
    ns.OpenCheckboxMenu(owner, choices, ns.Catalog.IsKindShown, function(kind)
        ns.Catalog.SetKindShown(kind, not ns.Catalog.IsKindShown(kind))
    end)
end

-- "Kinds: all" or "Kinds: N of 5" (FR-009).
function CatchHere.KindLabel()
    local count, total = ns.Catalog.ShownKinds()
    return count == total and L["Kinds: all"] or (L["Kinds: %d of %d"]):format(count, total)
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
    -- A header row (a kind's name over its items) shows only this text.
    row.header = CreateText(row, "GameFontNormal")
    row.header:SetPoint("LEFT", 0, 0)
    row.header:SetWidth(540)
    row.header:Hide()
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
    page.place:SetWidth(400) -- the Kinds button is to its right
    page.place:SetWordWrap(false) -- one line: the scope and counts lines below sit at fixed places
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
    page.kindButton = ns.CreateButton(page, "", KIND_WIDTH, CatchHere.OpenKindMenu)
    page.kindButton:SetPoint("TOPRIGHT", -LABEL_X, TOP + 3)
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

-- Shows the row's item columns, or (as a header) only the kind's text.
local function ShowColumns(row, visible)
    row.icon:SetShown(visible)
    for _, column in ipairs(COLUMNS) do
        row[column.key]:SetShown(visible)
    end
    row.header:SetShown(not visible)
end

-- A header row: Refresh cleared its item, so the row's scripts do nothing on it.
local function SetHeader(row, kind)
    ShowColumns(row, false)
    row.header:SetText(ns.Catalog.KindText(kind))
    row:Show()
end

local function FillRow(row, item, littleData)
    ShowColumns(row, true)
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
    page.kindButton:SetText(CatchHere.KindLabel())
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
    -- The view's items the client does not know yet, drawn or not: one hidden as Other may load as another kind
    -- (spec 014).
    shown.unknownIDs = {}
    for _, item in ipairs(view.items) do
        if C_Item.GetItemInfoInstant(item.itemID) == nil then
            shown.unknownIDs[item.itemID] = true
        end
    end
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
        -- The items under their kind headers (spec 014); headers take rows too, "and N more" counts items only.
        local list, hidden = ns.Catalog.Group(view.items)
        local used, drawn = 0, 0
        for _, element in ipairs(list) do
            -- A header needs room for one of its items after it.
            if used == MAX_ROWS or (element.header and used + 1 == MAX_ROWS) then
                break
            end
            used = used + 1
            if element.header then
                SetHeader(page.rows[used], element.header)
            else
                drawn = drawn + 1
                FillRow(page.rows[used], element, view.littleData)
            end
        end
        local itemsShown = #view.items - hidden
        if itemsShown > drawn then
            page.more:SetText((L["and %d more"]):format(itemsShown - drawn))
        end
        if #view.items > 0 and itemsShown == 0 then
            page.message:SetText(L["The kind filter hides every item."]) -- not "no data" (FR-011)
        end
        if itemsShown > 0 then
            table.insert(hints, L["Click an item to see where else it is caught."])
        end
        if view.littleData and filter.range ~= "all" then
            table.insert(hints, L["Try \"All skill levels\": little data for your skill."])
        end
    end
    if source == "all" and not ns.CatchDB.HasSeed() then
        -- With another player's catches behind these numbers they are not only the own (spec 012 US2).
        table.insert(hints, view.others and L["No bundled data in this version."]
            or L["No bundled data in this version: only your own catches are shown."])
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
-- A kind toggled in the menu redraws at once (FR-007); a hidden page redraws when shown again (dirty).
ns.On("SETTINGS_CHANGED", function(key)
    MarkDirty()
    if key == "hiddenKinds" then
        CatchHere.Refresh()
    end
end)

-- An item the game now knows: a drawn row gets its name; an item unknown at the last draw, hidden as Other, may
-- move to a shown kind (spec 014).
local function ItemArrived(_, itemID, success)
    if not (success and page and page:IsShown()) then
        return
    end
    if shown and shown.unknownIDs and shown.unknownIDs[itemID] then
        dirty = true
    end
    for _, row in ipairs(page.rows) do
        if row.itemID == itemID then
            dirty = true
        end
    end
end
ns.RegisterEvent("GET_ITEM_INFO_RECEIVED", ItemArrived)
ns.RegisterEvent("ITEM_DATA_LOAD_RESULT", ItemArrived) -- an unknown item the game now knows: its name and icon
