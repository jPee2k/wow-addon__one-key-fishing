-- BestPlaces: the zones worth fishing for gold (specs/024-best-places). Gold per hour is the value of one catch (the
-- shown kinds' items, chance x pieces x price) times the catches per hour of the place's raw cells (research R1); a
-- group sums its value and time, never averages rates (R2). The top 10 zones with at least 50 catches that pass the
-- filters; a zone opens into its subzones and spots (Catalog.GroupSpots). Levels and continents come from the game's
-- map data (V75, V76). No frames: the tab polls GetVersion on the window's tick. Its one message is a setting's:
-- SETTINGS_CHANGED("bestPlaces") from SetSafe and SetContinent.
local _, ns = ...

local BestPlaces = {}
ns.BestPlaces = BestPlaces

local TOP_ZONES = 10 -- the zones the tab lists
local TOP_ITEMS = 5 -- the items a row's tooltip names
local LEVEL_MARGIN = 3 -- Safe for me hides a zone whose lowest level is above the character's by more than this
BestPlaces.UNPRICED_MARK = 0.25 -- from this share of the catch without a price the gold carries a "*"
local STEP_MS, MAPS_PER_STEP = 3, 8 -- a build step's budget by debugprofilestop, or maps where there is no clock
local SYNC_MAPS = 4 -- up to this many maps are computed by the read that needs them; more go to frame steps
local CONTINENTS = { "all", "kalimdor", "eastern" } -- the Continent menu's values, in order
BestPlaces.CONTINENTS = CONTINENTS

local version = 0
local generation = 0 -- moves with anything that changes every zone's numbers: the kinds and the prices

local function Bump()
    version = version + 1
end

-- Grows whenever the ranking may have changed: the tab redraws when it moves.
function BestPlaces.GetVersion()
    return version
end

local function Invalidate()
    generation = generation + 1
    Bump()
end

-- What changes every zone's numbers: the prices (a scan, Auctionator, the two price switches of the settings, which
-- fire only their SETTINGS_CHANGED) and the kinds. Safe for me, the continent and the character's level only filter
-- the list when it is read: they redraw without a recount (the level a second later: UnitLevel may still give the old
-- one during PLAYER_LEVEL_UP, as Fishing/Skill.lua notes).
local INVALIDATING = { hiddenKinds = true, auctionPrices = true, auctionatorPrices = true }

ns.On("PRICES_CHANGED", Invalidate)
ns.On("SETTINGS_CHANGED", function(key)
    if INVALIDATING[key] then
        Invalidate()
    elseif key == "bestPlaces" then
        Bump()
    end
end)
ns.RegisterEvent("PLAYER_LEVEL_UP", function() C_Timer.After(1, Bump) end)

-- An item's vendor price is 0 until the client loads it: when an item counted without a price loads, the numbers move
-- once, a moment later for a burst (as Prices does with its notices). Other items the game loads change nothing.
local ITEM_INFO_DELAY = 0.5
local itemInfoPending = false
local unpricedSeen = {} -- item ID -> true: counted with no price
local loadedAtZero = {} -- item ID -> true: its info came and it still has no price (a quest item, a trophy)
ns.RegisterEvent("GET_ITEM_INFO_RECEIVED", function(_, itemID, success)
    if not (success and unpricedSeen[itemID]) then
        return
    end
    unpricedSeen[itemID] = nil
    if ns.Prices.Get(itemID) <= 0 then
        loadedAtZero[itemID] = true -- nothing to recount, now or later
        return
    end
    if not itemInfoPending then
        itemInfoPending = true
        C_Timer.After(ITEM_INFO_DELAY, function()
            itemInfoPending = false
            Invalidate()
        end)
    end
end)

---------------------------------------------------------------------------
-- The character's choices (per character, research R8)
---------------------------------------------------------------------------
local function State()
    return ns.charDB and ns.charDB.bestPlaces or { safe = true, continent = "all" }
end

function BestPlaces.GetSafe()
    return State().safe ~= false
end

-- The one way to change it (CLAUDE.md): fires SETTINGS_CHANGED("bestPlaces") when it changed.
function BestPlaces.SetSafe(on)
    if not ns.charDB or BestPlaces.GetSafe() == (on and true or false) then
        return
    end
    ns.charDB.bestPlaces.safe = on and true or false
    ns.Fire("SETTINGS_CHANGED", "bestPlaces")
end

-- "all", "kalimdor" or "eastern"; a value that is none of them reads as "all".
function BestPlaces.GetContinent()
    local value = State().continent
    return (value == "kalimdor" or value == "eastern") and value or "all"
end

function BestPlaces.SetContinent(value)
    if not ns.charDB or (value ~= "all" and value ~= "kalimdor" and value ~= "eastern")
        or BestPlaces.GetContinent() == value then
        return
    end
    ns.charDB.bestPlaces.continent = value
    ns.Fire("SETTINGS_CHANGED", "bestPlaces")
end

-- A continent value's text: the game's own name of the continent map, by ID (Principle II).
function BestPlaces.ContinentText(value)
    local mapID = ns.GameData.Continents[value]
    return mapID and ns.Catalog.ZoneName(mapID) or ns.L["All"]
end

---------------------------------------------------------------------------
-- The zones' levels (GameData.ZoneLevels) and continents (the map data, cached for the session)
---------------------------------------------------------------------------
local continents = {}

-- min, max: the zone's level range from GameData.ZoneLevels (Forever's client has none, V75; the capitals and Moonglade
-- read 1-60); a cave, a building or a dungeon map inside a zone takes its zone's range (the first listed parent); nil
-- when none is listed: such a place is never hidden.
function BestPlaces.ZoneLevels(mapID)
    -- V75, confirmed in game 2026-11-23: the table's ranges show as the game's map does (Riverglades 35-45)
    local current = mapID
    for _ = 1, 8 do
        local range = ns.GameData.ZoneLevels[current]
        if range then
            return range[1], range[2]
        end
        local info = current and current ~= 0 and C_Map.GetMapInfo(current)
        if not info then
            return nil
        end
        current = info.parentMapID
    end
end

local CONTINENT_TYPE = Enum and Enum.UIMapType and Enum.UIMapType.Continent or 2

-- Whether a map is a continent or above (old records kept a cave's catches on the continent, spec 011): such a map
-- is no place to rank.
function BestPlaces.IsContinent(mapID)
    local info = C_Map.GetMapInfo(mapID)
    return info ~= nil and info.mapType ~= nil and info.mapType <= CONTINENT_TYPE
end

-- The UiMap ID of the zone's continent (its first parent of type Continent), or nil when it cannot be told.
function BestPlaces.Continent(mapID)
    if continents[mapID] == nil then
        -- V76, confirmed in game 2026-11-23: Forever's zones have Kalimdor (1414) or the Eastern Kingdoms (1415) above
        local found, current = false, mapID
        for _ = 1, 8 do
            local info = current and current ~= 0 and C_Map.GetMapInfo(current)
            if not info then
                break
            elseif info.mapType == CONTINENT_TYPE then
                found = current
                break
            end
            current = info.parentMapID
        end
        continents[mapID] = found
    end
    return continents[mapID] or nil
end

---------------------------------------------------------------------------
-- The numbers of a place (data-model.md "Place numbers")
---------------------------------------------------------------------------
local function ShareOfGold(items, perHour)
    table.sort(items, function(a, b)
        if a.perHour ~= b.perHour then
            return a.perHour > b.perHour
        end
        return a.itemID < b.itemID
    end)
    local top = {}
    for index = 1, math.min(TOP_ITEMS, #items) do
        local item = items[index]
        if item.perHour <= 0 then
            break
        end
        table.insert(top, { itemID = item.itemID, chance = item.chance, price = item.price,
            share = perHour > 0 and item.perHour / perHour or 0 })
    end
    return top
end

-- A view's numbers: the value of one catch over the shown kinds (and, under a camp bonus value, the items it lists),
-- the gold per hour, the unpriced share of the catch's pieces and the items by the gold they bring. Under "Bonus
-- catches only" a tagged item counts with its chance under the bonus (Catalog.ItemNumbers), the gold under a bonus.
local function Numbers(view, bonus)
    local value, pieces, unpriced, items, ranges, reliable = 0, 0, 0, {}, nil, false
    local pace = view.catchesPerHour or 0
    for _, item in ipairs(view.items) do
        if ns.Catalog.IsKindShown(ns.Catalog.ItemKind(item.itemID)) and ns.Catalog.BonusShown(item.bonus, bonus) then
            local chance, littleData = item.chance, view.littleData
            if bonus == "bonusOnly" then
                -- nil without data under its bonus: it earns nothing; its little data is the bonus's
                chance, littleData = ns.Catalog.ItemNumbers(item, view)
            end
            reliable = reliable or (chance ~= nil and not littleData)
            local perCatch = (chance or 0) * item.pieces
            local price = ns.Prices.Get(item.itemID)
            pieces = pieces + perCatch
            if price <= 0 then
                unpriced = unpriced + perCatch
                unpricedSeen[item.itemID] = not loadedAtZero[item.itemID] or nil
            end
            value = value + perCatch * price
            table.insert(items, { itemID = item.itemID, chance = chance or 0, price = price,
                perHour = perCatch * price * pace })
            if item.ranges then
                ranges = ranges or { min = item.ranges.min, max = item.ranges.max }
                ranges.min = math.min(ranges.min, item.ranges.min)
                ranges.max = math.max(ranges.max, item.ranges.max)
            end
        end
    end
    local perHour = value * pace
    -- Under "Bonus catches only" a place has enough data only when an item's numbers under the bonus do, not on its
    -- total catches: a few bonus casts must not carry it into the top 10.
    local littleData = view.littleData or (bonus == "bonusOnly" and not reliable)
    return { goldPerHour = view.catchesPerHour and perHour or nil, seconds = view.seconds or 0,
        unpriced = pieces > 0 and unpriced / pieces or 0, pieces = pieces, unpricedPieces = unpriced, items = items,
        top = ShareOfGold(items, perHour), catches = view.catches, players = view.players, littleData = littleData,
        ranges = ranges, unreliable = bonus == "bonusOnly" and not reliable }
end

-- Higher gold first, little data last, ties by catches, then order.
local function Before(a, b)
    if a.littleData ~= b.littleData then
        return not a.littleData
    end
    local ga, gb = a.goldPerHour or -1, b.goldPerHour or -1
    if ga ~= gb then
        return ga > gb
    end
    if a.catches ~= b.catches then
        return a.catches > b.catches
    end
    return a.order < b.order
end

---------------------------------------------------------------------------
-- The ranking
---------------------------------------------------------------------------
local rankings = {} -- view filter key + bonus value -> { maps = { mapID -> zone }, ... }
local recent = {} -- the keys of the kept rankings, the latest last: KEEP_RANKINGS of them, as the catalog keeps two
local KEEP_RANKINGS = 2
local spotCache = {} -- mapID|key -> { cells, generation, list }

-- Keeps the latest rankings only; a dropped one takes its spots along.
local function Touch(key)
    for index, kept in ipairs(recent) do
        if kept == key then
            table.remove(recent, index)
            break
        end
    end
    table.insert(recent, key)
    while #recent > KEEP_RANKINGS do
        local dropped = table.remove(recent, 1)
        rankings[dropped] = nil
        for cacheKey in pairs(spotCache) do
            if cacheKey:sub(-#dropped - 1) == "|" .. dropped then
                spotCache[cacheKey] = nil
            end
        end
    end
end

local function Ranking(filter)
    local viewFilter = ns.Catalog.ViewFilter(filter)
    local key = ns.CatchDB.FilterKey(viewFilter) .. "|" .. tostring(filter.bonus)
    Touch(key)
    local ranking = rankings[key]
    if not ranking then
        -- A copy: the tab changes its own filter table in place, and a build in frame steps must keep querying the
        -- filter it was made for.
        local own = { range = viewFilter.range, source = viewFilter.source, water = viewFilter.water or "all",
            bonus = viewFilter.bonus or "all" }
        ranking = { key = key, filter = own, bonus = filter.bonus, maps = {}, state = "empty" }
        rankings[key] = ranking
    end
    return ranking
end

-- Into ranking.maps, or into the table a build in frame steps fills (swapped in when it ends, so a read meanwhile never
-- ranks old and new numbers together).
local function Compute(ranking, mapID, into)
    local view = ns.CatchDB.QueryMap(mapID, ranking.filter)
    local zone = Numbers(view, ranking.bonus)
    zone.mapID, zone.order, zone.stamp, zone.generation = mapID, mapID, ns.CatchDB.MapStamp(mapID), generation
    zone.continent = BestPlaces.Continent(mapID)
    local min, max = BestPlaces.ZoneLevels(mapID)
    zone.levels = min and { min = min, max = max } or nil
    (into or ranking.maps)[mapID] = zone
end

local function Stale(ranking, mapID)
    local zone = ranking.maps[mapID]
    return not zone or zone.stamp ~= ns.CatchDB.MapStamp(mapID) or zone.generation ~= generation
end

local function Clock()
    return type(debugprofilestop) == "function" and debugprofilestop() or nil
end

local function Step(ranking)
    if rankings[ranking.key] ~= ranking then
        return -- dropped (another filter was chosen): its build ends here
    end
    local start, done = Clock(), 0
    while ranking.pending[1] do
        Compute(ranking, table.remove(ranking.pending), ranking.fresh)
        done = done + 1
        local now = Clock()
        if (now and now - start >= STEP_MS) or (not now and done >= MAPS_PER_STEP) then
            break
        end
    end
    if ranking.pending[1] then
        C_Timer.After(0, function() Step(ranking) end)
    else
        for mapID, zone in pairs(ranking.fresh) do
            ranking.maps[mapID] = zone
        end
        ranking.building, ranking.state, ranking.fresh = false, "ready", nil
        Bump()
    end
end

-- Brings the ranking up to date: the maps whose stamp or generation moved are recomputed, up to SYNC_MAPS at once,
-- more in frame steps while the last complete ranking answers.
local function Freshen(ranking)
    if ranking.building then
        return
    end
    local mark = ns.CatchDB.GetStampVersion() .. ":" .. generation
    if ranking.seen == mark then
        return
    end
    ranking.seen = mark
    local present, changed = {}, {}
    for _, mapID in ipairs(ns.CatchDB.Maps(ranking.filter)) do
        present[mapID] = not BestPlaces.IsContinent(mapID) or nil
    end
    for mapID in pairs(present) do
        if Stale(ranking, mapID) then
            table.insert(changed, mapID)
        end
    end
    local removed = false
    for mapID in pairs(ranking.maps) do
        if not present[mapID] then
            ranking.maps[mapID], removed = nil, true
        end
    end
    if ranking.state == "empty" or #changed > SYNC_MAPS then
        ranking.pending, ranking.building, ranking.fresh = changed, true, {}
        if ranking.state ~= "ready" then
            ranking.state = "building"
        end
        C_Timer.After(0, function() Step(ranking) end)
        return
    end
    for _, mapID in ipairs(changed) do
        Compute(ranking, mapID)
    end
    if #changed > 0 or removed or ranking.state ~= "ready" then
        Bump() -- the tab redraws on the version: a new catch must show
    end
    ranking.state = "ready"
end

local function Passes(zone, safe, continent, level)
    if not zone.goldPerHour or zone.goldPerHour <= 0 or zone.littleData then
        return false
    end
    if safe and zone.levels and zone.levels.min > level + LEVEL_MARGIN then
        return false
    end
    return continent == nil or zone.continent == continent
end

-- zones, state: the top zones of the filter ({ mapID, goldPerHour, unpriced, top, catches, players, ranges, levels,
-- continent }), best first; state "building" while no complete ranking exists, else "ready".
function BestPlaces.Zones(filter)
    local ranking = Ranking(filter)
    Freshen(ranking)
    if ranking.state ~= "ready" then
        return {}, "building" -- no complete ranking yet: nothing half-sorted to draw
    end
    local safe, level = BestPlaces.GetSafe(), UnitLevel("player") or 0
    local continent = ns.GameData.Continents[BestPlaces.GetContinent()]
    local list = {}
    for _, zone in pairs(ranking.maps) do
        if Passes(zone, safe, continent, level) then
            table.insert(list, zone)
        end
    end
    table.sort(list, Before)
    for index = #list, TOP_ZONES + 1, -1 do
        list[index] = nil
    end
    return list, "ready"
end

-- Whether a zone's lowest level is above the character's (the Level column in red).
function BestPlaces.Unsafe(zone)
    return zone.levels ~= nil and zone.levels.min > (UnitLevel("player") or 0)
end

---------------------------------------------------------------------------
-- A zone's subzones and spots
---------------------------------------------------------------------------
-- A group's numbers: gold per hour weighted by each spot's casting time (the summed value over the summed time),
-- the items merged the same way.
local function SumSpots(spots)
    local seconds, catches, players, weighted, byItem, ranges = 0, 0, 0, 0, {}, nil
    local pieces, unpriced = 0, 0 -- the pieces of the group's catch, and those without a price
    for _, spot in ipairs(spots) do
        seconds, catches = seconds + spot.seconds, catches + spot.catches
        players = math.max(players, spot.players)
        weighted = weighted + (spot.goldPerHour or 0) * spot.seconds
        pieces = pieces + spot.pieces * spot.catches
        unpriced = unpriced + spot.unpricedPieces * spot.catches
        for _, item in ipairs(spot.items) do
            local entry = byItem[item.itemID] or { itemID = item.itemID, price = item.price, perHour = 0, chance = 0 }
            entry.perHour = entry.perHour + item.perHour * spot.seconds
            entry.chance = entry.chance + item.chance * spot.catches
            byItem[item.itemID] = entry
        end
        if spot.ranges then
            ranges = ranges or { min = spot.ranges.min, max = spot.ranges.max }
            ranges.min, ranges.max = math.min(ranges.min, spot.ranges.min), math.max(ranges.max, spot.ranges.max)
        end
    end
    local items = {}
    for _, entry in pairs(byItem) do
        entry.perHour = seconds > 0 and entry.perHour / seconds or 0
        entry.chance = catches > 0 and entry.chance / catches or 0
        table.insert(items, entry)
    end
    local perHour = seconds > 0 and weighted / seconds or nil
    local unreliable = true -- under "Bonus catches only": none of its spots has numbers under the bonus to trust
    for _, spot in ipairs(spots) do
        unreliable = unreliable and spot.unreliable == true
    end
    return { goldPerHour = perHour, seconds = seconds, catches = catches, players = players, ranges = ranges,
        unpriced = pieces > 0 and unpriced / pieces or 0, items = items, top = ShareOfGold(items, perHour or 0),
        littleData = catches < ns.CatchDB.LITTLE_DATA or unreliable, unreliable = unreliable }
end

-- The zone's elements for the list: subzone groups and spot rows (Catalog.GroupSpots), best first.
function BestPlaces.Spots(mapID, filter)
    local ranking = Ranking(filter)
    local cells = ns.CatchDB.QueryCells(mapID, ranking.filter)
    local cacheKey = mapID .. "|" .. ranking.key
    local cached = spotCache[cacheKey]
    if cached and cached.cells == cells and cached.generation == generation then
        return cached.list
    end
    local rows = {}
    for _, view in ipairs(cells) do
        local row = Numbers(view, ranking.bonus)
        row.cell, row.point, row.area, row.order = view.cell, view.point, view.area, view.cell
        row.name = ns.Catalog.SpotName(row)
        row.pin = row.point and ns.MapPin.Target({ mapID }, row.point.x, row.point.y)
        table.insert(rows, row)
    end
    table.sort(rows, Before)
    local list = ns.Catalog.GroupSpots(rows, SumSpots, Before)
    spotCache[cacheKey] = { cells = cells, generation = generation, list = list }
    return list
end

-- "12g 30s": the gold per hour as the game writes money.
function BestPlaces.FormatGold(copper)
    return ns.FormatMoney(math.floor((copper or 0) + 0.5))
end

-- Lines for /okf debug: counts and states only, never a place's or an item's name.
function BestPlaces.Describe()
    local lines = {}
    for key, ranking in pairs(rankings) do
        table.insert(lines, ("best places %s: %s, %d maps"):format(key, ranking.state, ns.CountKeys(ranking.maps)))
    end
    table.sort(lines)
    table.insert(lines, ("safe %s, continent %s"):format(tostring(BestPlaces.GetSafe()), BestPlaces.GetContinent()))
    return lines
end
