-- Catalog: the catch database across every map (specs/005-catch-catalog). For a filter it keeps an index of the
-- items and the maps they were caught on, made of CatchDB's per-map views and rebuilt only for the maps whose
-- change stamp moved, in frame steps when there are many. It also keeps the items' names in the client's language
-- and their search keys, and answers the catalog tab and the tooltips. No frames, so the tooltips use it without
-- the window; it sends no message (the tab follows GetVersion on the window's tick).
local _, ns = ...
local L = ns.L

local Catalog = {}
ns.Catalog = Catalog

local STEP_MS = 3 -- a build step ends once it took this long by debugprofilestop (SC-003: under 5 ms a frame)
local MAPS_PER_STEP = 8 -- or after this many maps where the client has no frame clock (the tests)
local SYNC_MAPS = 4 -- up to this many changed maps are recomputed by the read that finds them; more go to the steps
local NAME_REQUESTS_PER_STEP = 20 -- item name requests per frame step, light on the server (Principle I)
local DEFAULT_INDEX_DELAY = 10 -- seconds after the session's first loading screen until the default index is built

local DEFAULT_FILTER = { range = "all", source = "all", water = "all" }

-- A fresh copy of the default filter, for the tab to change (UI/CatalogTab.lua).
function Catalog.DefaultFilter()
    return { range = DEFAULT_FILTER.range, source = DEFAULT_FILTER.source, water = DEFAULT_FILTER.water }
end

local version = 0

local function Bump()
    version = version + 1
end

-- Grows whenever an index's items or an item's name change: the tab redraws when it moves.
function Catalog.GetVersion()
    return version
end

local FilterKey = ns.CatchDB.FilterKey -- the same key the views are cached by

local DEFAULT_KEY = FilterKey(DEFAULT_FILTER)

-- The frame clock in ms, or nil without one.
local function Clock()
    local clock = debugprofilestop
    return type(clock) == "function" and clock() or nil
end

---------------------------------------------------------------------------
-- Item names (research R7): known once GetItemInfoInstant and GetItemNameByID both answer; the others are asked
-- for once per session, NAME_REQUESTS_PER_STEP per frame step, and stay out of the lists until the game loads them.
---------------------------------------------------------------------------
local names = {} -- item ID -> { name, key, quality, known }
local asked = {} -- item ID -> true: its name request was queued this session
local queue = {} -- item IDs waiting for their request
local sent = 0 -- name requests sent this session
local sending = false -- a step of SendNames is scheduled

local function SendNames()
    sending = false
    for _ = 1, NAME_REQUESTS_PER_STEP do
        local itemID = table.remove(queue, 1)
        if not itemID then
            break
        end
        -- VERIFY(V35): item names load in batches of NAME_REQUESTS_PER_STEP without errors
        C_Item.RequestLoadItemDataByID(itemID)
        sent = sent + 1
    end
    if queue[1] then
        sending = true
        C_Timer.After(0, SendNames)
    end
end

local function Learn(itemID)
    local name = C_Item.GetItemInfoInstant(itemID) ~= nil and C_Item.GetItemNameByID(itemID) or nil
    local entry
    if type(name) == "string" and name ~= "" then
        entry = { name = name, key = ns.SearchKey(name), quality = C_Item.GetItemQualityByID(itemID), known = true }
    else
        entry = { known = false }
        if not asked[itemID] and C_Item.RequestLoadItemDataByID then
            asked[itemID] = true
            table.insert(queue, itemID)
            if not sending then
                sending = true
                C_Timer.After(0, SendNames)
            end
        end
    end
    names[itemID] = entry
    return entry
end

local function NameOf(itemID)
    return names[itemID] or Learn(itemID)
end

local function ItemArrived(_, itemID, success)
    local entry = names[itemID]
    if success and entry and not entry.known and Learn(itemID).known then
        Bump()
    end
end
ns.RegisterEvent("ITEM_DATA_LOAD_RESULT", ItemArrived)
ns.RegisterEvent("GET_ITEM_INFO_RECEIVED", ItemArrived)

local function IsPoor(entry)
    return Enum.ItemQuality ~= nil and entry.quality == Enum.ItemQuality.Poor
end

---------------------------------------------------------------------------
-- Indexes (research R3, data-model.md "Catalog")
---------------------------------------------------------------------------
local indexes = {} -- filter key -> index: the default filter's and the latest other one
local otherKey -- the key of that other one

-- Places in the order of the catalog and the tooltips (FR-007): those with 50 catches or more first, by chance,
-- highest first; then the little-data ones by the item's catches; ties by map ID or cell.
local function PlaceBefore(a, b)
    if a.littleData ~= b.littleData then
        return not a.littleData
    end
    if not a.littleData and a.chance ~= b.chance then
        return a.chance > b.chance
    end
    if a.littleData and a.itemCatches ~= b.itemCatches then
        return a.itemCatches > b.itemCatches
    end
    return a.order < b.order
end

local function IndexFor(filter)
    local key = FilterKey(filter)
    local index = indexes[key]
    if not index then
        if key ~= DEFAULT_KEY then
            if otherKey then
                indexes[otherKey] = nil
            end
            otherKey = key
        end
        index = { key = key, filter = { range = filter.range, source = filter.source, water = filter.water or "all" },
            maps = {}, items = {}, state = "empty", stale = false, building = false, steps = 0, mostMapsInStep = 0 }
        indexes[key] = index
    end
    return index
end

-- The items of an index from its map views: item ID -> its places, in PlaceBefore order.
local function RebuildItems(index)
    local items = {}
    for mapID, entry in pairs(index.maps) do
        local view = entry.view
        for _, item in ipairs(view.items) do
            items[item.itemID] = items[item.itemID] or {}
            table.insert(items[item.itemID], { mapID = mapID, item = item, view = view, littleData = view.littleData,
                chance = item.chance, itemCatches = item.catches, order = mapID })
        end
    end
    for _, places in pairs(items) do
        table.sort(places, PlaceBefore)
    end
    index.items, index.sorted = items, nil
    Bump()
end

local function Recompute(index, mapID)
    index.maps[mapID] = { stamp = ns.CatchDB.MapStamp(mapID), view = ns.CatchDB.QueryMap(mapID, index.filter) }
end

local function Step(index)
    if indexes[index.key] ~= index then
        return -- dropped for another filter meanwhile
    end
    local started, done = Clock(), 0
    while index.pending[1] do
        Recompute(index, table.remove(index.pending))
        done = done + 1
        if (started and Clock() - started >= STEP_MS) or (not started and done >= MAPS_PER_STEP) then
            break
        end
    end
    local finished = started and Clock()
    index.steps = index.steps + 1
    index.mostMapsInStep = math.max(index.mostMapsInStep, done)
    if finished then
        index.workMs = (index.workMs or 0) + (finished - started)
        index.longestStepMs = math.max(index.longestStepMs or 0, finished - started)
    end
    if index.pending[1] then
        C_Timer.After(0, function() Step(index) end)
    else
        index.building, index.stale, index.state = false, false, "ready"
        index.builtMs, index.builtLongestMs = index.workMs, index.longestStepMs
        RebuildItems(index)
    end
end

local function StartBuild(index, maps)
    index.pending, index.building = maps, true
    index.steps, index.mostMapsInStep, index.workMs, index.longestStepMs = 0, 0, nil, nil
    if index.state == "ready" then
        index.stale = true -- the last complete index answers meanwhile
    else
        index.state = "building"
    end
    C_Timer.After(0, function() Step(index) end)
end

-- Every read first brings the index up to date: nothing to do while no stamp moved; up to SYNC_MAPS changed maps
-- at once; more in frame steps, unless a build runs already, while the stale index answers.
local function Freshen(index)
    if index.building then
        return
    end
    local stampVersion = ns.CatchDB.GetStampVersion()
    if index.seen == stampVersion then
        return
    end
    index.seen = stampVersion
    local changed, present, removed = {}, {}, false
    for _, mapID in ipairs(ns.CatchDB.Maps(index.filter)) do
        present[mapID] = true
        local entry = index.maps[mapID]
        if not entry or entry.stamp ~= ns.CatchDB.MapStamp(mapID) then
            table.insert(changed, mapID)
        end
    end
    for mapID in pairs(index.maps) do
        if not present[mapID] then
            index.maps[mapID], removed = nil, true
        end
    end
    if index.state == "empty" or #changed > SYNC_MAPS then
        StartBuild(index, changed)
    elseif #changed > 0 or removed then
        for _, mapID in ipairs(changed) do
            Recompute(index, mapID)
        end
        RebuildItems(index)
    end
end

-- The session's first loading screen (a login or a /reload; each starts with empty session memory) builds the
-- default index a little later, so tooltips are ready at the first hover; later loading screens do not.
local scheduled = false
ns.RegisterEvent("PLAYER_ENTERING_WORLD", function()
    if not scheduled then
        scheduled = true
        C_Timer.After(DEFAULT_INDEX_DELAY, function() Freshen(IndexFor(DEFAULT_FILTER)) end)
    end
end)

-- The known items of an index, sorted by name ({ itemID, name, zones, key, poor }); kept until the version moves.
local function SortedItems(index)
    if index.sorted and index.sortedVersion == version then
        return index.sorted
    end
    local rows = {}
    for itemID, places in pairs(index.items) do
        local entry = NameOf(itemID)
        if entry.known then
            table.insert(rows, { itemID = itemID, name = entry.name, zones = #places, key = entry.key,
                poor = IsPoor(entry) })
        end
    end
    table.sort(rows, function(a, b)
        if ns.CompareText(a.name, b.name) then
            return true
        elseif ns.CompareText(b.name, a.name) then
            return false
        end
        return a.itemID < b.itemID
    end)
    index.sorted, index.sortedVersion = rows, version
    return rows
end

---------------------------------------------------------------------------
-- Reads
---------------------------------------------------------------------------
-- The state of the filter's index ("building" or "ready") after bringing it up to date: what Items returns as its
-- second value, without building the list (the tab's tick only needs this).
function Catalog.State(filter)
    local index = IndexFor(filter)
    Freshen(index)
    return index.state == "ready" and "ready" or "building"
end

-- items, state: the items of the filter as { itemID, name, zones }, sorted by name (FR-002 to FR-005): known items
-- only, grey ones only with search text, and with search text only those whose name contains it. state is
-- "building" while no complete index exists, else "ready" (maybe stale).
function Catalog.Items(filter, search)
    local index = IndexFor(filter)
    Freshen(index)
    if index.state ~= "ready" then
        return {}, "building"
    end
    local key = type(search) == "string" and search ~= "" and ns.SearchKey(search) or nil
    local list = {}
    for _, row in ipairs(SortedItems(index)) do
        if (key and row.key:find(key, 1, true)) or (not key and not row.poor) then
            table.insert(list, row)
        end
    end
    return list, "ready"
end

-- The zones of an item under the filter, in PlaceBefore order: { mapID, name, chance, catches (the zone's),
-- itemCatches, players, littleData, ranges }.
function Catalog.Places(itemID, filter)
    local index = IndexFor(filter)
    Freshen(index)
    local list = {}
    for _, place in ipairs(index.items[itemID] or {}) do
        table.insert(list, { mapID = place.mapID, name = Catalog.ZoneName(place.mapID), chance = place.chance,
            catches = place.view.catches, itemCatches = place.itemCatches, players = place.view.players,
            littleData = place.littleData, ranges = place.item.ranges })
    end
    return list
end

local spots = {} -- "<itemID>|<mapID>|<filter key>" -> { cells = the QueryCells list they come from, rows }

-- The spots of an item on one map (FR-008), in PlaceBefore order: { cell, name, point, area, chance, catches (the
-- spot's), itemCatches, players, littleData, ranges, pin }. Summed when a zone is expanded, kept until the map's
-- stamp moves (CatchDB.QueryCells keeps its views as long).
function Catalog.Spots(itemID, mapID, filter)
    local index = IndexFor(filter)
    Freshen(index)
    local key = itemID .. "|" .. mapID .. "|" .. index.key
    local cells = ns.CatchDB.QueryCells(mapID, index.filter)
    local cached = spots[key]
    if cached and cached.cells == cells then
        return cached.rows
    end
    local rows = {}
    for _, view in ipairs(cells) do
        for _, item in ipairs(view.items) do
            if item.itemID == itemID then
                local row = { cell = view.cell, point = view.point, area = view.area, chance = item.chance,
                    catches = view.catches, itemCatches = item.catches, players = view.players,
                    littleData = view.littleData, ranges = item.ranges, order = view.cell }
                row.name = Catalog.SpotName(row)
                -- The game's map pin for the spot (Core/MapPin.lua): none for a cell without a point.
                row.pin = row.point and ns.MapPin.Target({ mapID }, row.point.x, row.point.y)
                table.insert(rows, row)
            end
        end
    end
    table.sort(rows, PlaceBefore)
    spots[key] = { cells = cells, rows = rows }
    return rows
end

-- "45, 72": a spot's point in whole percent of the map, as the game's map coordinates read.
function Catalog.Coordinates(point)
    return ("%d, %d"):format(math.floor(point.x * 100 + 0.5), math.floor(point.y * 100 + 0.5))
end

-- The localized name of a spot's subzone, or nil without a known one.
function Catalog.AreaName(spot)
    local area = spot.area and C_Map.GetAreaInfo(spot.area)
    return type(area) == "string" and area ~= "" and area or nil
end

-- A spot's name (FR-015): "Subzone (45, 72)" in the client's language, the coordinates alone without a known
-- subzone, "No exact spot" for the cell without a position.
function Catalog.SpotName(spot)
    if not spot.point then
        return L["No exact spot"]
    end
    local area = Catalog.AreaName(spot)
    if area then
        return L["%s (%s)"]:format(area, Catalog.Coordinates(spot.point))
    end
    return Catalog.Coordinates(spot.point)
end

local zoneNames = {} -- map ID -> its name, for the session

-- The map's name in the client's language (FR-016): "Zone - Inner map" for a cave, a building or a dungeon map
-- inside a zone; "Unknown zone (%d)" when the game gives no map info.
function Catalog.ZoneName(mapID)
    if not zoneNames[mapID] then
        local info = C_Map.GetMapInfo(mapID)
        local name = info and info.name
        local types = Enum.UIMapType
        if not name then
            name = L["Unknown zone (%d)"]:format(mapID)
        elseif types and (info.mapType == types.Micro or info.mapType == types.Dungeon)
            and (info.parentMapID or 0) ~= 0 then
            local parent = C_Map.GetMapInfo(info.parentMapID)
            if parent and parent.name and parent.mapType == types.Zone then
                name = parent.name .. " - " .. name
            end
        end
        zoneNames[mapID] = name
    end
    return zoneNames[mapID]
end

local TOOLTIP_PLACES = 3 -- zones in an item tooltip, items in the minimap tooltip

-- "N catches from K players" from 2 players on (part 3, FR-025), else "N catches".
function Catalog.CatchesText(catches, players)
    if players >= 2 then
        return (L["%d catches from %d players"]):format(catches, players)
    end
    return (L["%d catches"]):format(catches)
end

-- A chance (or "Little data") with the players behind it from 2 on (part 3, FR-025).
function Catalog.ChanceText(chance, littleData, players)
    local text = littleData and L["Little data"] or ns.Percent(chance)
    return (players or 0) >= 2 and (L["%s (%d players)"]):format(text, players) or text
end

-- The "Caught in" lines of an item tooltip (FR-017): up to three { zone, right } pairs from the default index, stale
-- or not; the zones with 50 catches or more, or only without any, the little-data ones. nil for an item outside
-- the database and before any index exists.
function Catalog.TooltipLines(itemID)
    local index = IndexFor(DEFAULT_FILTER)
    Freshen(index)
    local places = index.state == "ready" and index.items[itemID]
    if not places then
        return nil
    end
    local reliable = not places[1].littleData -- PlaceBefore puts them first
    local lines = {}
    for _, place in ipairs(places) do
        if #lines >= TOOLTIP_PLACES or place.littleData == reliable then
            break
        end
        table.insert(lines, { zone = Catalog.ZoneName(place.mapID),
            right = Catalog.ChanceText(place.chance, place.littleData, place.view.players) })
    end
    return lines
end

-- The likely catches of the current place for the minimap tooltip in fishing mode (FR-018), counted like the "What
-- can be caught here" tab with its defaults: { items = { { name, right } }, footer }; grey items and items the
-- client does not know are left out. nil outside fishing mode or with the setting off.
function Catalog.MinimapLines()
    if not (ns.Mode.IsActive() and ns.db.settings.tooltipChances) then
        return nil
    end
    local mapID, range, cell = ns.CatchDB.GetCurrentPlace()
    local view = mapID and ns.CatchDB.Query(mapID, cell, { range = range, source = "all", water = "all" })
    if not view or view.scope == "none" then
        return { items = {}, footer = L["Nothing has been caught here yet."] }
    end
    local items = {}
    for _, item in ipairs(view.items) do
        if #items >= TOOLTIP_PLACES then
            break
        end
        local entry = NameOf(item.itemID)
        if entry.known and not IsPoor(entry) then
            table.insert(items, { name = entry.name, right = Catalog.ChanceText(item.chance, view.littleData) })
        end
    end
    return { items = items, footer = Catalog.CatchesText(view.catches, view.players) }
end

-- The item IDs of the default index whose name contains the text (any letter case), sorted by name.
function Catalog.Find(text)
    local index = IndexFor(DEFAULT_FILTER)
    Freshen(index)
    local key, found = ns.SearchKey(text), {}
    for _, row in ipairs(SortedItems(index)) do
        if row.key:find(key, 1, true) then
            table.insert(found, row.itemID)
        end
    end
    return found
end

-- What /okf catalog passes on: the item ID of an item link, nil for no text, else the text.
function Catalog.CommandArg(rest)
    local itemID = ns.ItemIDFromLink(rest)
    if itemID then
        return itemID
    end
    rest = strtrim(rest or "")
    return rest ~= "" and rest or nil
end

local function Ms(value)
    return value and ("%.1f ms"):format(value) or "no clock"
end

-- Lines for /okf debug: counts and times only, never an item name.
function Catalog.Describe()
    local lines = {}
    for _, key in ipairs({ DEFAULT_KEY, otherKey }) do
        local index = indexes[key]
        if index then
            table.insert(lines, ("index %s: %s, stale %s, %d maps, %d items"):format(key, index.state,
                tostring(index.stale), ns.CountKeys(index.maps), ns.CountKeys(index.items)))
            table.insert(lines, ("  last build %s of work, longest step %s; this build %d steps of at most %d maps")
                :format(Ms(index.builtMs), Ms(index.builtLongestMs), index.steps, index.mostMapsInStep))
        end
    end
    if #lines == 0 then
        table.insert(lines, "no index yet")
    end
    local known, unknown = 0, 0
    for _, entry in pairs(names) do
        if entry.known then
            known = known + 1
        else
            unknown = unknown + 1
        end
    end
    table.insert(lines, ("names known %d, unknown %d, requests sent %d, queued %d"):format(known, unknown, sent,
        #queue))
    return lines
end
