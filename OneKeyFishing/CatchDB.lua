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
local ID_CHARS = "abcdefghijklmnopqrstuvwxyz234567"
local ID_LENGTH = 8

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
local function NewID()
    local chars = {}
    for i = 1, ID_LENGTH do
        local index = math.random(#ID_CHARS)
        chars[i] = ID_CHARS:sub(index, index)
    end
    return table.concat(chars)
end

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

-- The cells a change goes into: mine and the own record under the current game version.
local function TargetCells(key)
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
-- Views
---------------------------------------------------------------------------
local LITTLE_DATA = 50 -- catches a scope needs before chances are shown

local function NewSum()
    return { c = 0, m = 0, i = {} }
end

local function AddCell(sum, cell)
    if type(cell) ~= "table" then
        return
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

-- The seed's keys per "<mapID>:<range>", built once per seed (the seed is large; own data is small).
local seedIndex, indexedSeed

local function SeedIndex(seed)
    if indexedSeed ~= seed then
        seedIndex, indexedSeed = {}, seed
        for key in pairs(seed.cells) do
            local prefix = KeyMapRange(key)
            if prefix then
                seedIndex[prefix] = seedIndex[prefix] or {}
                table.insert(seedIndex[prefix], key)
            end
        end
    end
    return seedIndex
end

-- The cell tables (place key -> cell, plus the seed's index) a source reads for a map: "all" is the seed plus
-- the own record, without the own cells of game versions older than a reset of the map (after a patch that
-- changed its catch); "mine" is the lifetime counts.
local function Sources(source, mapID)
    if source == "mine" then
        return { { cells = ns.db.shared.mine } }
    end
    local seed = Seed()
    local sources = { { cells = seed.cells, index = SeedIndex(seed) } }
    local reset = SeedField("resets")[mapID]
    for build, cells in pairs(OwnRecord().builds) do
        if not (reset and OlderBuild(build, reset)) then
            table.insert(sources, { cells = cells })
        end
    end
    return sources
end

local function SumMap(sources, mapID, ranges)
    local sum, wanted = NewSum(), {}
    for _, range in ipairs(ranges) do
        wanted[MapRange(mapID, range)] = true
    end
    for _, source in ipairs(sources) do
        if source.index then
            for prefix in pairs(wanted) do
                for _, key in ipairs(source.index[prefix] or {}) do
                    AddCell(sum, source.cells[key])
                end
            end
        else
            for key, cell in pairs(source.cells) do
                if wanted[KeyMapRange(key)] then
                    AddCell(sum, cell)
                end
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
    return { scope = scope, littleData = sum.c < LITTLE_DATA, catches = sum.c, misses = sum.m, items = items }
end

local cache, cacheVersion = {}, nil

-- What a place gives (contracts/catchdb-api.md): the spot, or the whole map when the spot has fewer than
-- LITTLE_DATA catches. filter = { range = 0..4 or "all", source = "all" or "mine" }.
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
    local spot = NewSum()
    for _, range in ipairs(ranges) do
        local key = CatchDB.PlaceKey(mapID, range, cell)
        for _, source in ipairs(sources) do
            AddCell(spot, source.cells[key])
        end
    end
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

-- False when the bundled seed is missing, malformed or has no places.
function CatchDB.HasSeed()
    return next(Seed().cells) ~= nil
end

local lastPool -- what IsPoolLoot said about the last catch

local function CountKeys(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

-- Lines for /okf debug; never the anonymous ID (the report goes into public bug reports).
function CatchDB.Describe()
    local lines = {}
    table.insert(lines, ("seed epoch %d, %d places"):format(SeedEpoch(), CountKeys(Seed().cells)))
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
        shared.myID = NewID()
    end
    -- A record the seed already absorbed starts over, so it does not count twice next to the seed.
    -- shared.mine keeps the lifetime counts either way.
    local record = shared.records[shared.myID]
    -- A damaged record (edited by hand, an interrupted write) would break every catch: it starts over.
    if type(record) ~= "table" or type(record.builds) ~= "table" or type(record.seq) ~= "number" then
        record = nil
    end
    local absorbed = SeedField("absorbed")[shared.myID]
    if record and type(absorbed) == "number" and absorbed >= (record.epoch or 0)
        and SeedEpoch() > (record.epoch or 0) then
        record = nil
    end
    if not record then
        shared.records[shared.myID] = { id = shared.myID, epoch = SeedEpoch(), seq = 0, builds = {} }
    end
    version = version + 1 -- the seed or the record may be new
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

ns.RegisterEvent("PLAYER_LOGOUT", function()
    if seqWaiting and ns.db and OwnRecord() then
        BumpSeq()
    end
end)
