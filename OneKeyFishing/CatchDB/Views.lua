-- CatchDB/Views.lua: what the tabs, the catalog and the tooltips read: the sums of a place or a map over the
-- own tables, the seed and other players' records, with their weights (over the indexes of CatchDB/Index.lua); the
-- seed info; the Describe lines of the debug report.
local _, ns = ...
local CatchDB = ns.CatchDB
local P = CatchDB.private
local MAX_RANGE, SeedEpoch = CatchDB.MAX_RANGE, CatchDB.SeedEpoch
local CountKeys = ns.CountKeys -- Data.lua
local mapCache, MapRange, KeyMapID = P.mapCache, P.MapRange, P.KeyMapID
local BuildKey, Seed, SeedField = P.BuildKey, P.Seed, P.SeedField
local OlderBuild, OwnRecord = P.OlderBuild, P.OwnRecord
local SeedIndex, Frozen, OwnIndex = P.SeedIndex, P.Frozen, P.OwnIndex -- CatchDB/Index.lua
-- Other players' cells that count: all while sharing is on, the imported ones while it is off (spec 027).
local CountedOthers = P.CountedOthers
local SeedItems, OwnItems = P.SeedItems, P.OwnItems

---------------------------------------------------------------------------
-- Views
---------------------------------------------------------------------------
local LITTLE_DATA = 50 -- catches a scope needs before chances are shown
CatchDB.LITTLE_DATA = LITTLE_DATA -- also the exchange's "little data" (Share.lua)
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
-- t, tc: the cells' casting seconds and catches before the water and camp bonus filters (those parts keep no time),
-- for the catches per hour of the best places (spec 024 research R1). Another player's are kept in its part and
-- weighted by its catches before the filters (from WEIGHT_FROM contributions on), and its time (and a seed cell's)
-- counts at least MIN_CAST_SECONDS a cast,
-- so a record claiming a cast a second cannot set a place's pace (a real cast and bite take longer). A seed cell the
-- harvest weighted has its t scaled with its c (tools/harvest.mjs scaleCell, from the seed after epoch 9; epoch 9
-- scaled it by its casts' factor, a slightly slower pace), so its c, not its raw r, goes with it.
local MIN_CAST_SECONDS = 5
local function NewSum()
    return { c = 0, m = 0, x = 0, i = {}, a = {}, ids = {}, seedK = 0, seedUnweighted = 0, parts = {}, px = 0,
        py = 0, n = 0, ranges = {}, water = "all", bonus = "all", t = 0, tc = 0 }
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

-- AddCounts(target, cell, factor): CatchDB.lua; factor is the weight of the cell's counts (research.md R7 of part 3).
local AddCounts, PartMask = P.AddCounts, P.PartMask

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

-- The camp bonuses (specs/020-camp-buffs), in rank order: a later one is the higher bonus. What a bonus is (its bit,
-- its known items) is Camp's (Fishing/Camp.lua); a part's key is CatchDB.lua's (PartMask).
local BONUSES = ns.GameData.CampBonuses
local Camp = ns.Camp

-- The cell's bonus parts as a table, or nil.
local function Parts(cell)
    return type(cell.q) == "table" and cell.q or nil
end

-- a with the known bonus bits of b added: the union of two masks, without bits this version does not know.
local function OrMasks(a, b)
    for _, bonus in ipairs(BONUSES) do
        if Camp.HasBit(b, bonus.key) and not Camp.HasBit(a, bonus.key) then
            a = a + bonus.bit
        end
    end
    return a
end

-- The union of the masks of a cell's parts: the bonuses the cell holds data for.
local function PartsUnion(parts)
    local union = 0
    for key in pairs(parts) do
        local mask = PartMask(key)
        if mask then
            union = OrMasks(union, mask)
        end
    end
    return union
end

-- A cell read through the camp bonus filter (specs/020-camp-buffs, research R6, R15): a bonus key sums the parts
-- whose mask has its bit (a cast under both bonuses counts for both); "none" is the cell minus all its parts, each
-- cast once, a part of a mask this version does not know included. A key takes a seed cell's players (the largest k
-- of its parts), raw catches (r) and catches weighted by casts (x) from those parts; "none" keeps the cell's k and
-- drops r and x of a cell it reduces, as the water filter does. A cell without parts is all "none": it is read whole,
-- r and x included, so a place without bonus data shows the same numbers under "none" as under "all".
local function ThroughBonus(cell, bonus)
    local parts = Parts(cell)
    if bonus == "none" then
        if not parts then
            return cell -- read only
        end
        local out = { c = 0, m = 0, i = {}, k = cell.k, a = cell.a }
        AddCounts(out, cell)
        for _, part in pairs(parts) do
            if type(part) == "table" then
                AddCounts(out, part, -1)
            end
        end
        return out
    end
    local out = { c = 0, m = 0, i = {}, a = cell.a, r = 0, x = 0 }
    local k
    for key, part in pairs(parts or {}) do
        local mask = PartMask(key)
        if mask and type(part) == "table" and Camp.HasBit(mask, bonus) then
            AddCounts(out, part)
            local c = tonumber(part.c) or 0
            out.r, out.x = out.r + (tonumber(part.r) or c), out.x + (tonumber(part.x) or c)
            if tonumber(part.k) then
                k = math.max(k or 0, tonumber(part.k))
            end
        end
    end
    out.k = k or cell.k
    return out
end

-- Marks who holds an item: the seed (a flag), the own catch, or another record's ID.
local function MarkHolder(byItem, itemID, source)
    local holder = byItem[itemID] or {}
    byItem[itemID] = holder
    if source.seed then
        holder.seed = true
    elseif source.other then
        holder.ids = holder.ids or {}
        holder.ids[source.id] = true
    else
        holder.own = true
    end
end

-- Who holds each item under each bonus the sum asks about (research R7 of spec 020): holders[key][itemID], from the
-- raw cell's parts.
local function AddHolders(sum, parts, source)
    for partKey, part in pairs(parts) do
        local mask = PartMask(partKey)
        if mask and type(part) == "table" and type(part.i) == "table" then
            for key, byItem in pairs(sum.holders) do
                if Camp.HasBit(mask, key) then
                    for itemID, entry in pairs(part.i) do
                        if type(entry) == "table" and (tonumber(entry[1]) or 0) > 0 then
                            MarkHolder(byItem, itemID, source)
                        end
                    end
                end
            end
        end
    end
end

-- A scope's sum also gathers what its items' camp bonus tags need (BuildView, Tag), only what its filter reads: the
-- holders of the bonuses it may tag from the data (none under "none" or the source "mine"); under "all" one sub-sum
-- per bonus, under a key the unfiltered catches of each item.
local function StartTagSums(sum, mine)
    sum.tagged = true
    if sum.bonus ~= "none" and not mine then
        sum.holders = {}
        for _, bonus in ipairs(BONUSES) do
            if sum.bonus == "all" or sum.bonus == bonus.key then
                sum.holders[bonus.key] = {}
            end
        end
    end
    if sum.bonus == "all" then
        sum.subs = {}
    elseif sum.holders then
        sum.rawAll = {}
    end
end

-- range: the skill range of the cell's place key.
local function AddCell(sum, cell, source, range)
    if type(cell) ~= "table" then
        return
    end
    -- The camp bonus tag's sums, from the raw cell in the same pass (research R7 of spec 020).
    local parts = sum.tagged and Parts(cell)
    if parts then
        if sum.holders then
            AddHolders(sum, parts, source)
        end
        if sum.subs then
            local union = PartsUnion(parts)
            for _, bonus in ipairs(BONUSES) do
                if Camp.HasBit(union, bonus.key) then
                    local sub = sum.subs[bonus.key]
                    if not sub then
                        sub = NewSum()
                        sub.bonus = bonus.key
                        sum.subs[bonus.key] = sub
                    end
                    AddCell(sub, cell, source, range)
                end
            end
        end
    end
    if sum.rawAll and type(cell.i) == "table" then
        for itemID, entry in pairs(cell.i) do
            if type(entry) == "table" then
                sum.rawAll[itemID] = (sum.rawAll[itemID] or 0) + (tonumber(entry[1]) or 0)
            end
        end
    end
    local seconds, counted = tonumber(cell.t) or 0, tonumber(cell.c) or 0 -- before the water and bonus filters
    -- the seed too: a weighted cell's time may be pushed down to a second a cast; a cell without time keeps none
    if seconds > 0 and (source.other or source.seed) then
        seconds = math.max(seconds, MIN_CAST_SECONDS * (counted + (tonumber(cell.m) or 0)))
    end
    if tonumber(cell.px) and tonumber(cell.py) then
        sum.px, sum.py = sum.px + cell.px, sum.py + cell.py
        sum.n = sum.n + (tonumber(cell.c) or 0) + (tonumber(cell.m) or 0)
    end
    if sum.bonus ~= "all" then
        cell = ThroughBonus(cell, sum.bonus) -- the water filter does not combine with it (research R6)
    else
        cell = ThroughWater(cell, sum.water)
    end
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
            target = { c = 0, m = 0, x = 0, i = {}, a = {}, t = 0, tc = 0 }
            sum.parts[source.id] = target
        end
    end
    target.t, target.tc = target.t + seconds, target.tc + counted
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

-- What a source sums for a map. "all": the seed, the own record and, with sharing on, the other players'
-- records, each without its cells of game versions older than a reset of the map (after a patch that changed its
-- catch); "mine": the lifetime counts. A record's cells count for its ID in the player count. The filter's water
-- and camp bonus go along; a bonus filter other than "all" reads the water as "all" (research R6 of spec 020).
local function Sources(filter, mapID)
    local source, bonus = filter.source, filter.bonus or "all"
    local water = bonus == "all" and filter.water or "all"
    if source == "mine" then
        return { tables = { { cells = ns.db.shared.mine } }, water = water, bonus = bonus, mine = true }
    end
    local reset = SeedField("resets")[mapID]
    local own = OwnRecord()
    local sources = { seed = { cells = Seed().cells, seed = true }, tables = {}, reset = reset,
        others = CountedOthers(), water = water, bonus = bonus }
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
    sum.water, sum.bonus = sources.water, sources.bonus
    StartTagSums(sum, sources.mine)
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
    sum.water, sum.bonus = sources.water, sources.bonus
    StartTagSums(sum, sources.mine)
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

-- What counts as a report of an item: a catch of it in an entry of another player's record, of a game version not
-- older than the map's reset. Adds the entry's contribution ID to ids[itemID] (itemID -> { ID -> true }).
local function AddReports(ids, entry, reset)
    local cell = entry.cell
    if type(cell) == "table" and type(cell.i) == "table" and not (reset and OlderBuild(entry.build, reset)) then
        for itemID, counts in pairs(cell.i) do
            if type(counts) == "table" and (tonumber(counts[1]) or 0) > 0 then
                ids[itemID] = ids[itemID] or {}
                ids[itemID][entry.id] = true
            end
        end
    end
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
            AddReports(ids, entry, sources.reset)
        end
    end
    for itemID, set in pairs(ids) do
        reporters[itemID] = CountKeys(set)
    end
    return reporters
end

local BuildView -- defined below; Tag builds the bonuses' views of the same scope with it

-- Whether the seed, or at least NEW_ITEM_REPORTERS players (the own catch one of them), hold the item under the bonus.
-- Never under the source "mine" or "none": the sum gathered no holders there.
local function Holds(sum, key, itemID)
    local byItem = sum.holders and sum.holders[key]
    local holder = byItem and byItem[itemID]
    if not holder then
        return false
    end
    return holder.seed == true or (holder.own and 1 or 0) + CountKeys(holder.ids or {}) >= NEW_ITEM_REPORTERS
end

-- An item's bonus with the numbers of a view under that bonus (entry: the item in it), or, without an entry, a known
-- item that has no data under its bonus.
local function BonusNumbers(key, entry, view)
    if not entry then
        return { key = key, littleData = true, catches = 0, players = 0 }
    end
    return { key = key, chance = entry.chance, littleData = view.littleData, catches = view.catches,
        players = view.players }
end

local function Contains(list, value)
    for _, entry in ipairs(list) do
        if entry == value then
            return true
        end
    end
    return false
end

local function ItemsByID(view)
    local byID = {}
    for _, item in ipairs(view and view.items or {}) do
        byID[item.itemID] = item
    end
    return byID
end

-- The camp bonus tag of a view's items (data-model.md "A view item's bonus", research R7 of spec 020), from the sums
-- gathered in the same pass over the same scope: no other view is fetched. A known item carries its key in every
-- view; an item is tagged from the data when every raw catch of it in the scope lies under the bonus and the seed or
-- three players hold it so; the higher-ranked bonus wins in an "all" view. Untagged items keep their numbers.
local function Tag(view, sum, rules, scope)
    local bonus = sum.bonus
    if bonus == "all" then
        -- A bonus's view of the same scope, built only when an item asks for it.
        local subViews, subItems = {}, {}
        local function Sub(key)
            if subItems[key] == nil then
                subViews[key] = sum.subs[key] and BuildView(scope, sum.subs[key], rules)
                subItems[key] = ItemsByID(subViews[key])
            end
            return subViews[key], subItems[key]
        end
        for _, item in ipairs(view.items) do
            local known = Camp.KnownBonuses(item.itemID)
            if known then
                -- Of the bonuses that give it, the one under which it has the most catches here; without any, the
                -- lowest-ranked (the cheapest to get it with: decision 32).
                local best, bestView, bestEntry = known[1], nil, nil
                for _, key in ipairs(known) do
                    local subView, items = Sub(key)
                    local entry = items[item.itemID]
                    if entry and (not bestEntry or entry.catches > bestEntry.catches) then
                        best, bestView, bestEntry = key, subView, entry
                    end
                end
                item.bonus = BonusNumbers(best, bestEntry, bestView)
                item.bonus.several = #known > 1 or nil
            else
                for i = #BONUSES, 1, -1 do
                    local key = BONUSES[i].key
                    if Holds(sum, key, item.itemID) then
                        local subView, items = Sub(key)
                        local entry = items[item.itemID]
                        if entry and entry.catches == item.catches then
                            item.bonus = BonusNumbers(key, entry, subView)
                            break
                        end
                    end
                end
            end
        end
        return
    end
    for _, item in ipairs(view.items) do
        local known = Camp.KnownBonuses(item.itemID)
        local several = known and #known > 1 or nil
        if known and Contains(known, bonus) then
            item.bonus = BonusNumbers(bonus, item, view)
            item.bonus.several = several
        elseif known then
            item.bonus = { key = known[1], plain = true, several = several }
        elseif sum.rawAll and item.catches == (sum.rawAll[item.itemID] or 0) and Holds(sum, bonus, item.itemID) then
            item.bonus = BonusNumbers(bonus, item, view)
        end
    end
end

-- The miss rate's numbers of a sum: its misses and casts weighted by casts (research.md R7 of part 3), and its raw
-- casts (the threshold of spec 021's missLittleData: real catches and misses, every player's part).
local function MissNumbers(sum)
    local castFactors = WeightFactors(sum, Players(sum), Casts)
    local misses, casts, rawMisses = sum.m, Casts(sum), sum.m
    for id, part in pairs(sum.parts) do
        local factor = castFactors[id] or 1
        misses, casts = misses + part.m * factor, casts + Casts(part) * factor
        rawMisses = rawMisses + part.m
    end
    return misses, casts, RawCatches(sum) + rawMisses
end

-- rules: { mine = source "mine" (every item shown), reporters = Reporters(...) }. missSum: the sum the miss rate comes
-- from (the chosen skill range alone, spec 021 research R3); without it the view has no miss rate (the catalog's).
function BuildView(scope, sum, rules, missSum)
    local players = Players(sum)
    local factors, castFactors = WeightFactors(sum, players, Catches), WeightFactors(sum, players, Casts)
    local weighted, raw = { c = 0, m = 0, i = {} }, { c = 0, m = 0, i = {} }
    AddCounts(weighted, sum)
    AddCounts(raw, sum)
    for id, part in pairs(sum.parts) do
        AddCounts(weighted, part, factors[id])
        AddCounts(raw, part)
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
    -- Another player caught something here: an ID with catches that has a part (only other players' records do).
    local others = false
    for id in pairs(sum.ids) do
        others = others or sum.parts[id] ~= nil
    end
    local catches = RawCatches(sum)
    -- The pace's weights come from the catches before the water and bonus filters, as its time does: a record with
    -- no catch under a filter is capped all the same.
    local timeFactors = WeightFactors(sum, players, function(part) return part.tc end)
    local seconds, counted = sum.t, sum.tc
    for id, part in pairs(sum.parts) do
        local factor = timeFactors[id] or 1
        seconds, counted = seconds + part.t * factor, counted + part.tc * factor
    end
    local view = { scope = scope, area = area, littleData = catches < LITTLE_DATA, catches = catches,
        misses = raw.m, items = items, players = players, others = others,
        point = sum.n > 0 and { x = sum.px / sum.n / 1000, y = sum.py / sum.n / 1000 } or nil,
        seconds = seconds, catchesPerHour = seconds > 0 and 3600 * counted / seconds or nil }
    -- No miss rate under a water filter: a miss has no loot source (FR-022). A camp bonus part has its misses, so the
    -- miss rate stays under a bonus filter (spec 020): missSum passed the same filter.
    if missSum and (sum.water or "all") == "all" then
        local misses, casts, rawCasts = MissNumbers(missSum)
        view.missRate = casts > 0 and misses / casts or 0
        view.missLittleData = rawCasts < LITTLE_DATA
    end
    if sum.tagged then
        Tag(view, sum, rules, scope)
    end
    return view
end

-- The ranges a filter sums: a range r sums every range from 0 to r, since more skill never undoes what less skill
-- catches; "all" (and a stray MAX_RANGE) every range (specs/021-cumulative-skill-filter, research R1 and R2).
local UP_TO = {}
for range = 0, MAX_RANGE - 1 do
    UP_TO[range] = {}
    for lower = 0, range do
        UP_TO[range][lower + 1] = lower
    end
end

local function Ranges(filter)
    return UP_TO[filter.range] or CatchDB.RANGES
end

-- The one range the miss rate comes from: the chosen range itself, 300+ for "all" (spec 021 research R3): lower skill
-- misses more, so a summed miss rate would show a skilled player the misses of beginners.
local function MissRange(filter)
    return UP_TO[filter.range] and filter.range or MAX_RANGE
end

-- "<range>|<source>|<water>|<bonus>": a filter as the view caches (and the catalog, Catalog.lua) key it; a missing
-- water or bonus reads as "all".
function CatchDB.FilterKey(filter)
    return tostring(filter.range) .. "|" .. filter.source .. "|" .. (filter.water or "all") .. "|"
        .. (filter.bonus or "all")
end

-- The camp bonus keys in rank order, for the menus (spec 020).
function CatchDB.BonusKeys()
    local keys = {}
    for i, bonus in ipairs(BONUSES) do
        keys[i] = bonus.key
    end
    return keys
end
local FilterKey = CatchDB.FilterKey

local cache, cacheVersion = {}, nil
local reportersCache = {} -- "<mapID>|<source>" -> Reporters(...): the map's, whatever the spot or range

-- What a place gives (contracts/catchdb-api.md): the spot, or the whole map when the spot has fewer than
-- LITTLE_DATA catches. filter = { range = 0..3 or "all", source = "all" or "mine" }; a range sums the ranges 0 to it
-- (spec 021). A view is
-- { scope = "spot" | "map" | "none", littleData, catches, misses, missRate, players, others (another player's catch
-- is in the sum),
-- items = { { itemID, catches, chance, pieces, reporters, inSeed } } }: catches is the real sum (a seed cell the
-- harvest weighted gives its raw catches, r); misses and the items' catches are summed unweighted, but a weighted
-- seed cell holds them weighted; chance, pieces and missRate come from the sums weighted by research.md R7 of part 3;
-- missRate and missLittleData (fewer than LITTLE_DATA casts) come from the chosen range alone at the view's scope
-- (300+ for "all"; spec 021), and only Query's views carry them, not QueryMap's or QueryCells'; an item neither the
-- seed nor
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
    local sources = Sources(filter, mapID)
    local reportersKey = mapID .. "|" .. filter.source
    reportersCache[reportersKey] = reportersCache[reportersKey] or Reporters(sources, mapID)
    local rules = { mine = filter.source == "mine", reporters = reportersCache[reportersKey] }
    -- The miss rate's sum: the chosen range alone at the scope of the list (spec 021 research R3); range 0 is the
    -- list's own sum.
    local missRange = MissRange(filter)
    local spot = SumSpot(sources, mapID, ranges, cell)
    local view
    if RawCatches(spot) >= LITTLE_DATA then
        local missSum = missRange == 0 and spot or SumSpot(sources, mapID, { missRange }, cell)
        view = BuildView("spot", spot, rules, missSum)
        view.cell = cell
    else
        local map = SumMap(sources, mapID, ranges)
        local missSum = missRange == 0 and map or SumMap(sources, mapID, { missRange })
        view = BuildView(RawCatches(map) > 0 and "map" or "none", map, rules, missSum) -- "none": nothing caught
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
        local sources = Sources(filter, mapID)
        local map = SumMap(sources, mapID, Ranges(filter))
        return BuildView(RawCatches(map) > 0 and "map" or "none", map, MapRules(sources, mapID, filter))
    end)
end

-- One spot view per cell of the map with catches under the filter, sorted by cell: the catalog's spot rows. Each
-- carries cell and, with positions, point.
function CatchDB.QueryCells(mapID, filter)
    return ByStamp("cells", mapID, filter, function()
        local sources, ranges = Sources(filter, mapID), Ranges(filter)
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
        for prefix in pairs(CountedOthers().byPrefix) do
            Add(prefix)
        end
    end
    for mapID in pairs(set) do
        table.insert(list, mapID)
    end
    table.sort(list)
    return list
end

-- Calls fn(cells) for every held cell table until it returns true: the seed, the own counts and every record's builds
-- (with sharingOnly, other players' records only while sharing is on or when imported, spec 027: the views read them
-- only then; the own records, the live one and those a roll kept, always).
local function EachHeldCells(fn, sharingOnly)
    if fn(Seed().cells) or fn(ns.db.shared.mine) then
        return
    end
    local myID, sharing = ns.db.shared.myID, ns.Share.IsEnabled()
    for unit, record in pairs(ns.db.shared.records) do
        if (sharing or not sharingOnly or unit == myID or P.IsOwnKey(unit) or ns.Share.IsImported(unit))
            and type(record) == "table"
            and type(record.builds) == "table" then
            for _, cells in pairs(record.builds) do
                if fn(cells) then
                    return
                end
            end
        end
    end
end

-- True once any held cell has a pool part (research R5): the "Water" filter shows only then. A false answer is kept
-- until the stored data changes (SHARED_DATA_CHANGED). No own catch writes one since spec 011 (the source is not
-- known); only data from older builds can have it.
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
        P.poolData = false
        EachHeldCells(function(cells)
            P.poolData = AnyPool(cells)
            return P.poolData
        end)
    end
    return P.poolData
end

-- True once a held cell has a camp bonus part of the bonus `key` (any bonus without one; specs/020-camp-buffs,
-- FR-024): the seed, the own counts, the own records and, while sharing is on or when imported, other players'
-- records; a part of a bit
-- this version does not know counts for nothing. The "Camp bonus" button shows only then. P.bonusData keeps the union
-- of every held part's mask; dropped at ADDON_LOADED, on every SHARED_DATA_CHANGED (a record with the only part may
-- leave: FR-027) and when the own catch makes a new part (CatchDB.lua).
function CatchDB.HasBonusData(key)
    if P.bonusData == nil then
        -- The walk stops once every known bonus has a part (it helps only once both have data); the answer is
        -- recomputed after every data change.
        local bits, every = 0, 0
        for _, bonus in ipairs(BONUSES) do
            every = every + bonus.bit
        end
        EachHeldCells(function(cells)
            for _, cell in pairs(type(cells) == "table" and cells or {}) do
                local parts = type(cell) == "table" and Parts(cell)
                if parts then
                    bits = OrMasks(bits, PartsUnion(parts))
                    if bits == every then
                        return true
                    end
                end
            end
        end, true)
        P.bonusData = bits
    end
    if key == nil then
        return P.bonusData > 0
    end
    return Camp.HasBit(P.bonusData, key)
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

-- The own counts of each camp bonus part of a place (spec 020, FR-038), English, for the debug report: "bonus parts
-- here: 1 = 12 catches / 3 misses, 3 = ..." by mask, or "none".
function CatchDB.DescribeBonusParts(placeKey)
    local cell = placeKey and ns.db.shared.mine[placeKey]
    local parts = type(cell) == "table" and Parts(cell)
    local keys = {}
    for key in pairs(parts or {}) do
        table.insert(keys, key)
    end
    table.sort(keys, function(a, b) return (tonumber(a) or 0) < (tonumber(b) or 0) end)
    local texts = {}
    for _, key in ipairs(keys) do
        local part = parts[key]
        table.insert(texts, ("%s = %d catches / %d misses"):format(key, math.floor(tonumber(part.c) or 0),
            math.floor(tonumber(part.m) or 0)))
    end
    return "bonus parts here: " .. (#texts > 0 and table.concat(texts, ", ") or "none")
end

-- Lines for /okf debug; never the anonymous ID (the report goes into public bug reports).
function CatchDB.Describe()
    local lines = {}
    table.insert(lines, ("seed epoch %d, %d places"):format(CatchDB.SeedInfo()))
    table.insert(lines, ("own places %d"):format(CountKeys(ns.db.shared.mine)))
    local mapID, range, cell = CatchDB.GetCurrentPlace()
    local placeKey = mapID and CatchDB.PlaceKey(mapID, range, cell)
    table.insert(lines, "current place " .. (placeKey or "none"))
    table.insert(lines, CatchDB.DescribeBonusParts(placeKey))
    table.insert(lines, "game version key " .. BuildKey())
    return lines
end

-- The items the auction scan searches beyond the own catches (Catch/Auction.lua, specs/018-auction-scan): the
-- bundled database's items and the items of other players' counted records (CountedOthers) that the catalog
-- shows: one the own catch has, or one NEW_ITEM_REPORTERS other contributions report on one map (FR-014), so a
-- single forged record cannot add an item. A report counts as in Reporters (AddReports). Two sets itemID -> true;
-- the first is the seed's own table: callers never write.
function CatchDB.ScanItems()
    local others = {}
    do
        local own, byMap = OwnItems(), {} -- byMap: mapID -> itemID -> { record ID -> true }
        local resets = SeedField("resets")
        for _, entries in pairs(CountedOthers().byRecord) do
            for _, entry in ipairs(entries) do
                byMap[entry.mapID] = byMap[entry.mapID] or {}
                AddReports(byMap[entry.mapID], entry, resets[entry.mapID])
            end
        end
        for _, items in pairs(byMap) do
            for itemID, ids in pairs(items) do
                if own[itemID] or CountKeys(ids) >= NEW_ITEM_REPORTERS then
                    others[itemID] = true
                end
            end
        end
    end
    return SeedItems(), others
end

ns.Auction.SetItemSource(CatchDB.ScanItems)
