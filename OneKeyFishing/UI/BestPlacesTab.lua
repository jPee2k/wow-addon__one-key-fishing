-- BestPlacesTab: the "Best places" page of the statistics window (specs/024-best-places): the top zones by gold per
-- hour (Catalog/BestPlaces.lua), each opening into its subzones and spots with map pins (UI/PlaceList.lua). Filters
-- in two rows as on the catalog: Skill, Source, Safe for me; then Water or Camp bonus, Kinds, Continent. Skill,
-- Source, Water and Camp bonus live in memory (every login starts at the own range and "all"); Safe for me and the
-- continent are the character's, the kinds the account's.
local _, ns = ...
local L = ns.L

local BestPlacesTab = {}
ns.BestPlacesTab = BestPlacesTab

local LABEL_X = 20
local TOP = -32 -- below the window title
local FILTER_TOP = TOP - 26 -- row A: Skill, Source, Safe for me
local SECOND_TOP = TOP - 52 -- row B: Water or Camp bonus, Kinds, Continent
local LIST_TOP = TOP - 104 -- the zones, below the column headers
local RED = { 1, 0.3, 0.3 }

local COLUMNS = {
    { key = "name", x = 16, width = 210, justify = "LEFT", label = function() return L["Place"] end },
    { key = "skill", x = 230, width = 60, justify = "LEFT", label = function() return L["Skill"] end },
    { key = "level", x = 290, width = 50, justify = "LEFT", label = function() return L["Level"] end },
    { key = "gold", x = 340, width = 110, justify = "RIGHT", label = function() return L["Gold per hour"] end },
    { key = "catches", x = 455, width = 45, justify = "RIGHT", label = function() return L["Catches"] end },
}

local page
local filter = { source = "all", water = "all", bonus = "all" } -- range: the own range unless one was picked
local pickedRange -- the Skill the player chose this session, or nil for the own range
local drawn -- { version, state }

local function Filter()
    local rank = ns.Skill.Get()
    filter.range = pickedRange or ns.CatchDB.SkillFilter(rank and ns.CatchDB.RangeOf(rank) or nil)
    return filter
end

-- The gold of a place: its gold per hour, "*" when much of its catch has no price (FR-015), or "Little data".
local function GoldText(place)
    if place.littleData or not place.goldPerHour then
        return L["Little data"]
    end
    local text = ns.BestPlaces.FormatGold(place.goldPerHour)
    return place.unpriced >= ns.BestPlaces.UNPRICED_MARK and text .. "*" or text
end

local function Cells(element)
    local place = element.place
    local cells = { skill = place.ranges and ns.RangeLabel(place.ranges.min, place.ranges.max) or "",
        gold = GoldText(place), catches = tostring(place.catches) }
    if element.kind == "zone" and place.levels then
        cells.level = ("%d-%d"):format(place.levels.min, place.levels.max)
        cells.levelColor = ns.BestPlaces.Unsafe(place) and RED or nil
    end
    return cells
end

-- A row's tooltip: the place, the items that bring the most gold (FR-009), the players, the unpriced share.
local function ShowTooltip(row)
    local element = row.element
    local place = element.place
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(element.kind == "zone" and place.name or (element.zone .. " - " .. place.name))
    for _, item in ipairs(place.top or {}) do
        GameTooltip:AddLine(L["%s: %s chance, %s each, %d%% of the gold"]:format(ns.ItemDisplay(item.itemID),
            ns.Catalog.ChanceText(item.chance), ns.FormatMoney(item.price), math.floor(item.share * 100 + 0.5)),
            1, 1, 1)
    end
    GameTooltip:AddLine(ns.Catalog.CatchesText(place.catches, place.players), 1, 1, 1)
    if place.unpriced >= ns.BestPlaces.UNPRICED_MARK then
        GameTooltip:AddLine(L["%d%% of the catch here has no price: the gold may be higher."]:format(
            math.floor(place.unpriced * 100 + 0.5)), 1, 0.82, 0, true)
    end
    GameTooltip:Show()
end

local function OnOff(on)
    return on and L["On"] or L["Off"]
end

local function OpenSafeMenu(owner)
    ns.OpenRadioMenu(owner, { { value = true, text = L["On"] }, { value = false, text = L["Off"] } },
        function(value) return ns.BestPlaces.GetSafe() == value end, ns.BestPlaces.SetSafe)
end

local function OpenContinentMenu(owner)
    local choices = {}
    for _, value in ipairs(ns.BestPlaces.CONTINENTS) do
        table.insert(choices, { value = value, text = ns.BestPlaces.ContinentText(value) })
    end
    ns.OpenRadioMenu(owner, choices, function(value) return ns.BestPlaces.GetContinent() == value end,
        ns.BestPlaces.SetContinent)
end

function BestPlacesTab.SetRange(range)
    pickedRange = range
    BestPlacesTab.Refresh()
end

function BestPlacesTab.SetSource(value)
    filter.source = value
    BestPlacesTab.Refresh()
end

function BestPlacesTab.SetWater(value)
    filter.water = value
    BestPlacesTab.Refresh()
end

function BestPlacesTab.SetBonus(value)
    filter.bonus = value
    BestPlacesTab.Refresh()
end

-- The page, a child of the statistics window covering the same area (hidden until its tab is chosen).
function BestPlacesTab.Create(parent)
    page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page.skillButton = ns.CreateButton(page, "", 150, function(self)
        ns.CatchHere.OpenSkillMenu(self, function() return Filter().range end, BestPlacesTab.SetRange)
    end)
    page.skillButton:SetPoint("TOPLEFT", LABEL_X - 4, FILTER_TOP)
    page.skillButton:SetScript("OnEnter", function(self) ns.ShowSkillTooltip(self, Filter().range) end)
    page.skillButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    page.sourceButton = ns.CreateButton(page, "", 150, function(self)
        ns.CatchHere.OpenSourceMenu(self, function() return filter.source end, BestPlacesTab.SetSource)
    end)
    page.sourceButton:SetPoint("LEFT", page.skillButton, "RIGHT", 8, 0)
    page.safeButton = ns.CreateButton(page, "", 150, OpenSafeMenu)
    page.safeButton:SetPoint("LEFT", page.sourceButton, "RIGHT", 8, 0)
    page.waterButton = ns.CatchHere.CreateWaterButton(page, LABEL_X - 4, SECOND_TOP,
        function() return filter.water end, BestPlacesTab.SetWater)
    page.bonusButton = ns.CatchHere.CreateBonusButton(page, LABEL_X - 4, SECOND_TOP,
        function() return filter.bonus end, BestPlacesTab.SetBonus)
    page.kindButton = ns.CreateButton(page, "", ns.CatchHere.KIND_WIDTH, ns.CatchHere.OpenKindMenu)
    page.continentButton = ns.CreateButton(page, "", 150, OpenContinentMenu)
    page.continentButton:SetPoint("LEFT", page.kindButton, "RIGHT", 8, 0)
    ns.PlaceList.Headers(page, LIST_TOP, COLUMNS)
    page.places = ns.PlaceList.Create(page, LIST_TOP, COLUMNS,
        { cells = Cells, tooltip = ShowTooltip, changed = function() BestPlacesTab.Refresh(true) end })
    page.status = ns.CreateText(page, "GameFontDisable")
    page.status:SetPoint("TOPLEFT", LABEL_X, LIST_TOP)
    page.status:SetWidth(540)
    page:Hide()
    return page
end

-- Redraws the page; retain (the tick, new data) keeps the scroll position.
function BestPlacesTab.Refresh(retain)
    if not (page and page:IsShown()) then
        return
    end
    local current = Filter()
    page.skillButton:SetText(ns.SkillFilterLabel(current.range))
    page.sourceButton:SetText((L["Source: %s"]):format(ns.CatchHere.SourceLabel(current.source)))
    page.safeButton:SetText((L["Safe for me: %s"]):format(OnOff(ns.BestPlaces.GetSafe())))
    current.water, current.bonus = ns.CatchHere.UpdateFilterSlot(page.waterButton, page.bonusButton, current.water,
        current.bonus, page.kindButton)
    page.kindButton:SetText(ns.CatchHere.KindLabel())
    local continent = ns.BestPlaces.ContinentText(ns.BestPlaces.GetContinent())
    page.continentButton:SetText((L["Continent: %s"]):format(continent))
    local zones, state = ns.BestPlaces.Zones(current)
    for _, zone in ipairs(zones) do
        zone.name = ns.Catalog.ZoneName(zone.mapID)
    end
    page.places.Show(zones, function(zone) return ns.BestPlaces.Spots(zone.mapID, current) end, retain)
    if state == "building" then
        page.status:SetText(L["Counting the catch..."])
    else
        page.status:SetText(#zones == 0 and L["Nothing matches the filters."] or "")
    end
    drawn = { version = ns.BestPlaces.GetVersion(), state = state }
end

-- Every second while the page is shown: a read brings the ranking up to date, and the page redraws when it moved.
function BestPlacesTab.Tick()
    if not (page and page:IsShown()) then
        return
    end
    local _, state = ns.BestPlaces.Zones(Filter())
    if not drawn or drawn.version ~= ns.BestPlaces.GetVersion() or drawn.state ~= state then
        BestPlacesTab.Refresh(true)
    end
end

-- A kind, Safe for me or the continent changed: redraw at once, keeping the scroll.
ns.On("SETTINGS_CHANGED", function(key)
    if key == "hiddenKinds" or key == "bestPlaces" then
        BestPlacesTab.Refresh(true)
    end
end)
