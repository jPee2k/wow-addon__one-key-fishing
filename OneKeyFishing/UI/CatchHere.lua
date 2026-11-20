-- CatchHere: the "What can be caught here" page of the statistics window. It lists the items of the player's
-- current spot from CatchDB.Query (or of the whole map when the spot has few catches), with a skill filter and
-- a source filter. The filters live in memory only, so every login starts at the defaults: the player's own
-- skill range (followed while the rank grows, until a range is picked by hand) and all sources. The items are
-- grouped under kind headers, and a kind menu hides kinds (specs/014-catch-filters); that choice is saved
-- (settings.hiddenKinds, through Catalog.SetKindShown) and shared with the catalog tab. The hints and the exchange
-- line sit at the top under the place, and the list scrolls (ns.CreateList, shared with the catalog; spec 020).
local _, ns = ...
local L = ns.L

local CatchHere = {}
ns.CatchHere = CatchHere

local LABEL_X = 20
local LINE_HEIGHT = 18
local KIND_WIDTH = 120 -- the Kinds button, in row B of both tabs (spec 020)
CatchHere.KIND_WIDTH = KIND_WIDTH
local BUTTON_GAP = 8
local TOP = -32 -- below the window title
-- From the top (spec 020 decisions 28-30, the same order as the statistics page: the title, small grey lines, then
-- the table): the place; the scope line; the hints (up to three lines, their room always kept, so nothing below
-- moves); the exchange line; the counts; row A (Skill, Source); row B (Water or Camp bonus, Kinds); the column
-- headers; the list.
local SCOPE_TOP = TOP - 18
local HINT_TOP = TOP - 32
local STATUS_TOP = TOP - 70
local COUNTS_TOP = TOP - 88
local ROW_A_TOP = TOP - 108
local ROW_B_TOP = TOP - 134
local ROWS_TOP = TOP - 164 -- the column headers; the list follows
-- The item table: x and width inside a row (a row starts at LABEL_X), and the text alignment. The last column ends
-- at 520: the scroll list (ns.CreateList) is 522 wide and clips what lies beyond, the scroll bar is to its right.
local COLUMNS = {
    { key = "name", x = 26, width = 220, justify = "LEFT" },
    { key = "chance", x = 250, width = 85, justify = "RIGHT" },
    { key = "pieces", x = 340, width = 65, justify = "RIGHT" },
    { key = "price", x = 410, width = 110, justify = "RIGHT" },
}

local CreateText = ns.CreateText -- UI/Widgets.lua

local page
local pickedRange -- a range (0..4 or "all") picked by hand since login; nil follows the own range
local source = "all"
local water = "all" -- "all" | "open" | "pool": the Water filter, offered once pool data exists (part 4, FR-021)
-- "all" | "none" | "bonusOnly" | a bonus key: the Camp bonus filter, offered once bonus data exists (spec 020); it
-- takes the Water button's place, and the water then reads as "all"
local bonus = "all"
local shown -- what the page shows now: { version, mapID, ownRange, cell, range, itemIDs, unknownIDs }
local shownView -- the view the list's rows are drawn from
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

-- The "Camp bonus" filter (specs/020-camp-buffs, research R8): "all", "none", "bonusOnly" or a bonus's key, in
-- memory only; the menu offers "All catches", "No camp bonus", "Bonus catches only" and each bonus with data (also
-- the catalog's). current() is the value.
function CatchHere.OpenBonusMenu(owner, current, choose)
    local choices = {}
    for _, value in ipairs({ "all", "none", "bonusOnly" }) do
        table.insert(choices, { value = value, text = ns.Catalog.BonusLabel(value) })
    end
    for _, key in ipairs(ns.CatchDB.BonusKeys()) do
        if ns.CatchDB.HasBonusData(key) then
            table.insert(choices, { value = key, text = ns.Catalog.BonusLabel(key) })
        end
    end
    ns.OpenRadioMenu(owner, choices, function(value) return current() == value end, choose)
end

-- The value the filter can have now: "all" without bonus data, or for a bonus no longer offered (FR-027).
function CatchHere.OfferedBonus(value)
    if not ns.CatchDB.HasBonusData() then
        return "all"
    end
    if value ~= "all" and value ~= "none" and value ~= "bonusOnly" and not ns.CatchDB.HasBonusData(value) then
        return "all"
    end
    return value
end

-- The button's tooltip: its title and the two agreed lines (both tabs).
function CatchHere.ShowBonusButtonTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L["Camp bonus"])
    local tip =
        L["Show the catches made with a camp bonus: the fishing buff of a Fishing Rack or a Fishing Hut by a campfire."]
    GameTooltip:AddLine(tip, 1, 1, 1, true)
    GameTooltip:AddLine(L["\"No camp bonus\" also holds older catches for which the bonus is not known."], 1, 1, 1,
        true)
    GameTooltip:Show()
end

-- A button of the one slot at the start of row B (both tabs, research R8): x, y its place in the parent.
local function SlotButton(parent, x, y, onClick)
    local button = ns.CreateButton(parent, "", 150, onClick)
    button:SetPoint("TOPLEFT", x, y)
    button.slotX, button.slotY = x, y
    button:Hide()
    return button
end

-- The Water button of a tab: current() is the filter's value, choose(value) sets it.
function CatchHere.CreateWaterButton(parent, x, y, current, choose)
    return SlotButton(parent, x, y, function(self)
        CatchHere.OpenWaterMenu(self, current, choose)
    end)
end

-- The Camp bonus button of a tab, in the Water button's place: current() is the filter's value, choose(value) sets it.
function CatchHere.CreateBonusButton(parent, x, y, current, choose)
    local button = SlotButton(parent, x, y, function(self)
        CatchHere.OpenBonusMenu(self, current, choose)
    end)
    button:SetScript("OnEnter", CatchHere.ShowBonusButtonTooltip)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return button
end

-- The one slot of the Water and the Camp bonus buttons (research R8), for both tabs: the Camp bonus button once bonus
-- data exists, else the Water button once pool data exists; the two filters do not combine. Sets both buttons,
-- places `nextButton` after the shown one (or at the slot when none shows) and returns the water and the bonus the
-- tab's filter keeps.
function CatchHere.UpdateFilterSlot(waterButton, bonusButton, water, bonus, nextButton)
    local bonusData = ns.CatchDB.HasBonusData()
    local pools = ns.CatchDB.HasPoolData() and not bonusData
    water = pools and water or "all"
    bonus = CatchHere.OfferedBonus(bonus)
    waterButton:SetText((L["Water: %s"]):format(WaterLabel(water)))
    waterButton:SetShown(pools)
    bonusButton:SetText(ns.Catalog.BonusButtonText(bonus))
    bonusButton:SetShown(bonusData)
    nextButton:ClearAllPoints()
    local before = (bonusData and bonusButton) or (pools and waterButton) or nil
    if before then
        nextButton:SetPoint("LEFT", before, "RIGHT", BUTTON_GAP, 0)
    else
        nextButton:SetPoint("TOPLEFT", waterButton.slotX, waterButton.slotY)
    end
    return water, bonus
end

-- The filter a view is queried with: "Bonus catches only" reads the "All catches" view and keeps the tagged items
-- (spec 020 decisions 24 to 26): a list filter, like the kinds.
function CatchHere.QueryBonus(value)
    return value == "bonusOnly" and "all" or value
end

-- The items a tab lists under the camp bonus filter: under "bonusOnly" the tagged ones (a non-plain item.bonus).
function CatchHere.BonusItems(items, value)
    if value ~= "bonusOnly" then
        return items
    end
    local kept = {}
    for _, item in ipairs(items) do
        if item.bonus and not item.bonus.plain then
            table.insert(kept, item)
        end
    end
    return kept
end

function CatchHere.SetBonus(value)
    bonus = value
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

local function ShowRowTooltip(self)
    local unknown = self.unknown
    if unknown then
        -- An item the client does not know yet (specs/004-public-channel-sync, FR-017a): no game tooltip.
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["Unknown item"])
        GameTooltip:AddLine(L["The game has not shown this item yet."], 1, 1, 1, true)
        GameTooltip:AddLine(unknown.inSeed and L["In the bundled data"]
            or (L["Reported by %d players on this map"]):format(unknown.reporters), 1, 1, 1, true)
        GameTooltip:AddLine((L["Item ID: %d"]):format(unknown.itemID), 0.6, 0.6, 0.6)
        ns.AddBonusLines(GameTooltip, self.bonus)
        GameTooltip:Show()
    elseif self.itemID then
        ns.ShowItemTooltip(self, self.itemID, true, self.bonus)
    end
end

-- A row's frames, made the first time the list draws on it.
local function BuildRow(row)
    row:SetSize(520, LINE_HEIGHT) -- within the scroll list's 522
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
    row.tag = ns.CreateTagIcon(row, COLUMNS[1].x + COLUMNS[1].width) -- the camp bonus tag (spec 020)
    -- A header row (a kind's name over its items) shows only this text.
    row.header = CreateText(row, "GameFontNormal")
    row.header:SetPoint("LEFT", 0, 0)
    row.header:SetWidth(520)
    row:EnableMouse(true)
    row:SetScript("OnEnter", ShowRowTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- A known item opens the catalog on it (FR-024); an "Unknown item" has no name to show there.
    row:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and self.itemID and not self.unknown then
            ns.StatsFrame.OpenCatalog(self.itemID)
        end
    end)
end

-- Shows the row's item columns, or (as a header) only the kind's text. The tag's icon is the item's.
local function ShowColumns(row, visible)
    row.icon:SetShown(visible)
    for _, column in ipairs(COLUMNS) do
        row[column.key]:SetShown(visible)
    end
    row.header:SetShown(not visible)
    row.tag:Hide()
end

local loadAsked = {} -- item IDs asked from the game this session

local function FillRow(row, item, view)
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
    -- A tagged item (spec 020): the icon, and the chance among the catches made with its bonus, without the words
    -- (they are in the tooltip); a plain tag keeps the view's chance.
    row.bonus = item.bonus
    ns.ShowTag(row.tag, row.name, COLUMNS[1].width, item.bonus)
    local chance, littleData = ns.Catalog.ItemNumbers(item, view)
    row.chance:SetText(ns.Catalog.ChanceText(chance, littleData))
    row.pieces:SetText(ns.FormatCount(item.pieces))
end

-- The list's element on a row: { header = kind } or an item of the shown view.
local function InitRow(row, element)
    if not row.name then
        BuildRow(row)
    end
    if element.header then
        -- A header row has no item: its scripts do nothing on it.
        row.itemID, row.unknown, row.bonus = nil, nil, nil
        ShowColumns(row, false)
        row.header:SetText(ns.Catalog.KindText(element.header))
        return
    end
    FillRow(row, element, shownView)
end

-- The page, a child of the statistics window covering the same area (hidden until its tab is chosen).
function CatchHere.Create(parent)
    page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page.place = CreateText(page, "GameFontNormal")
    page.place:SetPoint("TOPLEFT", LABEL_X, TOP)
    page.place:SetWidth(540)
    page.place:SetWordWrap(false) -- one line: the lines below sit at fixed places
    page.scope = CreateText(page, "GameFontDisableSmall")
    page.scope:SetPoint("TOPLEFT", LABEL_X, SCOPE_TOP)
    page.scope:SetWidth(540)
    page.hint = CreateText(page, "GameFontDisableSmall")
    page.hint:SetPoint("TOPLEFT", LABEL_X, HINT_TOP)
    page.hint:SetWidth(540)
    page.hint:SetMaxLines(3)
    -- The quiet state of the exchange with other players (Share.lua): one line of small text.
    page.status = CreateText(page, "GameFontDisableSmall")
    page.status:SetPoint("TOPLEFT", LABEL_X, STATUS_TOP)
    page.status:SetWidth(540)
    page.counts = CreateText(page, "GameFontHighlight")
    page.counts:SetPoint("TOPLEFT", LABEL_X, COUNTS_TOP)
    page.counts:SetWidth(540)

    -- Row A: Skill, Source.
    page.skillButton = ns.CreateButton(page, "", 150, function(self)
        CatchHere.OpenSkillMenu(self, function() return shown and shown.range end, CatchHere.SetRange)
    end)
    page.skillButton:SetPoint("TOPLEFT", LABEL_X - 4, ROW_A_TOP)
    page.sourceButton = ns.CreateButton(page, "", 150, function(self)
        CatchHere.OpenSourceMenu(self, function() return source end, CatchHere.SetSource)
    end)
    page.sourceButton:SetPoint("LEFT", page.skillButton, "RIGHT", BUTTON_GAP, 0)
    -- Row B: Water or Camp bonus (one slot), then Kinds (placed by UpdateFilterSlot).
    page.waterButton = CatchHere.CreateWaterButton(page, LABEL_X - 4, ROW_B_TOP, function() return water end,
        CatchHere.SetWater)
    page.bonusButton = CatchHere.CreateBonusButton(page, LABEL_X - 4, ROW_B_TOP, function() return bonus end,
        CatchHere.SetBonus)
    page.kindButton = ns.CreateButton(page, "", KIND_WIDTH, CatchHere.OpenKindMenu)
    page.kindButton:SetPoint("TOPLEFT", LABEL_X - 4, ROW_B_TOP)

    local headers = { name = L["Item"], chance = L["Chance"], pieces = L["Per catch"], price = L["Price"] }
    for _, column in ipairs(COLUMNS) do
        local header = CreateText(page, "GameFontNormalSmall", column.justify)
        header:SetPoint("TOPLEFT", LABEL_X + column.x, ROWS_TOP)
        header:SetWidth(column.width)
        header:SetText(headers[column.key])
    end

    page.list = ns.CreateList(page, ROWS_TOP - LINE_HEIGHT, InitRow)
    page.message = CreateText(page, "GameFontDisable")
    page.message:SetPoint("TOPLEFT", LABEL_X, ROWS_TOP - LINE_HEIGHT - 4)
    page.message:SetWidth(540)
    page:Hide()
    return page
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
    local queryWater
    queryWater, bonus = CatchHere.UpdateFilterSlot(page.waterButton, page.bonusButton, water, bonus, page.kindButton)
    local filter = { range = EffectiveRange(ownRange), source = source, water = queryWater,
        bonus = CatchHere.QueryBonus(bonus) }
    local previous = shown
    shown = { version = ns.CatchDB.GetVersion(), mapID = mapID, ownRange = ownRange, cell = cell,
        range = filter.range, itemIDs = {}, unknownIDs = {},
        filterKey = ns.CatchDB.FilterKey(filter) .. "|" .. bonus }
    -- The same place under the same filters (new data, an item the game learned, a kind toggled): the list keeps its
    -- scroll position, as the catalog's does (FR-028); a new place or filter starts at the top.
    local retain = previous ~= nil and previous.mapID == mapID and previous.cell == cell
        and previous.filterKey == shown.filterKey
    page.skillButton:SetText((L["Skill: %s"]):format(RangeLabel(filter.range)))
    page.sourceButton:SetText((L["Source: %s"]):format(SourceLabel(source)))
    page.kindButton:SetText(CatchHere.KindLabel())
    page.message:SetText("")
    local elements = {}
    local hints = {}
    if not mapID then
        page.place:SetText(ns.Skill.Get() and L["The game does not show this place on the map."]
            or L["Fishing is not learned."])
        page.scope:SetText("")
        page.counts:SetText("")
        page.hint:SetText("")
        page.list.Show(elements)
        return
    end
    page.place:SetText(ns.Stats.PlaceName(mapID))
    local view = ns.CatchDB.Query(mapID, cell, filter)
    shownView = view
    -- The view's items, drawn or not: an item the game learns redraws the page, and one the client does not know
    -- yet, hidden as Other, may load as another kind (spec 014).
    for _, item in ipairs(view.items) do
        shown.itemIDs[item.itemID] = true
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
        -- The items under their kind headers (spec 014), only the tagged ones under "Bonus catches only".
        local items = CatchHere.BonusItems(view.items, bonus)
        local hidden
        elements, hidden = ns.Catalog.Group(items)
        local itemsShown = #items - hidden
        if #view.items > 0 and #items == 0 then
            page.message:SetText(L["No bonus catch has been recorded here yet."]) -- spec 020
        elseif #items > 0 and itemsShown == 0 then
            page.message:SetText(L["The kind filter hides every item."]) -- not "no data" (FR-011)
        end
        if itemsShown > 0 then
            table.insert(hints, L["Click an item to see where else it is caught."])
        end
        if view.littleData and filter.range ~= "all" then
            table.insert(hints, L["Try \"All skill levels\": little data for your skill."])
        end
    end
    page.list.Show(elements, retain)
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

-- An item of the shown view the game now knows: its row gets its name, and one unknown at the last draw, hidden as
-- Other, may move to a shown kind (spec 014).
local function ItemArrived(_, itemID, success)
    if success and page and page:IsShown() and shown and shown.itemIDs and shown.itemIDs[itemID] then
        dirty = true
    end
end
ns.RegisterEvent("GET_ITEM_INFO_RECEIVED", ItemArrived)
ns.RegisterEvent("ITEM_DATA_LOAD_RESULT", ItemArrived) -- an unknown item the game now knows: its name and icon
