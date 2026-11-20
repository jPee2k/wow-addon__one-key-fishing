-- Catalog: the catch database across every map (specs/005-catch-catalog). For a filter it keeps an index of the
-- items and the maps they were caught on, made of CatchDB's per-map views and rebuilt only for the maps whose
-- change stamp moved, in frame steps when there are many. It also keeps the items' names in the client's language
-- and their search keys, and answers the catalog tab and the tooltips. No frames, so the tooltips use it without
-- the window; it sends no message about its data (the tab follows GetVersion on the window's tick), only two
-- settings' SETTINGS_CHANGED: the kind choice's (SetKindShown, spec 014) and the list order's (SetSort, spec 017).
local _, ns = ...
local L = ns.L

local Catalog = {}
ns.Catalog = Catalog

local STEP_MS = 3 -- a build step ends once it took this long by debugprofilestop (SC-003: under 5 ms a frame)
local MAPS_PER_STEP = 8 -- or after this many maps where the client has no frame clock (the tests)
local SYNC_MAPS = 4 -- up to this many changed maps are recomputed by the read that finds them; more go to the steps
local NAME_REQUESTS_PER_STEP = 20 -- item name requests per frame step, light on the server (Principle I)
local DEFAULT_INDEX_DELAY = 10 -- seconds after the session's first loading screen until the default index is built

local DEFAULT_FILTER = { range = "all", source = "all", water = "all", bonus = "all" }

-- A fresh copy of the default filter, for the tab to change (UI/CatalogTab.lua).
function Catalog.DefaultFilter()
    local filter = {}
    for key, value in pairs(DEFAULT_FILTER) do
        filter[key] = value
    end
    return filter
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
        -- Item names load in batches of NAME_REQUESTS_PER_STEP without errors (V35, seen in game)
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

-- "Bonus catches only" (spec 020) is a list filter over "All catches": its index is the "all" one (Catalog.Items
-- keeps the tagged rows), so it needs no index of its own, and an item's page shows all its zones.
local function IndexFilter(filter)
    if filter.bonus ~= "bonusOnly" then
        return filter
    end
    return { range = filter.range, source = filter.source, water = filter.water, bonus = "all" }
end

local function IndexFor(filter)
    filter = IndexFilter(filter)
    local key = FilterKey(filter)
    local index = indexes[key]
    if not index then
        if key ~= DEFAULT_KEY then
            if otherKey then
                indexes[otherKey] = nil
            end
            otherKey = key
        end
        index = { key = key, filter = { range = filter.range, source = filter.source, water = filter.water or "all",
            bonus = filter.bonus or "all" },
            maps = {}, items = {}, state = "empty", stale = false, building = false, steps = 0, mostMapsInStep = 0 }
        indexes[key] = index
    end
    return index
end

-- What a place or a row shows for an item of a view (specs/020-camp-buffs data-model.md "A catalog place, spot and
-- row"): chance, littleData, catches, players, withBonus: the camp bonus's numbers when the item carries one that is
-- not plain (withBonus true: the chance is the one "with the bonus"), else the item's and the view's. A known item
-- without data under its bonus has no chance, 0 catches and 0 players. Every reader of a tag's numbers asks this.
function Catalog.ItemNumbers(item, view)
    local bonus = item.bonus
    if bonus and not bonus.plain then
        return bonus.chance, bonus.littleData, bonus.catches, bonus.players, true
    end
    return item.chance, view.littleData, view.catches, view.players, false
end
local PlaceNumbers = Catalog.ItemNumbers

-- The items of an index from its map views: item ID -> its places, in PlaceBefore order.
local function RebuildItems(index)
    local items = {}
    for mapID, entry in pairs(index.maps) do
        local view = entry.view
        for _, item in ipairs(view.items) do
            items[item.itemID] = items[item.itemID] or {}
            local chance, littleData, catches, players, withBonus = PlaceNumbers(item, view)
            table.insert(items[item.itemID], { mapID = mapID, item = item, view = view, littleData = littleData,
                chance = chance, catches = catches, players = players, bonus = item.bonus, withBonus = withBonus,
                itemCatches = item.catches, order = mapID })
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

-- The known items of an index, sorted by name ({ itemID, name, zones, key, poor, chance, littleData, players, bonus:
-- the item's best place in PlaceBefore order }); kept until the version moves.
local function SortedItems(index)
    if index.sorted and index.sortedVersion == version then
        return index.sorted
    end
    local rows = {}
    for itemID, places in pairs(index.items) do
        local entry = NameOf(itemID)
        if entry.known then
            table.insert(rows, { itemID = itemID, name = entry.name, zones = #places, key = entry.key,
                poor = IsPoor(entry), chance = places[1].chance, littleData = places[1].littleData,
                players = places[1].players, bonus = places[1].bonus })
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

---------------------------------------------------------------------------
-- The list's order (specs/017-catalog-sort)
---------------------------------------------------------------------------
Catalog.SORTS = { "name", "price", "chance" } -- the menu's order; "name" is the default

local KNOWN_SORT = {}
for _, sort in ipairs(Catalog.SORTS) do
    KNOWN_SORT[sort] = true
end

-- The saved order of the catalog's list; a saved value that is no order reads as "name".
function Catalog.GetSort()
    local sort = ns.db and ns.db.settings.catalogSort
    return KNOWN_SORT[sort] and sort or "name"
end

-- The one way to change the order (CLAUDE.md): fires SETTINGS_CHANGED("catalogSort") when it changed.
function Catalog.SetSort(sort)
    if not KNOWN_SORT[sort] or not ns.db or Catalog.GetSort() == sort then
        return
    end
    ns.db.settings.catalogSort = sort
    ns.Fire("SETTINGS_CHANGED", "catalogSort")
end

-- An order's text in the addon's language, looked up when drawn.
function Catalog.SortText(sort)
    if sort == "price" then
        return L["Price"]
    elseif sort == "chance" then
        return L["Chance"]
    end
    return L["Name"]
end

-- Sorts the rows (by name already) in place by the saved order: "price" by Prices.Get (the value of the statistics:
-- vendor or a trusted auction price), highest first; "chance" by the chance of the item's best place, highest first,
-- the items with little data everywhere after the others. Ties keep the order by name. Prices are read here, not
-- cached: a scan moves them without moving the catalog's version.
local function SortRows(list)
    local sort = Catalog.GetSort()
    if sort == "name" then
        return
    end
    local position, value = {}, {}
    for i, row in ipairs(list) do
        position[row] = i
        if sort == "price" then
            value[row] = ns.Prices.Get(row.itemID) -- once per row, not in the comparator
        else
            value[row] = row.chance or 0
        end
    end
    table.sort(list, function(a, b)
        if sort == "chance" and (a.littleData or false) ~= (b.littleData or false) then
            return not a.littleData
        end
        if value[a] ~= value[b] then
            return value[a] > value[b]
        end
        return position[a] < position[b]
    end)
end

-- Whether a row (or a view's item) with this camp bonus tag is listed under the filter value (spec 020): "Bonus
-- catches only" keeps the tagged ones (a non-plain tag); "No camp bonus" leaves out every tagged one, plain too
-- (a Bloated fish of older catches whose bonus is not known: decision 35); any other value lists every row.
function Catalog.BonusShown(bonus, value)
    if value == "bonusOnly" then
        return bonus ~= nil and not bonus.plain
    elseif value == "none" then
        return bonus == nil
    end
    return true
end

-- items, state: the items of the filter as { itemID, name, zones, chance, littleData }, in the saved order (by name
-- unless the player chose another, spec 017; FR-002 to FR-005): known items only, grey ones only with search text,
-- and with search text only those whose name contains it; under "Bonus catches only" (spec 020) the items whose best
-- place is tagged, under "No camp bonus" the untagged ones (Catalog.BonusShown). state is "building" while no
-- complete index exists, else "ready" (maybe stale).
function Catalog.Items(filter, search)
    local index = IndexFor(filter)
    Freshen(index)
    if index.state ~= "ready" then
        return {}, "building"
    end
    local key = type(search) == "string" and search ~= "" and ns.SearchKey(search) or nil
    local list = {}
    for _, row in ipairs(SortedItems(index)) do
        local searched = (key and row.key:find(key, 1, true)) or (not key and not row.poor)
        if searched and Catalog.BonusShown(row.bonus, filter.bonus) then
            table.insert(list, row)
        end
    end
    SortRows(list)
    return list, "ready"
end

-- The zones of an item under the filter, in PlaceBefore order: { mapID, name, chance, catches (the zone's),
-- itemCatches, players, littleData, ranges, bonus }; a tagged item's numbers are its camp bonus's (spec 020).
function Catalog.Places(itemID, filter)
    local index = IndexFor(filter)
    Freshen(index)
    local list = {}
    for _, place in ipairs(index.items[itemID] or {}) do
        table.insert(list, { mapID = place.mapID, name = Catalog.ZoneName(place.mapID), chance = place.chance,
            catches = place.catches, itemCatches = place.itemCatches, players = place.players,
            littleData = place.littleData, ranges = place.item.ranges, bonus = place.bonus })
    end
    return list
end

local spots = {} -- "<itemID>|<mapID>|<filter key>" -> { cells = the QueryCells list they come from, rows }

-- The spots of an item on one map (FR-008), in PlaceBefore order: { cell, name, point, area, chance, catches (the
-- spot's), itemCatches, players, littleData, ranges, pin, bonus }; a tagged item's numbers are its camp bonus's
-- (spec 020). Summed when a zone is expanded, kept until the map's stamp moves (CatchDB.QueryCells keeps its views
-- as long).
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
                local chance, littleData, catches, players = PlaceNumbers(item, view)
                local row = { cell = view.cell, point = view.point, area = view.area, chance = chance,
                    catches = catches, itemCatches = item.catches, players = players,
                    littleData = littleData, ranges = item.ranges, order = view.cell, bonus = item.bonus }
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

---------------------------------------------------------------------------
-- Item kinds (specs/014-catch-filters): the lists of both tabs are grouped by kind, and the player may hide kinds.
-- The kind filter applies to finished item lists only: the views, their sums and the indexes never see it, so a
-- shown item's numbers are the same whatever is hidden (FR-010, research R2).
---------------------------------------------------------------------------
Catalog.KINDS = { "fish", "containers", "potions", "reagents", "other" }

local KNOWN_KIND = {}
for _, kind in ipairs(Catalog.KINDS) do
    KNOWN_KIND[kind] = true
end

-- The kind of an item: the list by ID (every item of the bundled seed and every fished container, a test makes
-- sure), then the client's class numbers, else "other" (also for an item the client does not know yet). Not cached: an
-- item the game learns during the session gets its class kind at the next draw. Never by name or quality
-- (Principle II, FR-005).
function Catalog.ItemKind(itemID)
    local kinds = ns.GameData.ItemKinds
    local listed = kinds.byItem[itemID]
    if listed then
        return listed
    end
    local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
    if classID then
        return kinds.byClass[classID .. ":" .. tostring(subClassID)] or kinds.byClass[tostring(classID)] or "other"
    end
    return "other"
end

-- A kind's text in the addon's language, looked up when drawn (never while the files load).
function Catalog.KindText(kind)
    if kind == "fish" then
        return L["Fish"]
    elseif kind == "containers" then
        return L["Containers"]
    elseif kind == "potions" then
        return L["Potions & drinks"]
    elseif kind == "reagents" then
        return L["Reagents & herbs"]
    end
    return L["Other"]
end

local function HiddenKinds()
    return ns.db and ns.db.settings.hiddenKinds or {}
end

function Catalog.IsKindShown(kind)
    return not HiddenKinds()[kind]
end

-- The hidden kinds in KINDS order (a saved name that is no kind is left out).
local function HiddenKindList()
    local hidden, list = HiddenKinds(), {}
    for _, kind in ipairs(Catalog.KINDS) do
        if hidden[kind] then
            table.insert(list, kind)
        end
    end
    return list
end

-- shown, total: how many of the kinds are shown, for the button.
function Catalog.ShownKinds()
    return #Catalog.KINDS - #HiddenKindList(), #Catalog.KINDS
end

-- The one way to change the choice (CLAUDE.md): fires SETTINGS_CHANGED("hiddenKinds") when it changed.
function Catalog.SetKindShown(kind, shown)
    if not KNOWN_KIND[kind] or not ns.db then
        return
    end
    local hidden = ns.db.settings.hiddenKinds
    local value = (not shown) or nil
    if hidden[kind] == value then
        return
    end
    hidden[kind] = value
    ns.Fire("SETTINGS_CHANGED", "hiddenKinds")
end

-- list, hiddenCount: rows that carry itemID (in a view's order) as the lists draw them: { header = kind } before
-- each shown kind's rows, in KINDS order, no header for an empty or hidden kind; the rows keep their order and are
-- not copied. hiddenCount: the rows of hidden kinds.
function Catalog.Group(items)
    local hidden, byKind, hiddenCount = HiddenKinds(), {}, 0
    for _, row in ipairs(items) do
        local kind = Catalog.ItemKind(row.itemID)
        if hidden[kind] then
            hiddenCount = hiddenCount + 1
        else
            byKind[kind] = byKind[kind] or {}
            table.insert(byKind[kind], row)
        end
    end
    local list = {}
    for _, kind in ipairs(Catalog.KINDS) do
        if byKind[kind] then
            table.insert(list, { header = kind })
            for _, row in ipairs(byKind[kind]) do
                table.insert(list, row)
            end
        end
    end
    return list, hiddenCount
end

local TOOLTIP_PLACES = 3 -- zones in an item tooltip, items in the minimap tooltip

-- "N catches from K players" from 2 players on (part 3, FR-025), else "N catches" ("1 catch" for one).
function Catalog.CatchesText(catches, players)
    if players >= 2 then
        return (L["%d catches from %d players"]):format(catches, players)
    end
    if catches == 1 then
        return L["1 catch"]
    end
    return (L["%d catches"]):format(catches)
end

-- A chance (or "Little data", also for a missing chance) with the players behind it from 2 on (part 3, FR-025).
-- withBonus (spec 020: tooltips, the "Caught in:" lines, the minimap lines, never a plain tag): the chance among the
-- catches made with the camp bonus, "0.47% with the bonus (3 players)"; the rows' cells show the number alone.
function Catalog.ChanceText(chance, littleData, players, withBonus)
    local text
    if littleData or chance == nil then
        text = L["Little data"]
    else
        text = ns.Percent(chance)
        if withBonus then
            text = (L["%s with the bonus"]):format(text)
        end
    end
    return (players or 0) >= 2 and (L["%s (%d players)"]):format(text, players) or text
end

-- The texts of a camp bonus by key: tag (its name, the first line of its tooltip), tip (what the player does to get
-- the catch) and label (its value in the "Camp bonus" filter). Read when drawn, never while the files load.
local function BonusTexts(key)
    local texts = {
        rack = { tag = L["Fishing Rack bonus"], label = L["Fishing Rack"],
            tip = L["Bonus catch: comes only with the buff of a Fishing Rack (Uncommon Fishing)."] },
        hut = { tag = L["Fishing Hut bonus"], label = L["Fishing Hut"],
            tip = L["Bonus catch: comes only with the buff of a Fishing Hut (Rare Fishing)."] },
    }
    return texts[key] or texts.rack
end

function Catalog.BonusTag(key)
    return BonusTexts(key).tag
end

-- several: the item is a known item of more than one bonus (a Bloated fish: the Rack or the Hut, decision 32).
function Catalog.BonusTip(key, several)
    if several then
        return L["Bonus catch: comes only with the buff of a Fishing Rack or a Fishing Hut."]
    end
    return BonusTexts(key).tip
end

-- A value of the "Camp bonus" filter as its menu names it: "all", "none", "bonusOnly" or a bonus's key.
function Catalog.BonusLabel(value)
    if value == "none" then
        return L["No camp bonus"]
    elseif value == "all" then
        return L["All catches"]
    elseif value == "bonusOnly" then
        return L["Bonus catches only"]
    end
    return BonusTexts(value).label
end

-- The button's text for a value: "Camp bonus: <the value in short>" (spec 020 decision 23; the menu has the full
-- labels). Whole texts, so each language words them its own way.
function Catalog.BonusButtonText(value)
    local texts = { all = L["Camp bonus: All"], none = L["Camp bonus: No bonus"],
        bonusOnly = L["Camp bonus: Bonus only"], rack = L["Camp bonus: Rack"], hut = L["Camp bonus: Hut"] }
    return texts[value] or texts.all
end

-- VERIFY(V66): the camp features' item icons are known to every client
-- The tag's icon: the camp feature's item icon (by its item ID, the same in every language), or nil.
function Catalog.BonusIcon(key)
    local bonus = ns.Camp.Bonus(key)
    return bonus and C_Item.GetItemIconByID(bonus.item)
end

-- The "Caught in" lines of an item tooltip (FR-017): up to three { zone, right } pairs from the default index, stale
-- or not; the zones with 50 catches or more, or only without any, the little-data ones. nil for an item outside
-- the database and before any index exists. A tagged place's chance is in the bonus form (spec 020); the second value
-- is the best place's camp bonus table (the tag's explanation line, UI/ItemHooks.lua), or nil.
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
            right = Catalog.ChanceText(place.chance, place.littleData, place.players, place.withBonus) })
    end
    return lines, places[1].bonus
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
            local chance, littleData, _, _, withBonus = PlaceNumbers(item, view) -- a tag's own numbers (spec 020)
            table.insert(items, { name = entry.name, right = Catalog.ChanceText(chance, littleData, nil, withBonus) })
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
    -- The kind choice (spec 014), last so the first line stays the index's.
    local hidden = HiddenKindList()
    table.insert(lines, "kinds hidden: " .. (#hidden > 0 and table.concat(hidden, ", ") or "none"))
    return lines
end
