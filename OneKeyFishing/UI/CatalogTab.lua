-- CatalogTab: the "Catch catalog" page of the statistics window (specs/005-catch-catalog, contracts/ui.md). The list
-- of every item of the database with a search over the client's own names and the filters; choosing an item shows
-- its zones, and each zone expands into its spots. Everything shown comes from Catalog.lua. The search, the
-- filters, the chosen item and the expanded zones live in memory only, so every login starts at the defaults. The
-- list is grouped under kind headers, and the kind menu (shared with "What can be caught here") hides kinds
-- (specs/014-catch-filters); that choice is saved, and an item opened by its ID shows whatever its kind. The Sort
-- button orders the list by name, price or chance (specs/017-catalog-sort); that choice is saved too.
local _, ns = ...
local L = ns.L

local CatalogTab = {}
ns.CatalogTab = CatalogTab

local LABEL_X = 20
local LINE_HEIGHT = 18
local ROW_WIDTH = 520
-- An item row: the icon, the name, and the right column (the zones, a price or a chance, spec 017); a price of three
-- coins (123g 45s 67c with their icons) takes about 120 pixels.
local ITEM_NAME_WIDTH = 350
local ITEM_RIGHT_WIDTH = 140
local TOP = -32 -- below the window title
-- Over the list (spec 017, spec 020 decisions 28-30): the search box; the status line (two lines); row A: Skill,
-- Source; row B: Water or Camp bonus, Kinds, Sort (the same two rows as "What can be caught here").
local STATUS_TOP = TOP - 24 -- the status line under the search box
local FILTER_TOP = TOP - 56 -- row A: Skill, Source
local SORT_TOP = TOP - 82 -- row B: Water or Camp bonus, Kinds, Sort
local LIST_TOP = TOP - 114 -- the item list, below row B
local ITEM_LIST_TOP = TOP - 46 -- the zone rows, below the item header and the column headers
local INDENT = 16 -- spot rows under their zone
local PIN_ATLAS = "Waypoint-MapPin-Untracked"
-- The zone and spot rows: x and width inside a row, and the text alignment.
local COLUMNS = {
    { key = "name", x = 16, width = 230, justify = "LEFT" },
    { key = "skill", x = 250, width = 70, justify = "LEFT" },
    -- 110 wide: French "Little data" was cut at 70 (seen 2026-11-20), as in "What can be caught here"
    { key = "chance", x = 320, width = 110, justify = "RIGHT" },
    { key = "catches", x = 435, width = 60, justify = "RIGHT" },
}

local CreateText = ns.CreateText -- UI/Widgets.lua

local page
local search = ""
local filter = ns.Catalog.DefaultFilter()
local chosen -- the item ID of the item page, or nil for the list
local pending -- what Show was asked for while the index was still building; Tick passes it on once it is ready
local expanded = {} -- map ID -> true: zones of the chosen item that show their spots
local drawn -- what the page shows now: { version, state }
local listed = {} -- item ID -> true: the items of the list as last drawn by price (read only by price)
local dirty = false

-- The span of skill an item was caught with ({ min, max } ranges): "0-74", "75-224", "300+", "75+".
local function SpanLabel(ranges)
    return ranges and ns.RangeLabel(ranges.min, ranges.max) or ""
end

local function MarkDirty()
    dirty = true
end

---------------------------------------------------------------------------
-- The item list
---------------------------------------------------------------------------
local GREY = 0.5 -- the right column's "No price"

-- text, grey: the right column of an item row shows what the list is ordered by (spec 017, research R7): the price per
-- piece (the statistics' value; "No price" in grey when there is none), the best place's chance, or by name the
-- number of zones as before.
local function RightColumn(element)
    local sort = ns.Catalog.GetSort()
    if sort == "price" then
        local price = ns.Prices.Get(element.itemID)
        if price > 0 then
            return ns.FormatMoney(price), false
        end
        return L["No price"], true
    elseif sort == "chance" then
        -- A known camp bonus item without data under its bonus (spec 020) has no chance: "Little data".
        return ns.Catalog.ChanceText(element.chance, element.littleData), false
    end
    return (L["Zones: %d"]):format(element.zones), false
end

-- The list's elements: { header = kind } before each kind's items, or an item row of Catalog.Items.
local function InitItemRow(row, element)
    if not row.name then
        row:SetSize(ROW_WIDTH, LINE_HEIGHT)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(16, 16)
        row.icon:SetPoint("LEFT")
        row.name = CreateText(row, "GameFontHighlight")
        row.name:SetPoint("LEFT", 22, 0)
        row.name:SetWidth(ITEM_NAME_WIDTH)
        row.name:SetWordWrap(false)
        row.zones = CreateText(row, "GameFontHighlight", "RIGHT")
        row.zones:SetPoint("RIGHT", -4, 0)
        row.zones:SetWidth(ITEM_RIGHT_WIDTH)
        row.tag = ns.CreateTagIcon(row, 22 + ITEM_NAME_WIDTH)
        -- A header row (kindHeader) has no item: hover and click do nothing on it.
        row:SetScript("OnEnter", function(self)
            if not self.kindHeader then
                -- with its own "Caught in" lines (UI/ItemHooks.lua) and its camp bonus lines (spec 020)
                ns.ShowItemTooltip(self, self.itemID, true, self.bonus)
            end
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:SetScript("OnClick", function(self)
            if not self.kindHeader then
                CatalogTab.Show(self.itemID)
            end
        end)
    end
    row.name:ClearAllPoints()
    row.kindHeader = element.header -- the kind of a header row, nil for an item
    if element.header then
        row.itemID, row.bonus = nil, nil
        row.icon:Hide()
        row.tag:Hide()
        row.name:SetPoint("LEFT", 2, 0)
        row.name:SetWidth(ITEM_NAME_WIDTH)
        row.name:SetTextColor(1, 0.82, 0) -- the game's header gold
        row.name:SetText(ns.Catalog.KindText(element.header))
        row.zones:SetText("")
        return
    end
    row.itemID, row.bonus = element.itemID, element.bonus
    local text, icon = ns.ItemDisplay(element.itemID)
    row.icon:SetTexture(icon)
    row.icon:Show()
    ns.ShowTag(row.tag, row.name, ITEM_NAME_WIDTH, element.bonus)
    row.name:SetPoint("LEFT", 22, 0)
    row.name:SetTextColor(1, 1, 1)
    row.name:SetText(text)
    local right, grey = RightColumn(element)
    row.zones:SetText(right)
    -- Set on every draw: a row frame is reused for other items.
    if grey then
        row.zones:SetTextColor(GREY, GREY, GREY)
    else
        row.zones:SetTextColor(1, 1, 1)
    end
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
        GameTooltip:AddLine(ns.Catalog.AreaName(spot) or element.zone)
        if spot.point then
            GameTooltip:AddLine(ns.Catalog.Coordinates(spot.point), 1, 1, 1)
        end
    end
    GameTooltip:AddLine(ns.Catalog.CatchesText(element.place.catches, element.place.players), 1, 1, 1)
    ns.AddBonusLines(GameTooltip, element.place.bonus) -- a tagged place's own bonus (spec 020)
    GameTooltip:Show()
end

-- The pin button of a spot row: the game's pin icon, or a text button when the client lacks the atlas.
local function CreatePinButton(row)
    local button
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(PIN_ATLAS) then
        button = CreateFrame("Button", nil, row)
        button:SetSize(16, 16)
        button:SetNormalAtlas(PIN_ATLAS)
        button:SetHighlightAtlas(PIN_ATLAS, "ADD")
    else
        button = ns.CreateButton(row, L["Pin"], 30, nil)
        button:SetHeight(16)
    end
    button:SetPoint("RIGHT", -2, 0)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["Set a map pin here"])
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnClick", function()
        local element = row.element
        ns.MapPin.Set(element.place.pin, element.zone .. " - " .. element.place.name) -- Core/MapPin.lua
    end)
    return button
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
        row.pinButton = CreatePinButton(row)
        row.tag = ns.CreateTagIcon(row, COLUMNS[1].x + COLUMNS[1].width)
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
    ns.ShowTag(row.tag, row.name, COLUMNS[1].width - (zone and 0 or INDENT), place.bonus)
    row.name:SetText(place.name)
    row.skill:SetText(SpanLabel(place.ranges))
    row.chance:SetText(ns.Catalog.ChanceText(place.chance, place.littleData))
    row.catches:SetText(tostring(place.catches))
    row.pinButton:SetShown(not zone and place.pin ~= nil)
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------
function CatalogTab.SetRange(range)
    filter.range = range
    CatalogTab.Refresh()
end

function CatalogTab.SetSource(value)
    filter.source = value
    CatalogTab.Refresh()
end

function CatalogTab.SetWater(value)
    filter.water = value
    CatalogTab.Refresh()
end

-- The catalog's own Camp bonus filter (spec 020), in memory like the Water filter.
function CatalogTab.SetBonus(value)
    filter.bonus = value
    CatalogTab.Refresh()
end

-- The Sort menu: one radio entry per order; a click saves it through Catalog.SetSort, whose
-- SETTINGS_CHANGED("catalogSort") redraws the list (the handler at the end of this file).
local function OpenSortMenu(owner)
    local choices = {}
    for _, sort in ipairs(ns.Catalog.SORTS) do
        table.insert(choices, { value = sort, text = ns.Catalog.SortText(sort) })
    end
    ns.OpenRadioMenu(owner, choices, function(value) return ns.Catalog.GetSort() == value end, ns.Catalog.SetSort)
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
    box:HookScript("OnTextChanged", function(self, userInput)
        if userInput then
            pending = nil -- the player's typing wins over an older request
        end
        search = self:GetText() or ""
        CatalogTab.Refresh()
    end)
    if box.clearButton then
        -- its SetText("") is no userInput, but the click is the player's
        box.clearButton:HookScript("OnClick", function() pending = nil end)
    end
    return box
end

-- The page, a child of the statistics window covering the same area (hidden until its tab is chosen).
function CatalogTab.Create(parent)
    page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page:SetScript("OnHide", function() pending = nil end) -- a closed window or another tab ends the request

    page.listView = CreateFrame("Frame", nil, page)
    page.listView:SetAllPoints()
    page.search = CreateSearchBox(page.listView)
    page.search:SetPoint("TOPLEFT", LABEL_X + 6, TOP)
    page.skillButton = ns.CreateButton(page.listView, "", 150, function(self)
        ns.CatchHere.OpenSkillMenu(self, function() return filter.range end, CatalogTab.SetRange)
    end)
    page.skillButton:SetPoint("TOPLEFT", LABEL_X - 4, FILTER_TOP)
    page.skillButton:SetScript("OnEnter", function(self) ns.ShowSkillTooltip(self, filter.range) end) -- spec 021
    page.skillButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    page.sourceButton = ns.CreateButton(page.listView, "", 150, function(self)
        ns.CatchHere.OpenSourceMenu(self, function() return filter.source end, CatalogTab.SetSource)
    end)
    page.sourceButton:SetPoint("LEFT", page.skillButton, "RIGHT", 8, 0)
    -- Row B: one slot for Water (with pool data) or Camp bonus (with bonus data, spec 020), then the kind menu (the
    -- catch tab's: one choice for both, spec 014) and the list's order. Each button follows the previous one, so a
    -- longer translation pushes the next along.
    page.waterButton = ns.CatchHere.CreateWaterButton(page.listView, LABEL_X - 4, SORT_TOP,
        function() return filter.water end, CatalogTab.SetWater)
    page.bonusButton = ns.CatchHere.CreateBonusButton(page.listView, LABEL_X - 4, SORT_TOP,
        function() return filter.bonus end, CatalogTab.SetBonus)
    page.kindButton = ns.CreateButton(page.listView, "", ns.CatchHere.KIND_WIDTH, ns.CatchHere.OpenKindMenu)
    page.sortButton = ns.CreateButton(page.listView, "", 150, OpenSortMenu)
    page.sortButton:SetPoint("LEFT", page.kindButton, "RIGHT", 8, 0)
    page.list = ns.CreateList(page.listView, LIST_TOP, InitItemRow)

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
    page.places = ns.CreateList(page.itemView, ITEM_LIST_TOP, InitPlaceRow)
    page.itemView:Hide()

    -- One status line: under the search box on the list, where the zones begin on an item's page (Refresh).
    page.status = CreateText(page, "GameFontDisable")
    page.status:SetWidth(540)
    page.status:SetMaxLines(2) -- its room between the search box and row A (STATUS_TOP)
    page:Hide()
    return page
end

-- items: the rows before the kind filter; shown: how many of them the kind filter lets through (spec 014).
local function StatusText(items, state, shown)
    if state == "building" then
        return L["Counting the catch..."]
    elseif #items > 0 then
        if shown > 0 then
            return ""
        end
        return search ~= "" and L["The kind filter hides the matches."] or L["The kind filter hides every item."]
    elseif search ~= "" then
        return L["No item matches the search."]
    elseif filter.bonus == "bonusOnly" then
        return L["No bonus catch has been recorded yet."] -- spec 020
    elseif filter.source == "mine" then
        return L["You have not caught anything yet."]
    end
    -- One paragraph: on two lines it keeps clear of row A in every language (the second sentence alone wraps).
    return L["Nothing has been caught yet."] .. " "
        .. L["The catalog fills with your catches, the bundled data and, with sharing on, other players' catches."]
end

-- The items under their kind headers (spec 014); the status reads the rows before the kind filter.
local function ShowList(retain)
    local items, state = ns.Catalog.Items(filter, search)
    listed = {}
    if ns.Catalog.GetSort() == "price" then
        for _, row in ipairs(items) do
            listed[row.itemID] = true
        end
    end
    local elements, hidden = ns.Catalog.Group(items)
    page.list.Show(elements, retain)
    page.status:SetText(StatusText(items, state, #items - hidden))
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
    page.skillButton:SetText(ns.SkillFilterLabel(filter.range))
    page.sourceButton:SetText((L["Source: %s"]):format(ns.CatchHere.SourceLabel(filter.source)))
    -- One slot for the Water and the Camp bonus buttons (spec 020); a filter without its button is "all".
    filter.water, filter.bonus = ns.CatchHere.UpdateFilterSlot(page.waterButton, page.bonusButton, filter.water,
        filter.bonus, page.kindButton)
    page.kindButton:SetText(ns.CatchHere.KindLabel())
    page.sortButton:SetText((L["Sort: %s"]):format(ns.Catalog.SortText(ns.Catalog.GetSort())))
    page.listView:SetShown(chosen == nil)
    page.itemView:SetShown(chosen ~= nil)
    page.status:ClearAllPoints()
    page.status:SetPoint("TOPLEFT", LABEL_X, chosen and ITEM_LIST_TOP or STATUS_TOP)
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
    local state = ns.Catalog.State(filter)
    if pending and state == "ready" then
        CatalogTab.Show(pending)
        return
    end
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
-- search and chooses the item when exactly one matches; nil shows the list (FR-024, FR-025). Asked while the index is
-- still building, the list waits and Tick makes the choice once the index is ready.
function CatalogTab.Show(arg)
    pending = nil
    if arg ~= nil and ns.Catalog.State(filter) ~= "ready" then
        chosen, pending = nil, arg
        if type(arg) == "string" then
            CatalogTab.SetSearch(arg)
        end
        CatalogTab.Refresh()
        return
    end
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
        -- A name is a search of the list: the one match the kind filter shows is chosen (spec 014 R9); an item asked
        -- for by its ID (above) opens whatever its kind (FR-012).
        local shown = {}
        for _, itemID in ipairs(ns.Catalog.Find(arg)) do
            if ns.Catalog.IsKindShown(ns.Catalog.ItemKind(itemID)) then
                table.insert(shown, itemID)
            end
        end
        if #shown == 1 then
            chosen, expanded = shown[1], {}
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

ns.On("PRICES_CHANGED", MarkDirty) -- the item tooltips' prices, and by price the order and the right column
-- An item's full info, its vendor price with it, may arrive after the draw (as on the other tabs): by price the order
-- and the right column of the list follow at the next tick (spec 017). Only for an item the list shows: the game
-- loads other items all the time (bags, the auction house, chat links).
ns.RegisterEvent("GET_ITEM_INFO_RECEIVED", function(_, itemID, success)
    if success and listed[itemID] and chosen == nil and page and page:IsShown() and ns.Catalog.GetSort() == "price" then
        MarkDirty()
    end
end)
-- A kind toggled in the menu redraws at once, keeping the scroll (FR-007); a hidden page redraws when shown (dirty).
-- A new order redraws at once from the top of the list (spec 017).
ns.On("SETTINGS_CHANGED", function(key)
    MarkDirty()
    if key == "hiddenKinds" then
        CatalogTab.Refresh(true)
    elseif key == "catalogSort" then
        CatalogTab.Refresh()
    end
end)
