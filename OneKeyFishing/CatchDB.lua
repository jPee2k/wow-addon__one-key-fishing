-- CatchDB: what is caught where, account-wide, for the "What can be caught here" tab and the bundled seed
-- (SeedData.lua, written by npm run harvest). A place is "<mapID>:<skill range>:<cell>", numbers only, so
-- clients in every language agree. Every catch and miss in fishing mode goes into two tables of the same cell
-- shape: shared.mine (this account's catches, never reset) and the account's contribution record (what the
-- harvest reads; split by game version). See specs/002-local-catch-db/data-model.md.
local _, ns = ...

local CatchDB = {}
ns.CatchDB = CatchDB

local GRID = 10 -- cells per map side
local RANGE_STEP = 75 -- skill points per range
local MAX_RANGE = 4 -- 300 and above
local MAX_PIECES = 20 -- pieces counted per catch and item, against bogus quantities
local SEQ_INTERVAL = 60 -- seconds between bumps of the record's seq
-- Places of the own record before a new one rolls it (Roll below): a peer takes a record of up to 1,000 places and
-- 32 KB encoded. Measured with CBOR + Deflate + Base64 in Node: 34-47 bytes per place, so 500 places stay under
-- 24 KB even with hundreds of catches per cell.
-- VERIFY(V18): C_EncodingUtil encodes an own record of ROLL_PLACES busy places in at most 24 KB
local ROLL_PLACES = 500
local ID_LENGTH = 8 -- base32 characters (Data.lua)
CatchDB.ID_LENGTH = ID_LENGTH

-- The skill ranges, for the UI: range r is RANGE_STEP * r points of base rank and up; MAX_RANGE has no top.
CatchDB.RANGE_STEP, CatchDB.MAX_RANGE, CatchDB.RANGES = RANGE_STEP, MAX_RANGE, {}
for range = 0, MAX_RANGE do
    CatchDB.RANGES[range + 1] = range
end

local version = 0
local casts = {} -- cast ID (Catch.lua) -> { key, x, y, start, stop } until its catch or miss settles it
local lastSeqBump -- GetTime() of the last seq bump
local seqWaiting = false -- a change since the last bump

function CatchDB.GetVersion()
    return version
end

---------------------------------------------------------------------------
-- Places
---------------------------------------------------------------------------
function CatchDB.PlaceKey(mapID, range, cell)
    return mapID .. ":" .. range .. ":" .. cell
end

-- "<mapID>:<range>", the part of a place key the whole-map sums group by.
local function MapRange(mapID, range)
    return mapID .. ":" .. range
end

local function KeyMapRange(key)
    return type(key) == "string" and key:match("^(%d+:%d):")
end

local function Digit(value)
    return math.max(0, math.min(GRID - 1, math.floor(value * GRID)))
end

-- cell, x, y of the player on map mapID (x, y in 0..1); "x" without a position.
function CatchDB.GetCell(mapID)
    -- VERIFY(V1): a position while fishing in the open world and in cities, nil in instances
    local position = C_Map.GetPlayerMapPosition(mapID, "player")
    local x, y
    if position then
        x, y = position:GetXY()
    end
    if not (x and y) then
        return "x"
    end
    -- At a map's edge the position can be a little outside 0..1; the cell and the position sums stay inside.
    x, y = math.max(0, math.min(1, x)), math.max(0, math.min(1, y))
    return Digit(x) .. Digit(y), x, y
end

-- mapID, range, cell, x, y of the player now (cell "x" and no x, y without a position), or nil without Fishing
-- or a map.
function CatchDB.GetCurrentPlace()
    local rank = ns.Skill.Get()
    -- VERIFY(V2): the map the game reports for the player is a stable place per fishing spot
    local mapID = C_Map.GetBestMapForUnit("player")
    if not (rank and mapID) then
        return nil
    end
    return mapID, math.min(MAX_RANGE, math.floor(rank / RANGE_STEP)), CatchDB.GetCell(mapID)
end

-- The game version the data is recorded under.
local function BuildKey()
    -- VERIFY(V7): GetBuildInfo returns the version as "1.60.1"-style text
    local build = GetBuildInfo()
    if type(build) ~= "string" or build == "" then
        return "unknown"
    end
    return build
end

---------------------------------------------------------------------------
-- Records
---------------------------------------------------------------------------
-- The bundled seed (SeedData.lua) as read at runtime; a missing or malformed one counts as empty.
local EMPTY_SEED = { epoch = 0, absorbed = {}, resets = {}, cells = {} }

local function Seed()
    local seed = ns.SeedData
    if type(seed) == "table" and type(seed.cells) == "table" then
        return seed
    end
    return EMPTY_SEED
end

local function SeedField(name)
    local value = Seed()[name]
    return type(value) == "table" and value or EMPTY_SEED[name]
end

local function SeedEpoch()
    local epoch = Seed().epoch
    return type(epoch) == "number" and epoch or 0
end
CatchDB.SeedEpoch = SeedEpoch

-- ID -> { [epoch] = seq }: every unit "<id>@<epoch>" the seed holds, and up to which seq.
function CatchDB.SeedAbsorbed()
    return SeedField("absorbed")
end

-- The seq up to which the seed holds unit <id>@<epoch>, or nil when it holds none of it. absorbed: the seed's
-- table by default.
function CatchDB.AbsorbedSeq(id, epoch, absorbed)
    local epochs = (absorbed or SeedField("absorbed"))[id]
    local seq = type(epochs) == "table" and epochs[epoch]
    return type(seq) == "number" and seq or nil
end

-- True when the seed holds this version of the unit whole: next to the seed it would count twice. A newer seq of
-- a unit the seed holds is held only in part: it is kept and passed on, so the next harvest gets the rest, but not
-- counted, since the seed already has its first part.
function CatchDB.IsAbsorbed(id, epoch, seq, absorbed)
    local held = CatchDB.AbsorbedSeq(id, epoch, absorbed)
    return held ~= nil and seq <= held
end

-- Other players' records are kept under "<id>@<epoch>" (Share.lua), the own one under its ID.
function CatchDB.UnitKey(id, epoch)
    return ("%s@%d"):format(id, epoch)
end

-- The ID and the epoch of a "<id>@<epoch>" key (nil for anything else).
function CatchDB.ParseUnit(unit)
    local id, epoch = unit:match("^(%w+)@(%d+)$")
    return id, tonumber(epoch)
end

function CatchDB.IsOtherKey(key)
    return type(key) == "string" and key:find("@", 1, true) ~= nil
end

-- A game version key as records store it ("1.60.1"); the own record's "unknown" is not one.
function CatchDB.IsBuild(build)
    return type(build) == "string" and build:find("^%d+%.%d+%.%d+$") ~= nil
end

local function CountKeys(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

-- True when game version `build` ("1.60.1") is older than `than`; "unknown" (the game gave no version) is older
-- than any version, so a reset of a map leaves it out as the harvest does; false for anything else.
local function OlderBuild(build, than)
    if build == "unknown" then
        return true
    end
    local a = { tostring(build):match("^(%d+)%.(%d+)%.(%d+)$") }
    local b = { tostring(than):match("^(%d+)%.(%d+)%.(%d+)$") }
    if #a < 3 or #b < 3 then
        return false
    end
    for i = 1, 3 do
        local x, y = tonumber(a[i]), tonumber(b[i])
        if x ~= y then
            return x < y
        end
    end
    return false
end

local function OwnRecord()
    local shared = ns.db.shared
    return shared.records[shared.myID]
end

local function BumpSeq()
    OwnRecord().seq = OwnRecord().seq + 1
    lastSeqBump, seqWaiting = GetTime(), false
end

-- True when a record has at least one cell (an empty one is neither kept on a roll nor offered to peers).
function CatchDB.HasCells(record)
    if type(record.builds) ~= "table" then
        return false
    end
    for _, cells in pairs(record.builds) do
        if type(cells) == "table" and next(cells) ~= nil then
            return true
        end
    end
    return false
end

-- The epoch of a new own record: the seed's, and above every epoch of the own ID held, so each unit of the own ID
-- is new (a record may roll more than once between two seeds).
local function NextEpoch(shared)
    local epoch = SeedEpoch()
    for _, record in pairs(shared.records) do
        if type(record) == "table" and record.id == shared.myID and type(record.epoch) == "number" then
            epoch = math.max(epoch, record.epoch + 1)
        end
    end
    return epoch
end

-- Starts a new own record (contracts: data-model.md "Rolling the own record"). The old one, with a seq for all its
-- cells, stays under "<myID>@<epoch>": it never changes again, goes to peers like other players' records and
-- reaches the seed through the author's harvest. Not kept when it is empty or the seed holds it whole. Returns the
-- key it is kept under, or nil.
local function Roll()
    local shared = ns.db.shared
    local old, key = OwnRecord(), nil
    if old and seqWaiting then
        BumpSeq()
    end
    if old and CatchDB.HasCells(old) and not CatchDB.IsAbsorbed(shared.myID, old.epoch, old.seq) then
        key = CatchDB.UnitKey(shared.myID, old.epoch)
        old.seen = time()
        shared.records[key] = old
    end
    shared.records[shared.myID] = { id = shared.myID, epoch = NextEpoch(shared), seq = 0, builds = {} }
    return key
end

-- Bumps a seq change that waits for its minute (at logout, and before the record goes to a peer, so it has a
-- seq for all its cells).
function CatchDB.FlushSeq()
    if seqWaiting and ns.db and OwnRecord() then
        BumpSeq()
    end
end

local function Changed()
    version = version + 1
    seqWaiting = true
    if not lastSeqBump or GetTime() - lastSeqBump >= SEQ_INTERVAL then
        BumpSeq()
    end
end

local function Cell(cells, key)
    local cell = cells[key]
    if not cell then
        cell = { c = 0, m = 0, t = 0, i = {} }
        cells[key] = cell
    end
    return cell
end

local function HasPlace(record, key)
    for _, cells in pairs(record.builds) do
        if type(cells) == "table" and cells[key] then
            return true
        end
    end
    return false
end

-- The cells a change goes into: mine and the own record under the current game version. A place new to an own
-- record of ROLL_PLACES places rolls the record first.
local function TargetCells(key)
    local own = OwnRecord()
    if not HasPlace(own, key) and CatchDB.CountPlaces(own, ROLL_PLACES) >= ROLL_PLACES then
        local kept = Roll()
        if kept then
            ns.Fire("SHARED_DATA_CHANGED", { kept })
        end
    end
    local builds = OwnRecord().builds
    local build = BuildKey()
    builds[build] = builds[build] or {}
    return { Cell(ns.db.shared.mine, key), Cell(builds[build], key) }
end

-- Item ID -> pieces of one catch, each capped at MAX_PIECES.
local function CatchItems(items)
    local pieces = {}
    for _, item in ipairs(items) do
        local itemID = C_Item.GetItemInfoInstant(item.link)
        if itemID then
            pieces[itemID] = math.min(MAX_PIECES, (pieces[itemID] or 0) + math.max(1, item.quantity or 1))
        end
    end
    return pieces
end

local function AddItems(target, pieces)
    for itemID, count in pairs(pieces) do
        local entry = target.i[itemID]
        if not entry then
            entry = { 0, 0 }
            target.i[itemID] = entry
        end
        entry[1] = entry[1] + 1
        entry[2] = entry[2] + count
    end
end

-- Adds a settled cast (caught: item ID -> pieces, or nil for a miss) to both tables.
local function Settle(cast, caught, fromPool)
    local seconds = math.max(1, math.floor((cast.stop or GetTime()) - cast.start + 0.5))
    for _, cell in ipairs(TargetCells(cast.key)) do
        cell.t = cell.t + seconds
        if cast.x then
            cell.px = (cell.px or 0) + math.floor(cast.x * 1000 + 0.5)
            cell.py = (cell.py or 0) + math.floor(cast.y * 1000 + 0.5)
        end
        if caught then
            cell.c = cell.c + 1
            AddItems(cell, caught)
            if fromPool then
                cell.p = cell.p or { c = 0, i = {} } -- catches only: a miss has no loot source
                cell.p.c = cell.p.c + 1
                AddItems(cell.p, caught)
            end
        else
            cell.m = cell.m + 1
        end
    end
    Changed()
end

---------------------------------------------------------------------------
-- Checking other players' records
---------------------------------------------------------------------------
local MAX_RECORD_PLACES = 1000 -- distinct places of one received record
local MAX_COUNT = 1e12 -- any count above this is garbage (and keeps math.huge out)

local function IsCount(value)
    return type(value) == "number" and value >= 0 and value <= MAX_COUNT and value == math.floor(value)
end
CatchDB.IsCount = IsCount

-- Distinct places over all builds of a record (a place fished before and after a patch is one), as
-- CheckRecord and the harvest count them: the unit of the place limits. limit (optional): counting stops above
-- it, so a huge record costs no more than limit + 1 places.
function CatchDB.CountPlaces(record, limit)
    local seen, count = {}, 0
    if type(record) == "table" and type(record.builds) == "table" then
        -- One game version (almost every record): no place can repeat, so no set is needed.
        local multi = next(record.builds, (next(record.builds))) ~= nil
        for _, cells in pairs(record.builds) do
            if type(cells) == "table" then
                for key in pairs(cells) do
                    if not (multi and seen[key]) then
                        seen[key], count = multi or nil, count + 1
                        if limit and count > limit then
                            return count
                        end
                    end
                end
            end
        end
    end
    return count
end

-- known: item IDs already found in the game during this check (the same fish repeat in every cell).
local function CheckItems(items, catches, known)
    if items == nil then
        return true
    end
    if type(items) ~= "table" then
        return false, "items are not a table"
    end
    for itemID, entry in pairs(items) do
        if not (IsCount(itemID) and itemID > 0) then
            return false, "item ID " .. tostring(itemID) .. " is not a positive number"
        end
        local withItem, pieces = type(entry) == "table" and entry[1], type(entry) == "table" and entry[2]
        if not (IsCount(withItem) and IsCount(pieces)) or withItem > catches or pieces < withItem
            or pieces > MAX_PIECES * withItem then
            return false, "item " .. itemID .. " has impossible counts"
        end
        if known[itemID] == nil then
            known[itemID] = C_Item.GetItemInfoInstant(itemID) ~= nil
        end
        if not known[itemID] then
            known.unknownItem = known.unknownItem or itemID -- noted; the rest is still checked
        end
    end
    return true
end

local function CheckCell(cell, known)
    if type(cell) ~= "table" or not (IsCount(cell.c) and IsCount(cell.m) and IsCount(cell.t)) then
        return false, "not a cell"
    end
    local casts = cell.c + cell.m
    if casts > cell.t then
        return false, "more casts than seconds of casting"
    end
    if (cell.px == nil) ~= (cell.py == nil) then
        return false, "px and py come together"
    end
    for _, name in ipairs({ "px", "py" }) do
        if cell[name] ~= nil and not (IsCount(cell[name]) and cell[name] <= 1000 * casts) then
            return false, name .. " is out of range"
        end
    end
    local ok, reason = CheckItems(cell.i, cell.c, known)
    if not ok then
        return false, reason
    end
    if cell.p ~= nil then
        if type(cell.p) ~= "table" or not IsCount(cell.p.c) or cell.p.c > cell.c then
            return false, "the pool part does not fit the totals"
        end
        return CheckItems(cell.p.i, cell.p.c, known)
    end
    return true
end

-- True, or false and the reason, for a record received from another player (the store refuses the own ID); a
-- third value true when the only fault is an item this client does not know (it may be new).
-- Mirrors checkRecord / checkCell in tools/harvest.mjs, so what a client accepts the next seed accepts too, but
-- rejects the whole record on any bad cell: a peer's data is refused, not cleaned up. No side effects.
function CatchDB.CheckRecord(record)
    if type(record) ~= "table" then
        return false, "not a table"
    end
    local id = record.id
    if type(id) ~= "string" or #id ~= ID_LENGTH or not id:find("^[a-z2-7]+$") then
        return false, "the ID is not 8 base32 characters"
    end
    if not (IsCount(record.epoch) and IsCount(record.seq)) then
        return false, "epoch or seq is not a count"
    end
    if type(record.builds) ~= "table" then
        return false, "no builds"
    end
    if CatchDB.CountPlaces(record, MAX_RECORD_PLACES) > MAX_RECORD_PLACES then
        return false, "more than " .. MAX_RECORD_PLACES .. " places"
    end
    local known, casts = {}, 0
    for build, cells in pairs(record.builds) do
        if not CatchDB.IsBuild(build) or type(cells) ~= "table" then
            return false, "build " .. tostring(build) .. " is not a game version"
        end
        for key, cell in pairs(cells) do
            if type(key) ~= "string" or not (key:find("^%d+:[0-4]:%d%d$") or key:find("^%d+:[0-4]:x$")) then
                return false, "place key " .. tostring(key) .. " is not <mapID>:<range>:<cell>"
            end
            local ok, reason = CheckCell(cell, known)
            if not ok then
                return false, key .. ": " .. reason
            end
            casts = casts + cell.c + cell.m
        end
    end
    -- The seq grows only after a settled cast, so it is never above the casts; a higher one is made up (it would
    -- make the owner's real updates look older everywhere).
    if record.seq > casts then
        return false, "seq " .. record.seq .. " is above the record's " .. casts .. " casts"
    end
    if known.unknownItem then
        return false, "item " .. known.unknownItem .. " is unknown to the game", true
    end
    return true
end

---------------------------------------------------------------------------
-- Views
---------------------------------------------------------------------------
local LITTLE_DATA = 50 -- catches a scope needs before chances are shown

-- A sum also tallies who it comes from: the IDs of the records with a summed cell and the seed's largest k.
local function NewSum()
    return { c = 0, m = 0, i = {}, ids = {}, seedK = 0 }
end

local function AddCell(sum, cell, source)
    if type(cell) ~= "table" then
        return
    end
    -- Who caught something here: a cell of misses only adds no player.
    if (tonumber(cell.c) or 0) > 0 then
        if source.seed then
            sum.seedK = math.max(sum.seedK, tonumber(cell.k) or 0)
        elseif source.id then
            sum.ids[source.id] = true
        end
    end
    sum.c = sum.c + (tonumber(cell.c) or 0)
    sum.m = sum.m + (tonumber(cell.m) or 0)
    if type(cell.i) == "table" then
        for itemID, entry in pairs(cell.i) do
            if type(entry) == "table" then
                local total = sum.i[itemID] or { 0, 0 }
                total[1] = total[1] + (tonumber(entry[1]) or 0)
                total[2] = total[2] + (tonumber(entry[2]) or 0)
                sum.i[itemID] = total
            end
        end
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
local others -- { byKey = { place -> { entry -> true } }, byPrefix = { prefix -> { entry -> true } }, byRecord }

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
                local entry = { cell = cell, id = record.id, build = build, place = place, prefix = prefix }
                AddToSet(others.byKey, place, entry)
                AddToSet(others.byPrefix, prefix, entry)
                table.insert(entries, entry)
            end
        end
    end
    others.byRecord[key] = entries
end

local function UnindexRecord(key)
    for _, entry in ipairs(others.byRecord[key] or {}) do
        others.byKey[entry.place][entry] = nil
        others.byPrefix[entry.prefix][entry] = nil
    end
    others.byRecord[key] = nil
end

-- The own records frozen by a roll that the seed does not hold yet: they count like the live one.
local frozen

local function Frozen()
    if not frozen then
        frozen = {}
        for key, record in pairs(ns.db.shared.records) do
            if CountedUnit(key, record) == "own" then
                table.insert(frozen, record)
            end
        end
    end
    return frozen
end

local function Others()
    if not others then
        others = { byKey = {}, byPrefix = {}, byRecord = {} }
        for key in pairs(ns.db.shared.records) do
            IndexRecord(key)
        end
    end
    return others
end

-- What a source sums for a map. "all": the seed, the own record and, with sharing on, the other players'
-- records, each without its cells of game versions older than a reset of the map (after a patch that changed its
-- catch); "mine": the lifetime counts. A record's cells count for its ID in the player count.
local function Sources(source, mapID)
    if source == "mine" then
        return { tables = { { cells = ns.db.shared.mine } } }
    end
    local reset = SeedField("resets")[mapID]
    local own = OwnRecord()
    local sources = { seed = { cells = Seed().cells, seed = true }, tables = {}, reset = reset,
        others = ns.Share.IsEnabled() and Others() or nil }
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
            AddCell(sum, entry.cell, entry)
        end
    end
end

local function SumSpot(sources, keys)
    local sum = NewSum()
    for _, key in ipairs(keys) do
        if sources.seed then
            AddCell(sum, sources.seed.cells[key], sources.seed)
        end
        for _, source in ipairs(sources.tables) do
            AddCell(sum, source.cells[key], source)
        end
        if sources.others then
            AddOthers(sum, sources.others.byKey[key], sources.reset)
        end
    end
    return sum
end

-- Contributions behind a sum, each at most once (research R9): records of IDs the seed never absorbed are
-- other players for sure; those it absorbed may be among the seed's k, so they only count above it.
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
    local sum, wanted = NewSum(), {}
    for _, range in ipairs(ranges) do
        wanted[MapRange(mapID, range)] = true
    end
    for prefix in pairs(wanted) do
        if sources.seed then
            for _, key in ipairs(SeedIndex(sources.seed.cells)[prefix] or {}) do
                AddCell(sum, sources.seed.cells[key], sources.seed)
            end
        end
        if sources.others then
            AddOthers(sum, sources.others.byPrefix[prefix], sources.reset)
        end
    end
    for _, source in ipairs(sources.tables) do
        for key, cell in pairs(source.cells) do
            if wanted[KeyMapRange(key)] then
                AddCell(sum, cell, source)
            end
        end
    end
    return sum
end

local function BuildView(scope, sum)
    local items = {}
    for itemID, entry in pairs(sum.i) do
        if entry[1] > 0 then
            table.insert(items, { itemID = itemID, catches = entry[1], chance = sum.c > 0 and entry[1] / sum.c or 0,
                pieces = entry[2] / entry[1] })
        end
    end
    table.sort(items, function(a, b)
        if a.catches ~= b.catches then
            return a.catches > b.catches
        end
        return a.itemID < b.itemID
    end)
    return { scope = scope, littleData = sum.c < LITTLE_DATA, catches = sum.c, misses = sum.m, items = items,
        players = Players(sum) }
end

local cache, cacheVersion = {}, nil

-- What a place gives (contracts/catchdb-api.md): the spot, or the whole map when the spot has fewer than
-- LITTLE_DATA catches. filter = { range = 0..4 or "all", source = "all" or "mine" }. A view is
-- { scope = "spot" | "map" | "none", littleData, catches, misses, items = { { itemID, catches, chance, pieces } },
-- players } (players: the contributions behind the numbers, a lower bound where the seed cannot tell; research R9).
function CatchDB.Query(mapID, cell, filter)
    if cacheVersion ~= version then
        wipe(cache)
        cacheVersion = version
    end
    local cacheKey = table.concat({ mapID, cell, tostring(filter.range), filter.source }, "|")
    if cache[cacheKey] then
        return cache[cacheKey]
    end
    local ranges = filter.range == "all" and CatchDB.RANGES or { filter.range }
    local sources = Sources(filter.source, mapID)
    local keys = {}
    for i, range in ipairs(ranges) do
        keys[i] = CatchDB.PlaceKey(mapID, range, cell)
    end
    local spot = SumSpot(sources, keys)
    local view
    if spot.c >= LITTLE_DATA then
        view = BuildView("spot", spot)
    else
        local map = SumMap(sources, mapID, ranges)
        view = BuildView(map.c > 0 and "map" or "none", map) -- "none": nothing caught, misses or not
    end
    cache[cacheKey] = view
    return view
end

-- The bundled seed's epoch and number of places, for /okf share.
function CatchDB.SeedInfo()
    return SeedEpoch(), CountKeys(Seed().cells)
end

-- False when the bundled seed is missing, malformed or has no places.
function CatchDB.HasSeed()
    return next(Seed().cells) ~= nil
end

local lastPool -- what IsPoolLoot said about the last catch

-- Lines for /okf debug; never the anonymous ID (the report goes into public bug reports).
function CatchDB.Describe()
    local lines = {}
    table.insert(lines, ("seed epoch %d, %d places"):format(CatchDB.SeedInfo()))
    table.insert(lines, ("own places %d"):format(CountKeys(ns.db.shared.mine)))
    local mapID, range, cell = CatchDB.GetCurrentPlace()
    table.insert(lines, "current place " .. (mapID and CatchDB.PlaceKey(mapID, range, cell) or "none"))
    table.insert(lines, "last catch from a pool: " .. tostring(lastPool))
    table.insert(lines, "game version key " .. BuildKey())
    return lines
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
ns.RegisterEvent("ADDON_LOADED", function(_, loadedName)
    if loadedName ~= "OneKeyFishing" or not ns.db then
        return
    end
    local shared = ns.db.shared
    if type(shared.myID) ~= "string" or shared.myID == "" then
        shared.myID = ns.RandomBase32(ID_LENGTH)
    end
    local record = shared.records[shared.myID]
    -- A damaged record (edited by hand, an interrupted write) would break every catch: it starts over.
    if type(record) ~= "table" or type(record.builds) ~= "table" or type(record.seq) ~= "number"
        or type(record.epoch) ~= "number" then
        shared.records[shared.myID] = nil
        Roll()
    -- A record the seed holds (in part or whole) rolls, so it does not count twice next to the seed; what the seed
    -- lacks goes on to the next harvest. shared.mine keeps the lifetime counts either way.
    elseif CatchDB.AbsorbedSeq(shared.myID, record.epoch) then
        Roll()
    end
    version = version + 1 -- the seed or the record may be new
    others, frozen = nil, nil
end)

-- The place is read at every cast start, also for a cast picked up after a /reload: nothing is counted here,
-- so nothing can count twice; its time runs from the pickup.
ns.On("FISHING_CAST_START", function()
    local mapID, range, cell, x, y = CatchDB.GetCurrentPlace()
    if mapID then
        casts[ns.GetFishingCastID()] = { key = CatchDB.PlaceKey(mapID, range, cell), x = x, y = y,
            start = GetTime() }
    end
end)

ns.On("FISHING_CAST_STOP", function()
    local cast = casts[ns.GetFishingCastID()]
    if cast then
        cast.stop = GetTime()
    end
end)

-- Catch.lua settles a cast and every earlier one with it; only the named cast is counted.
local function TakeCast(castID)
    local cast = casts[castID]
    for id in pairs(casts) do
        if id <= castID then
            casts[id] = nil
        end
    end
    return cast
end

ns.On("FISH_CAUGHT", function(items, fromPool, castID)
    lastPool = fromPool
    local cast = TakeCast(castID)
    if cast then
        Settle(cast, CatchItems(items), fromPool)
    end
end)

ns.On("FISH_MISSED", function(castID)
    local cast = TakeCast(castID)
    if cast then
        Settle(cast, nil)
    end
end)

-- Records under "<id>@<epoch>" came or went (other players', Share.lua, or the own one a roll kept), or sharing
-- was switched: the views and their index change.
ns.On("SHARED_DATA_CHANGED", function(keys)
    version = version + 1
    frozen = nil
    if others and keys then
        for _, key in ipairs(keys) do
            UnindexRecord(key)
            IndexRecord(key)
        end
    else
        others = nil
    end
end)

ns.RegisterEvent("PLAYER_LOGOUT", CatchDB.FlushSeq)
