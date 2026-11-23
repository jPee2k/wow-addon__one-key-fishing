-- PlaceList: the three-level place list of the catalog's item page and of the best places (specs/024-best-places
-- FR-003, FR-004, FR-010): a zone opens into its subzone groups and spots (Catalog.GroupSpots), a group into its
-- spots; groups and spots carry the game's map pin. The caller gives the columns, what each cell reads and the
-- tooltip; the data comes from Catalog or BestPlaces, nothing is computed here. Expanded zones and groups live in
-- memory only.
local _, ns = ...
local L = ns.L

local PlaceList = {}
ns.PlaceList = PlaceList

local LABEL_X = 20
local LINE_HEIGHT = 18
local ROW_WIDTH = 520
local INDENT = 16 -- each level below the zone
local PIN_ATLAS = "Waypoint-MapPin-Untracked"

-- The pin button of a group or spot row: the game's pin icon, or a text button when the client lacks the atlas.
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
        local place = element.place
        ns.MapPin.Set(place.pin, element.zone .. " - " .. (place.pinName or place.name)) -- Core/MapPin.lua
    end)
    return button
end

-- The column headers over the list.
function PlaceList.Headers(parent, top, columns)
    for _, column in ipairs(columns) do
        local header = ns.CreateText(parent, "GameFontNormalSmall", column.justify)
        header:SetPoint("TOPLEFT", LABEL_X + column.x, top + LINE_HEIGHT + 4)
        header:SetWidth(column.width)
        header:SetText(column.label())
    end
end

local function GroupKey(mapID, area)
    return mapID .. ":" .. tostring(area)
end

-- columns: { key, x, width, justify, label() }, the first one the place's name; opts: cells(element) -> { key ->
-- text, key .. "Color" -> { r, g, b } } for the other columns, tooltip(row) (optional), changed() after a toggle.
function PlaceList.Create(parent, top, columns, opts)
    local expanded = {} -- map ID or "mapID:area" -> true
    local self

    local function InitRow(row, element)
        if not row.name then
            row:SetSize(ROW_WIDTH, LINE_HEIGHT)
            row.toggle = ns.CreateText(row, "GameFontNormal")
            row.toggle:SetPoint("LEFT", 2, 0)
            for _, column in ipairs(columns) do
                local text = ns.CreateText(row, "GameFontHighlight", column.justify)
                text:SetPoint("LEFT", column.x, 0)
                text:SetWidth(column.width)
                text:SetWordWrap(false)
                row[column.key] = text
            end
            row.pinButton = CreatePinButton(row)
            row.tag = ns.CreateTagIcon(row, columns[1].x + columns[1].width)
            row:SetScript("OnEnter", function(this)
                if opts.tooltip then
                    opts.tooltip(this)
                end
            end)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row:SetScript("OnClick", function(this)
                local key = this.element.key
                if key then
                    expanded[key] = not expanded[key] or nil
                    opts.changed()
                end
            end)
        end
        row.element = element
        local place, indent = element.place, (element.level - 1) * INDENT
        row.toggle:ClearAllPoints()
        row.toggle:SetPoint("LEFT", 2 + indent, 0)
        row.toggle:SetText(element.key and (expanded[element.key] and "-" or "+") or "")
        local name = row[columns[1].key]
        name:ClearAllPoints()
        name:SetPoint("LEFT", columns[1].x + indent, 0)
        ns.ShowTag(row.tag, name, columns[1].width - indent, place.bonus)
        -- A spot under its subzone's row names only its coordinates: the subzone is already named above it.
        name:SetText(element.level == 3 and place.point and ns.Catalog.Coordinates(place.point) or place.name)
        local cells = opts.cells(element)
        for index = 2, #columns do
            local key = columns[index].key
            row[key]:SetText(cells[key] or "")
            local color = cells[key .. "Color"]
            row[key]:SetTextColor(color and color[1] or 1, color and color[2] or 1, color and color[3] or 1)
        end
        row.pinButton:SetShown(element.kind ~= "zone" and place.pin ~= nil)
    end

    self = { list = ns.CreateList(parent, top, InitRow) }
    self.box, self.rows = self.list.box, self.list.rows

    -- zones: { mapID, name, ... }; spotsOf(zone) -> the zone's elements from Catalog.GroupSpots. retain keeps the
    -- scroll position.
    function self.Show(zones, spotsOf, retain)
        local elements = {}
        for _, zone in ipairs(zones) do
            table.insert(elements, { kind = "zone", level = 1, place = zone, key = zone.mapID })
            if expanded[zone.mapID] then
                for _, place in ipairs(spotsOf(zone)) do
                    if place.spots then
                        place.name = ns.Catalog.GroupName(place)
                        local key = GroupKey(zone.mapID, place.area)
                        table.insert(elements, { kind = "group", level = 2, place = place, key = key,
                            zone = zone.name, mapID = zone.mapID })
                        if expanded[key] then
                            for _, spot in ipairs(place.spots) do
                                table.insert(elements, { kind = "spot", level = 3, place = spot, zone = zone.name,
                                    mapID = zone.mapID })
                            end
                        end
                    else
                        table.insert(elements, { kind = "spot", level = 2, place = place, zone = zone.name,
                            mapID = zone.mapID })
                    end
                end
            end
        end
        self.list.Show(elements, retain)
    end

    -- Opens or folds a zone (by map ID) or a group ("mapID:area").
    function self.Toggle(key)
        expanded[key] = not expanded[key] or nil
    end

    function self.Fold()
        expanded = {}
    end

    function self.IsOpen(key)
        return expanded[key] == true
    end

    return self
end
