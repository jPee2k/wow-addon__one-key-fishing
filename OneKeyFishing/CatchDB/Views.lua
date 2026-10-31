-- CatchDB/Views.lua: what the tabs, the catalog and the tooltips read: the sums of a place or a map over the
-- own tables, the seed and other players' records, with their weights; the index of others' records; the seed
-- info; the Describe lines of the debug report.
local _, ns = ...
local CatchDB = ns.CatchDB
local P = CatchDB.private
local MAX_RANGE, SeedEpoch = CatchDB.MAX_RANGE, CatchDB.SeedEpoch
local CountKeys = ns.CountKeys -- Data.lua
local mapCache, MapRange, KeyMapRange, KeyMapID = P.mapCache, P.MapRange, P.KeyMapRange, P.KeyMapID
local AddToOwnIndex, BuildKey, Seed, SeedField = P.AddToOwnIndex, P.BuildKey, P.Seed, P.SeedField
local OlderBuild, OwnRecord = P.OlderBuild, P.OwnRecord
-- P.others: { byKey = { place -> { entry -> true } }, byPrefix = { prefix -> { entry -> true } }, byRecord }
-- P.frozen: the frozen own records; P.lastPool: what IsPoolLoot said about the last catch

---------------------------------------------------------------------------
-- Views
---------------------------------------------------------------------------
local LITTLE_DATA = 50 -- catches a scope needs before chances are shown
-- Weights (specs/004-public-channel-sync, research.md R7): from WEIGHT_FROM contributions on, no other player's
-- contribution carries more than WEIGHT_SHARE of the weight in the shown numbers.
local WEIGHT_FROM, WEIGHT_SHARE = 5, 1 / 5
local NEW_ITEM_REPORTERS = 3 -- other contributions that must report an item neither the seed nor the own catch has

-- A sum also tallies who it comes from: the IDs of the records with a summed cell and the seed's largest k. The
-- seed and the own catch go into the sum itself; each other player's contribution into its own part, so it can be
-- weighted before the parts are added.
-- x: the catches weighted by casts, for the miss rate (a seed cell's own x, else its catches).
-- px, py, n: the summed positions of the cells that have one and their casts, for a spot's point; ranges: item ID ->
-- { min, max }, the skill ranges the item was caught in. These three are never weighted.
local function NewSum()
    return { c = 0, m = 0, x = 0, i = {}, a = {}, ids = {}, seedK = 0, seedUnweighted = 0, parts = {}, px = 0,
        py = 0, n = 0, ranges = {} }
end

local function AddRanges(sum, cell, range)
    if not range or type(cell.i) ~= "table" then
        return
    end
    for itemID, entry in pairs(cell.i) do
        if type(entry) == "table" and (tonumber(entry[1]) or 0) > 0 then
            local span = sum.ranges[itemID]
            if span then
                span.min, span.max = math.min(span.min, range), math.max(span.max, range)
            else
                sum.ranges[itemID] = { min = range, max = range }
            end
        end
    end
end

-- factor: the weight of the cell's counts (research.md R7 of part 3), 1 when nil.
local function AddCounts(target, cell, factor)
    factor = factor or 1
    target.c = target.c + (tonumber(cell.c) or 0) * factor
    target.m = target.m + (tonumber(cell.m) or 0) * factor
    if type(cell.i) == "table" then
        for itemID, entry in pairs(cell.i) do
            if type(entry) == "table" then
                local total = target.i[itemID] or { 0, 0 }
                total[1] = total[1] + (tonumber(entry[1]) or 0) * factor
                total[2] = total[2] + (tonumber(entry[2]) or 0) * factor
                target.i[itemID] = total
            end
        end
    end
end

-- A cell read through the water filter (specs/005-catch-catalog, research R5): "pool" its pool part, "open" the
-- rest; both without misses, which have no loot source. A cell without a pool part is all open water. The
-- harvest's x and r give way to the filtered catches.
local function ThroughWater(cell, water)
    if water == nil or water == "all" then
        return cell
    end
    local pool = type(cell.p) == "table" and cell.p or nil
    local poolCatches = pool and tonumber(pool.c) or 0
    local poolItems = pool and type(pool.i) == "table" and pool.i or {}
    if water == "pool" then
        return { c = poolCatches, m = 0, i = poolItems, k = cell.k, a = cell.a }
    end
    local items = {}
    for itemID, entry in pairs(type(cell.i) == "table" and cell.i or {}) do
        local inPool = poolItems[itemID]
        if type(entry) == "table" then
            items[itemID] = { (tonumber(entry[1]) or 0) - (inPool and tonumber(inPool[1]) or 0),
                (tonumber(entry[2]) or 0) - (inPool and tonumber(inPool[2]) or 0) }
        end
    end
    return { c = (tonumber(cell.c) or 0) - poolCatches, m = 0, i = items, k = cell.k, a = cell.a }
end

-- range: the skill range of the cell's place key.
local function AddCell(sum, cell, source, range)
    if type(cell) ~= "table" then
        return
    end
    if tonumber(cell.px) and tonumber(cell.py) then
        sum.px, sum.py = sum.px + cell.px, sum.py + cell.py
        sum.n = sum.n + (tonumber(cell.c) or 0) + (tonumber(cell.m) or 0)
    end
    cell = ThroughWater(cell, sum.water)
    AddRanges(sum, cell, range)
    -- Who caught something here: a cell of misses only adds no player.
    if (tonumber(cell.c) or 0) > 0 then
        if source.seed then
            sum.seedK = math.max(sum.seedK, tonumber(cell.k) or 0)
        elseif source.id then
            sum.ids[source.id] = true
        end
    end
    local target = sum
    if source.other then
        target = sum.parts[source.id]
        if not target then
            target = { c = 0, m = 0, x = 0, i = {}, a = {} }
            sum.parts[source.id] = target
        end
    end
    AddCounts(target, cell)
    if type(cell.a) == "table" then
        for areaID, n in pairs(cell.a) do
            target.a[areaID] = (target.a[areaID] or 0) + (tonumber(n) or 0)
        end
    end
    -- A seed cell weighted by the harvest carries its catches weighted by casts (x) and its raw catches (r); records
    -- never do (CleanCell).
    target.x = target.x + ((source.seed and tonumber(cell.x)) or tonumber(cell.c) or 0)
    if source.seed and tonumber(cell.r) then
        sum.seedUnweighted = sum.seedUnweighted + math.max(0, tonumber(cell.r) - (tonumber(cell.c) or 0))
    end
end

-- The seed's keys per "<mapID>:<range>", built once per seed (the seed is large and never changes in place).
local seedIndex, indexedSeed

local function SeedIndex(cells)
    if indexedSeed ~= cells then
        seedIndex, indexedSeed = {}, cells
        for key in pairs(cells) do
            local prefix = KeyMapRange(key)
            if prefix then
                seedIndex[prefix] = seedIndex[prefix] or {}
                table.insert(seedIndex[prefix], key)
            end
        end
    end
    return seedIndex
end

-- Every cell of the other players' records (Share.lua) as an entry { cell, id, build, place, prefix }, in sets by
-- place key and by "<mapID>:<range>": one index for all of them, so a query does not walk every record. Built on
-- the first query; SHARED_DATA_CHANGED with the changed keys updates only those records, without the keys it is
-- built anew; an own catch leaves it alone.

local function AddToSet(sets, name, entry)
    sets[name] = sets[name] or {}
    sets[name][entry] = true
end

-- Which records under "<id>@<epoch>" count: "own" for one the own record left on a roll (Sources counts those
-- with sharing off too), "other" for another player's, nil for a unit the seed holds in part (its first part is in
-- the seed; the store deletes those it holds whole) or anything malformed.
local function CountedUnit(key, record)
    if CatchDB.IsOtherKey(key) and type(record) == "table" and type(record.builds) == "table"
        and not CatchDB.AbsorbedSeq(record.id, record.epoch) then
        return record.id == ns.db.shared.myID and "own" or "other"
    end
end

local function IndexRecord(key)
    local record = ns.db.shared.records[key]
    if CountedUnit(key, record) ~= "other" then
        return
    end
    local entries = {}
    for build, cells in pairs(record.builds) do
        for place, cell in pairs(type(cells) == "table" and cells or {}) do
            local prefix = KeyMapRange(place)
            if prefix then
                local entry = { cell = cell, id = record.id, build = build, place = place, prefix = prefix,
                    other = true, mapID = KeyMapID(prefix), range = tonumber(prefix:match(":(%d)$")) }
                AddToSet(P.others.byKey, place, entry)
                AddToSet(P.others.byPrefix, prefix, entry)
                table.insert(entries, entry)
            end
        end
    end
    P.others.byRecord[key] = entries
end

local function RemoveFromSet(sets, name, entry)
    local set = sets[name]
    set[entry] = nil
    if next(set) == nil then
        sets[name] = nil
    end
end

local function UnindexRecord(key)
    for _, entry in ipairs(P.others.byRecord[key] or {}) do
        RemoveFromSet(P.others.byKey, entry.place, entry)
        RemoveFromSet(P.others.byPrefix, entry.prefix, entry)
    end
    P.others.byRecord[key] = nil
end

-- The own records frozen by a roll that the seed does not hold yet: they count like the live one.

local function Frozen()
    if not P.frozen then
        P.frozen = {}
        for key, record in pairs(ns.db.shared.records) do
            if CountedUnit(key, record) == "own" then
                table.insert(P.frozen, record)
            end
        end
    end
    return P.frozen
end

local function Others()
    if not P.others then
        P.others = { byKey = {}, byPrefix = {}, byRecord = {} }
        for key in pairs(ns.db.shared.records) do
            IndexRecord(key)
        end
    end
    return P.others
end

-- True for a record key of the own ID: the live record, or one a roll froze under "<myID>@<epoch>".
local function IsOwnKey(key)
    local myID = ns.db.shared.myID
    return key == myID or (CatchDB.IsOtherKey(key) and CatchDB.ParseUnit(key) == myID)
end

local function OwnIndex()
    if not P.ownIndex then
        P.ownIndex = {}
        for key in pairs(ns.db.shared.mine) do
            AddToOwnIndex(key)
        end
        for key, record in pairs(ns.db.shared.records) do
            if IsOwnKey(key) and type(record) == "table" and type(record.builds) == "table" then
                for _, cells in pairs(record.builds) do
                    for place in pairs(type(cells) == "table" and cells or {}) do
                        AddToOwnIndex(place)
                    end
                end
            end
        end
    end
    return P.ownIndex
end

-- What a source sums for a map. "all": the seed, the own record and, with sharing on, the other players'
-- records, each without its cells of game versions older than a reset of the map (after a patch that changed its
-- catch); "mine": the lifetime counts. A record's cells count for its ID in the player count.
local function Sources(source, mapID, water)
    if source == "mine" then
        return { tables = { { cells = ns.db.shared.mine } }, water = water }
    end
    local reset = SeedField("resets")[mapID]
    local own = OwnRecord()
    local sources = { seed = { cells = Seed().cells, seed = true }, tables = {}, reset = reset,
        others = ns.Share.IsEnabled() and Others() or nil, water = water }
    local records = { own }
    for _, record in ipairs(Frozen()) do
        table.insert(records, record)
    end
    for _, record in ipairs(records) do
        for build, cells in pairs(record.builds) do
            if type(cells) == "table" and not (reset and OlderBuild(build, reset)) then
                table.insert(sources.tables, { cells = cells, id = own.id })
            end
        end
    end
    return sources
end

local function AddOthers(sum, entries, reset)
    for entry in pairs(entries or {}) do
        if not (reset and OlderBuild(entry.build, reset)) then
            AddCell(sum, entry.cell, entry, entry.range)
        end
    end
end

-- One cell of a map over the given skill ranges.
local function SumSpot(sources, mapID, ranges, cell)
    local sum = NewSum()
    sum.water = sources.water
    for _, range in ipairs(ranges) do
        local key = CatchDB.PlaceKey(mapID, range, cell)
        if sources.seed then
            AddCell(sum, sources.seed.cells[key], sources.seed, range)
        end
        for _, source in ipairs(sources.tables) do
            AddCell(sum, source.cells[key], source, range)
        end
        if sources.others then
            AddOthers(sum, sources.others.byKey[key], sources.reset)
        end
    end
    return sum
end

-- Contributions behind a sum, each at most once (specs/003-guild-group-sync/research.md R9): records of IDs
-- the seed never absorbed are other players for sure; those it absorbed may be among the seed's k, so they
-- only count above it.
local function Players(sum)
    local absorbed, known, fresh = SeedField("absorbed"), 0, 0
    for id in pairs(sum.ids) do
        if absorbed[id] then
            known = known + 1
        else
            fresh = fresh + 1
        end
    end
    return math.max(sum.seedK, known) + fresh
end

local function SumMap(sources, mapID, ranges)
    local sum, own = NewSum(), OwnIndex()
    sum.water = sources.water
    for _, range in ipairs(ranges) do
        local prefix = MapRange(mapID, range)
        if sources.seed then
            for _, key in ipairs(SeedIndex(sources.seed.cells)[prefix] or {}) do
                AddCell(sum, sources.seed.cells[key], sources.seed, range)
            end
        end
        if sources.others then
            AddOthers(sum, sources.others.byPrefix[prefix], sources.reset)
        end
        for key in pairs(own[prefix] or {}) do
            for _, source in ipairs(sources.tables) do
                AddCell(sum, source.cells[key], source, range)
            end
        end
    end
    return sum
end

-- The cells of a map ("47", "x") with a cell in any source, in the given ranges.
local function MapCells(sources, mapID, ranges)
    local cells, own = {}, OwnIndex()
    local function Add(key)
        local cell = key:match(":([^:]+)$")
        if cell then
            cells[cell] = true
        end
    end
    for _, range in ipairs(ranges) do
        local prefix = MapRange(mapID, range)
        if sources.seed then
            for _, key in ipairs(SeedIndex(sources.seed.cells)[prefix] or {}) do
                Add(key)
            end
        end
        for entry in pairs(sources.others and sources.others.byPrefix[prefix] or {}) do
            Add(entry.place)
        end
        for key in pairs(own[prefix] or {}) do
            Add(key)
        end
    end
    return cells
end

-- Catches of a sum with every other player's part, unweighted.
-- The real catches: what the harvest's weights took off the seed's cells is added back (the little-data threshold).
local function RawCatches(sum)
    local catches = sum.c + sum.seedUnweighted
    for _, part in pairs(sum.parts) do
        catches = catches + part.c
    end
    return catches
end

-- What a contribution is capped by (research.md R7 of part 3): its catches for the chances and pieces, its casts for
-- the miss rate (so one with few catches and many misses holds no more of the miss rate than of the chances).
local function Catches(cell)
    return cell.c
end

local function Casts(cell)
    return cell.x + cell.m
end

-- The weight factor of each other player's contribution (research.md R7 of part 3): from WEIGHT_FROM contributions
-- on, the largest ones by `amount` are capped one by one at T, where T is WEIGHT_SHARE of the weighted total; the
-- seed block and the own catch are not capped. At most four are capped: the fifth is never above the rest.
local function WeightFactors(sum, players, amount)
    local factors = {}
    if players < WEIGHT_FROM then
        return factors
    end
    local list, rest = {}, 0
    for id, part in pairs(sum.parts) do
        local value = amount(part)
        if value > 0 then
            table.insert(list, { id = id, c = value })
            rest = rest + value
        end
    end
    table.sort(list, function(a, b)
        if a.c ~= b.c then
            return a.c > b.c
        end
        return a.id < b.id
    end)
    local shares, base = 1 / WEIGHT_SHARE, amount(sum)
    local cap, capped = (base + rest) * WEIGHT_SHARE, 0
    for _, entry in ipairs(list) do
        if entry.c <= cap then
            break
        end
        capped, rest = capped + 1, rest - entry.c
        cap = (base + rest) / (shares - capped)
    end
    for _, entry in ipairs(list) do
        if entry.c > cap then
            factors[entry.id] = cap / entry.c
        end
    end
    return factors
end

-- Adds the item IDs of every cell to `set` (item ID -> true).
local function AddItemsOf(set, cells)
    for _, cell in pairs(type(cells) == "table" and cells or {}) do
        if type(cell) == "table" and type(cell.i) == "table" then
            for itemID in pairs(cell.i) do
                set[itemID] = true
            end
        end
    end
end

-- Item ID -> true for every item of the seed, built once per seed.
local seedItems, seedItemsOf

local function SeedItems()
    local cells = Seed().cells
    if seedItemsOf ~= cells then
        seedItems, seedItemsOf = {}, cells
        AddItemsOf(seedItems, cells)
    end
    return seedItems
end

-- Item ID -> true for every item of the own catch (shared.mine and the records of the own ID), built once and grown
-- by catches (ownItems is declared at the top: Settle grows it).
local function OwnItems()
    if not P.ownItems then
        P.ownItems = {}
        AddItemsOf(P.ownItems, ns.db.shared.mine)
        for key, record in pairs(ns.db.shared.records) do
            if type(record) == "table" and record.id == ns.db.shared.myID and type(record.builds) == "table"
                and (key == record.id or CatchDB.IsOtherKey(key)) then
                for _, cells in pairs(record.builds) do
                    AddItemsOf(P.ownItems, cells)
                end
            end
        end
    end
    return P.ownItems
end

-- Item ID -> the number of other players' contributions that report it anywhere on the map, in any range
-- (FR-014: an item neither the seed nor the own catch has is shown from NEW_ITEM_REPORTERS of them on).
local function Reporters(sources, mapID)
    local ids, reporters = {}, {}
    if not sources.others then
        return reporters
    end
    for range = 0, MAX_RANGE do
        for entry in pairs(sources.others.byPrefix[MapRange(mapID, range)] or {}) do
            if type(entry.cell.i) == "table" and not (sources.reset and OlderBuild(entry.build, sources.reset)) then
                for itemID, counts in pairs(entry.cell.i) do
                    if type(counts) == "table" and (tonumber(counts[1]) or 0) > 0 then
                        ids[itemID] = ids[itemID] or {}
                        ids[itemID][entry.id] = true
                    end
                end
            end
        end
    end
    for itemID, set in pairs(ids) do
        reporters[itemID] = CountKeys(set)
    end
    return reporters
end

-- rules: { mine = source "mine" (every item shown), reporters = Reporters(...) }.
local function BuildView(scope, sum, rules)
    local players = Players(sum)
    local factors, castFactors = WeightFactors(sum, players, Catches), WeightFactors(sum, players, Casts)
    local weighted, raw = { c = 0, m = 0, i = {} }, { c = 0, m = 0, i = {} }
    local misses, casts = sum.m, Casts(sum) -- the miss rate's sums, weighted by casts
    AddCounts(weighted, sum)
    AddCounts(raw, sum)
    for id, part in pairs(sum.parts) do
        AddCounts(weighted, part, factors[id])
        AddCounts(raw, part)
        local factor = castFactors[id] or 1
        misses, casts = misses + part.m * factor, casts + Casts(part) * factor
    end
    local seed, own, reporters = SeedItems(), OwnItems(), rules.reporters
    local items = {}
    for itemID, entry in pairs(weighted.i) do
        local catches = raw.i[itemID][1]
        local shown = rules.mine or seed[itemID] or own[itemID] or (reporters[itemID] or 0) >= NEW_ITEM_REPORTERS
        if catches > 0 and entry[1] > 0 and shown then
            table.insert(items, { itemID = itemID, catches = catches,
                chance = weighted.c > 0 and entry[1] / weighted.c or 0, pieces = entry[2] / entry[1],
                reporters = reporters[itemID] or 0, inSeed = seed[itemID] == true, ranges = sum.ranges[itemID] })
        end
    end
    table.sort(items, function(a, b)
        if a.catches ~= b.catches then
            return a.catches > b.catches
        end
        return a.itemID < b.itemID
    end)
    -- The subzone with the most casts, other players' parts scaled like their casts; ties to the lower ID.
    local areas, area = {}, nil
    for areaID, n in pairs(sum.a) do
        areas[areaID] = n
    end
    for id, part in pairs(sum.parts) do
        for areaID, n in pairs(part.a) do
            areas[areaID] = (areas[areaID] or 0) + n * (castFactors[id] or 1)
        end
    end
    for areaID, n in pairs(areas) do
        if n > 0 and (not area or n > areas[area] or (n == areas[area] and areaID < area)) then
            area = areaID
        end
    end
    local catches = RawCatches(sum)
    return { scope = scope, area = area, littleData = catches < LITTLE_DATA, catches = catches, misses = raw.m,
        -- No miss rate under a water filter: a miss has no loot source (FR-022).
        missRate = (sum.water or "all") == "all" and (casts > 0 and misses / casts or 0) or nil, items = items,
        players = players,
        point = sum.n > 0 and { x = sum.px / sum.n / 1000, y = sum.py / sum.n / 1000 } or nil }
end

local function Ranges(filter)
    return filter.range == "all" and CatchDB.RANGES or { filter.range }
end

local function FilterKey(filter)
    return tostring(filter.range) .. "|" .. filter.source .. "|" .. (filter.water or "all")
end

local cache, cacheVersion = {}, nil
local reportersCache = {} -- "<mapID>|<source>" -> Reporters(...): the map's, whatever the spot or range

-- What a place gives (contracts/catchdb-api.md): the spot, or the whole map when the spot has fewer than
-- LITTLE_DATA catches. filter = { range = 0..4 or "all", source = "all" or "mine" }. A view is
-- { scope = "spot" | "map" | "none", littleData, catches, misses, missRate, players,
-- items = { { itemID, catches, chance, pieces, reporters, inSeed } } }: catches is the real sum (a seed cell the
-- harvest weighted gives its raw catches, r); misses and the items' catches are summed unweighted, but a weighted
-- seed cell holds them weighted; chance, pieces and missRate come from the sums weighted by research.md R7 of part 3;
-- an item neither the seed nor
-- the own catch has needs NEW_ITEM_REPORTERS other contributions on the map (FR-014); players is a lower bound where
-- the seed cannot tell (specs/003-guild-group-sync/research.md R9).
function CatchDB.Query(mapID, cell, filter)
    if cacheVersion ~= P.version then
        wipe(cache)
        wipe(reportersCache)
        cacheVersion = P.version
    end
    local cacheKey = mapID .. "|" .. cell .. "|" .. FilterKey(filter)
    if cache[cacheKey] then
        return cache[cacheKey]
    end
    local ranges = Ranges(filter)
    local sources = Sources(filter.source, mapID, filter.water)
    local reportersKey = mapID .. "|" .. filter.source
    reportersCache[reportersKey] = reportersCache[reportersKey] or Reporters(sources, mapID)
    local rules = { mine = filter.source == "mine", reporters = reportersCache[reportersKey] }
    local spot = SumSpot(sources, mapID, ranges, cell)
    local view
    if RawCatches(spot) >= LITTLE_DATA then
        view = BuildView("spot", spot, rules)
        view.cell = cell
    else
        local map = SumMap(sources, mapID, ranges)
        view = BuildView(RawCatches(map) > 0 and "map" or "none", map, rules) -- "none": nothing caught at all
    end
    cache[cacheKey] = view
    return view
end

-- value of build(), cached until the map's stamp moves.
local function ByStamp(kind, mapID, filter, build)
    local key = kind .. "|" .. mapID .. "|" .. FilterKey(filter)
    local stamp = CatchDB.MapStamp(mapID)
    local entry = mapCache[key]
    if not (entry and entry.stamp == stamp) then
        entry = { stamp = stamp, value = build() }
        mapCache[key] = entry
    end
    return entry.value
end

local function MapRules(sources, mapID, filter)
    return { mine = filter.source == "mine", reporters = Reporters(sources, mapID) }
end

-- The whole map's view (Query's shape, scope "map" or "none" when nothing was caught), without the spot: the
-- catalog's zone rows and the tooltips (specs/005-catch-catalog/contracts/api.md).
function CatchDB.QueryMap(mapID, filter)
    return ByStamp("map", mapID, filter, function()
        local sources = Sources(filter.source, mapID, filter.water)
        local map = SumMap(sources, mapID, Ranges(filter))
        return BuildView(RawCatches(map) > 0 and "map" or "none", map, MapRules(sources, mapID, filter))
    end)
end

-- One spot view per cell of the map with catches under the filter, sorted by cell: the catalog's spot rows. Each
-- carries cell and, with positions, point.
function CatchDB.QueryCells(mapID, filter)
    return ByStamp("cells", mapID, filter, function()
        local sources, ranges = Sources(filter.source, mapID, filter.water), Ranges(filter)
        local rules, views = MapRules(sources, mapID, filter), {}
        for cell in pairs(MapCells(sources, mapID, ranges)) do
            local sum = SumSpot(sources, mapID, ranges, cell)
            if RawCatches(sum) > 0 then
                local view = BuildView("spot", sum, rules)
                view.cell = cell
                table.insert(views, view)
            end
        end
        table.sort(views, function(a, b) return a.cell < b.cell end)
        return views
    end)
end

-- The map IDs with any cell under the filter's source, sorted: the seed's, the own tables' and, with sharing on,
-- the other players'; for "mine" those of shared.mine.
function CatchDB.Maps(filter)
    local set, list = {}, {}
    local function Add(key)
        local mapID = KeyMapID(key)
        if mapID then
            set[mapID] = true
        end
    end
    if filter.source == "mine" then
        for key in pairs(ns.db.shared.mine) do
            Add(key)
        end
    else
        for prefix in pairs(SeedIndex(Seed().cells)) do
            Add(prefix)
        end
        for prefix in pairs(OwnIndex()) do
            Add(prefix)
        end
        if ns.Share.IsEnabled() then
            for prefix in pairs(Others().byPrefix) do
                Add(prefix)
            end
        end
    end
    for mapID in pairs(set) do
        table.insert(list, mapID)
    end
    table.sort(list)
    return list
end

-- True once any held cell has a pool part (research R5): the "Water" filter shows only then. A false answer is kept
-- until the stored data changes (SHARED_DATA_CHANGED); a pool catch sets it.

local function AnyPool(cells)
    for _, cell in pairs(type(cells) == "table" and cells or {}) do
        if type(cell) == "table" and type(cell.p) == "table" and (tonumber(cell.p.c) or 0) > 0 then
            return true
        end
    end
    return false
end

function CatchDB.HasPoolData()
    if P.poolData == nil then
        P.poolData = AnyPool(Seed().cells) or AnyPool(ns.db.shared.mine)
        for _, record in pairs(ns.db.shared.records) do
            for _, cells in pairs(type(record) == "table" and type(record.builds) == "table" and record.builds or {}) do
                P.poolData = P.poolData or AnyPool(cells)
            end
        end
    end
    return P.poolData
end

-- The seed's cell of a place key, or nil (the eviction order of Share.lua weighs records by it).
function CatchDB.SeedCell(key)
    local cell = Seed().cells[key]
    return type(cell) == "table" and cell or nil
end

function CatchDB.SeedInfo()
    return SeedEpoch(), CountKeys(Seed().cells)
end

-- False when the bundled seed is missing, malformed or has no places.
function CatchDB.HasSeed()
    return next(Seed().cells) ~= nil
end


-- Lines for /okf debug; never the anonymous ID (the report goes into public bug reports).
function CatchDB.Describe()
    local lines = {}
    table.insert(lines, ("seed epoch %d, %d places"):format(CatchDB.SeedInfo()))
    table.insert(lines, ("own places %d"):format(CountKeys(ns.db.shared.mine)))
    local mapID, range, cell = CatchDB.GetCurrentPlace()
    table.insert(lines, "current place " .. (mapID and CatchDB.PlaceKey(mapID, range, cell) or "none"))
    table.insert(lines, "last catch from a pool: " .. tostring(P.lastPool))
    table.insert(lines, "game version key " .. BuildKey())
    return lines
end

-- Shared with CatchDB/Events.lua through CatchDB.private.
P.IsOwnKey, P.IndexRecord, P.UnindexRecord = IsOwnKey, IndexRecord, UnindexRecord
