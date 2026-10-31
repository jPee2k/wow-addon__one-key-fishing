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
local MAX_AREAS = 8 -- subzones counted per cell (a, specs/005-catch-catalog research R4); a ninth is not added
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
local ownItems -- item ID -> true: the items of the own catch, for the views (OwnItems below)
-- "<mapID>:<range>" -> { place key -> true }: the keys of the own tables (mine, the own record and the frozen own
-- records), so a map's sum does not walk every own cell (OwnIndex below). Built on first use, grown by Settle.
local ownIndex
local poolData -- CatchDB.HasPoolData's answer: nil until read, false until a pool part shows up

function CatchDB.GetVersion()
    return version
end

---------------------------------------------------------------------------
-- Change stamps (specs/005-catch-catalog, research R3): a stamp per map, moved whenever that map's sums may change,
-- and one for every map. The catalog recomputes only the maps whose stamp moved.
---------------------------------------------------------------------------
local stamps, globalStamp = {}, 0
local stampVersion = 0 -- grows with every bump of any stamp: nothing moved while it stays
local mapCache = {} -- "<kind>|<mapID>|<filter>" -> { stamp, value }: the views of QueryMap and QueryCells

local function BumpMap(mapID)
    if mapID then
        stamps[mapID] = (stamps[mapID] or 0) + 1
        stampVersion = stampVersion + 1
    end
end

local function BumpAll()
    globalStamp = globalStamp + 1
    stampVersion = stampVersion + 1
    wipe(mapCache) -- every entry is stale now
end

function CatchDB.MapStamp(mapID)
    return globalStamp .. ":" .. (stamps[mapID] or 0)
end

function CatchDB.GetStampVersion()
    return stampVersion
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

-- The map ID of a place key or a "<mapID>:<range>" prefix.
local function KeyMapID(key)
    return type(key) == "string" and tonumber(key:match("^(%d+):")) or nil
end

local function AddToOwnIndex(key)
    local prefix = KeyMapRange(key)
    if prefix then
        ownIndex[prefix] = ownIndex[prefix] or {}
        ownIndex[prefix][key] = true
    end
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

-- The game's area ID of the player's subzone at a position of map mapID (research R4 of specs/005-catch-catalog),
-- or nil. Of the explored areas there it keeps the one the game names as GetSubZoneText does. Principle II: matching
-- against localized text must tolerate case changes in non-ASCII text, so both names are folded (ns.FoldCase); the
-- needle is the client's own text and only the ID is kept.
function CatchDB.GetArea(mapID, x, y)
    local subzone = GetSubZoneText and GetSubZoneText()
    if type(subzone) ~= "string" or subzone == "" or not (C_MapExplorationInfo and CreateVector2D and x and y) then
        return nil
    end
    -- VERIFY(V34): the explored areas at the player's own position include the subzone, named as GetSubZoneText
    -- shows it
    local areas = C_MapExplorationInfo.GetExploredAreaIDsAtPosition(mapID, CreateVector2D(x, y))
    local wanted = ns.FoldCase(subzone)
    for _, areaID in ipairs(type(areas) == "table" and areas or {}) do
        local name = C_Map.GetAreaInfo(areaID)
        if type(name) == "string" and ns.FoldCase(name) == wanted then
            return areaID
        end
    end
    return nil
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
local EMPTY_SEED = { epoch = 0, absorbed = {}, proofs = {}, blocked = {}, resets = {}, cells = {} }

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

local function IsProof(value)
    return type(value) == "string" and #value == 16 and value:find("^[a-z2-7]+$") ~= nil
end

-- True when the seed's `blocked` names the contribution ID (the author blocked it, FR-019 of part 3).
function CatchDB.IsBlocked(id)
    return id ~= nil and SeedField("blocked")[id] == true
end

-- The proof of the version of unit <id>@<epoch> the seed holds (its `proofs`), or nil: a newer version of the unit
-- must chain to it (specs/004-public-channel-sync, research.md R9).
function CatchDB.SeedProof(id, epoch)
    local epochs = SeedField("proofs")[id]
    local proof = type(epochs) == "table" and epochs[epoch]
    return IsProof(proof) and proof or nil
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

local CountKeys = ns.CountKeys -- Data.lua

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

---------------------------------------------------------------------------
-- The own record's version chain (specs/004-public-channel-sync/data-model.md "The version chain")
---------------------------------------------------------------------------
-- Link `top` is ProofStep(secret) and every lower link the ProofStep of the one above; a record at seq i carries
-- link i as its proof. Only this account knows the links above the newest one it published, so nobody else can
-- make a version a peer takes as newer. The marks (every MARK_STEP-th link) are built in the background.
local CHAIN_LENGTH = 4096 -- the highest seq one chain proves; the record rolls when its seq reaches it
local MARK_STEP = 64 -- a proof is at most MARK_STEP - 1 steps below the next mark
local SECRET_LENGTH = 26 -- base32 characters of a chain's secret (130 bits); never sent, never shown
CatchDB.CHAIN_LENGTH = CHAIN_LENGTH
local building = false -- a step of the mark build is scheduled

local function Chain()
    local chain = ns.db.shared.chain
    if type(chain) == "table" and type(chain.secret) == "string" and type(chain.marks) == "table"
        and type(chain.top) == "number" and type(chain.epoch) == "number" then
        return chain
    end
end

-- The chain of the own record's epoch, or nil (none yet, or one left from another epoch).
local function OwnChain(own)
    local chain = own and Chain()
    return chain and chain.epoch == own.epoch and chain or nil
end

-- Random draws, the clocks and the player's GUID through SHA-256: nobody can guess it from outside.
local function NewSecret()
    local parts = {}
    for i = 1, 8 do
        parts[i] = tostring(math.random(0, 2147483646))
    end
    table.insert(parts, tostring(time()))
    table.insert(parts, tostring(GetTime()))
    table.insert(parts, tostring(debugprofilestop and debugprofilestop() or 0))
    table.insert(parts, tostring((UnitGUID("player"))))
    return ns.HexToBase32(ns.SHA256(table.concat(parts, ":")), SECRET_LENGTH)
end

-- The proof of `seq`, or nil while the mark above it is not built yet.
local function ProofFor(chain, seq)
    if seq > chain.top then
        return nil
    end
    local mark = math.max(MARK_STEP, math.ceil(seq / MARK_STEP) * MARK_STEP)
    local link = chain.marks[mark]
    if not link then
        return nil
    end
    for _ = 1, mark - seq do
        link = ns.ProofStep(link)
    end
    return link
end

local function SetOwnProof()
    local own = OwnRecord()
    local chain = OwnChain(own)
    if chain then
        own.proof = ProofFor(chain, own.seq)
    end
end

-- One gap between two marks (MARK_STEP links) from the lowest mark built, so a build cut short by a logout goes on
-- at the next login. Returns true when every mark is there.
local function BuildMarkStep(chain)
    if chain.marks[MARK_STEP] then
        return true
    end
    local position = chain.top
    if not chain.marks[position] then
        chain.marks[position] = ns.ProofStep(chain.secret)
    end
    while position > MARK_STEP and chain.marks[position - MARK_STEP] do
        position = position - MARK_STEP
    end
    local link = chain.marks[position]
    for _ = 1, MARK_STEP do
        position = position - 1
        link = ns.ProofStep(link)
    end
    chain.marks[position] = link
    return position <= MARK_STEP
end

local function BuildMarks()
    building = false
    local chain = Chain()
    if not chain then
        return
    end
    if BuildMarkStep(chain) then
        SetOwnProof()
    else
        building = true
        C_Timer.After(0, BuildMarks)
    end
end

local function StartMarks()
    local chain = Chain()
    if chain and not chain.marks[MARK_STEP] and not building then
        building = true
        C_Timer.After(0, BuildMarks)
    end
end

local function NewChain(epoch)
    ns.db.shared.chain = { epoch = epoch, secret = NewSecret(), top = CHAIN_LENGTH, marks = {} }
    StartMarks()
end

-- False while the marks are still being built after a roll or a login: the own record is not offered then.
function CatchDB.OwnProofReady()
    local own = OwnRecord()
    local chain = OwnChain(own)
    return chain ~= nil and chain.marks[MARK_STEP] ~= nil and own.proof ~= nil
end

-- "seq of top, marks ready" for /okf debug; never the secret.
function CatchDB.ChainState()
    local own = OwnRecord()
    local chain = OwnChain(own)
    if not chain then
        return "none"
    end
    return ("%d of %d, marks %s"):format(own.seq, chain.top, chain.marks[MARK_STEP] and "ready" or "building")
end

local function BumpSeq()
    local own = OwnRecord()
    own.seq = own.seq + 1
    lastSeqBump, seqWaiting = GetTime(), false
    SetOwnProof()
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
        local chain = OwnChain(old)
        if not old.proof and chain then
            repeat until BuildMarkStep(chain) -- rare: a roll before the marks were ready; the kept record needs a proof
            SetOwnProof()
        end
        key = CatchDB.UnitKey(shared.myID, old.epoch)
        old.seen = time()
        shared.records[key] = old
    end
    local epoch = NextEpoch(shared)
    shared.records[shared.myID] = { id = shared.myID, epoch = epoch, seq = 0, builds = {} }
    NewChain(epoch)
    ownIndex = nil
    return key
end

-- Bumps a seq change that waits for its minute (at logout, and before the record goes to a peer, so it has a
-- seq for all its cells).
function CatchDB.FlushSeq()
    if seqWaiting and ns.db and OwnRecord() then
        BumpSeq()
    end
end

-- countsForSeq: false for a cast under a build the game gave no version for ("unknown"): that build never goes to
-- a peer (Share.lua, Store.ForSending), and a peer refuses a seq above the casts it gets.
local function Changed(countsForSeq)
    version = version + 1
    if not countsForSeq then
        return
    end
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

-- The cells a change goes into (mine and the own record under the current game version) and that version. A place
-- new to an own record of ROLL_PLACES places rolls the record first.
local function TargetCells(key)
    local own = OwnRecord()
    local chain = OwnChain(own)
    -- A seq at the chain's top cannot be bumped again (its proof is the last link): a new record goes on.
    if (not HasPlace(own, key) and CatchDB.CountPlaces(own, ROLL_PLACES) >= ROLL_PLACES)
        or (chain and own.seq >= chain.top) then
        local kept = Roll()
        if kept then
            ns.Fire("SHARED_DATA_CHANGED", { kept })
        end
    end
    local builds = OwnRecord().builds
    local build = BuildKey()
    builds[build] = builds[build] or {}
    return { Cell(ns.db.shared.mine, key), Cell(builds[build], key) }, build
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
    local cells, build = TargetCells(cast.key)
    for _, cell in ipairs(cells) do
        cell.t = cell.t + seconds
        if cast.x then
            cell.px = (cell.px or 0) + math.floor(cast.x * 1000 + 0.5)
            cell.py = (cell.py or 0) + math.floor(cast.y * 1000 + 0.5)
            if cast.area and (cell.a == nil or cell.a[cast.area] or ns.CountKeys(cell.a) < MAX_AREAS) then
                cell.a = cell.a or {}
                cell.a[cast.area] = (cell.a[cast.area] or 0) + 1
            end
        end
        if caught then
            cell.c = cell.c + 1
            AddItems(cell, caught)
            if fromPool then
                poolData = true
                cell.p = cell.p or { c = 0, i = {} } -- catches only: a miss has no loot source
                cell.p.c = cell.p.c + 1
                AddItems(cell.p, caught)
            end
        else
            cell.m = cell.m + 1
        end
    end
    if ownItems and caught then
        for itemID in pairs(caught) do
            if not ownItems[itemID] then
                -- An item new to the own catch may now show on other maps too (BuildView's rule for new items).
                BumpAll()
            end
            ownItems[itemID] = true
        end
    end
    if ownIndex then
        AddToOwnIndex(cast.key)
    end
    BumpMap(KeyMapID(cast.key))
    Changed(CatchDB.IsBuild(build))
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
CatchDB.IsProof = IsProof

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

local MAX_ITEM_ID = 2147483647 -- item IDs are 32-bit; an item the client does not know yet is no fault (FR-017a)

local function CheckItems(items, catches)
    if items == nil then
        return true
    end
    if type(items) ~= "table" then
        return false, "items are not a table"
    end
    for itemID, entry in pairs(items) do
        if not (IsCount(itemID) and itemID > 0 and itemID <= MAX_ITEM_ID) then
            return false, "item ID " .. tostring(itemID) .. " is not a positive 32-bit number"
        end
        local withItem, pieces = type(entry) == "table" and entry[1], type(entry) == "table" and entry[2]
        if not (IsCount(withItem) and IsCount(pieces)) or withItem > catches or pieces < withItem
            or pieces > MAX_PIECES * withItem then
            return false, "item " .. itemID .. " has impossible counts"
        end
    end
    return true
end

-- The subzone counts a of a cell (data-model.md of specs/005-catch-catalog): absent or a table of at most 8
-- entries; every key is a whole number from 1 to 2,147,483,647; every count is a count, and their sum is at most
-- c + m.
local MAX_AREA_ID = 2147483647

local function CheckAreas(areas, casts)
    if areas == nil then
        return true
    end
    if type(areas) ~= "table" then
        return false, "the areas are not a table"
    end
    local count, total = 0, 0
    for areaID, n in pairs(areas) do
        count = count + 1
        if count > MAX_AREAS then
            return false, "more than " .. MAX_AREAS .. " areas"
        end
        if not (IsCount(areaID) and areaID >= 1 and areaID <= MAX_AREA_ID) then
            return false, "area ID " .. tostring(areaID) .. " is not a positive 32-bit number"
        end
        if not IsCount(n) then
            return false, "area " .. areaID .. " has no count"
        end
        total = total + n
    end
    if total > casts then
        return false, "more casts in areas than in the cell"
    end
    return true
end

local function CheckCell(cell)
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
    local ok, reason = CheckItems(cell.i, cell.c)
    if not ok then
        return false, reason
    end
    ok, reason = CheckAreas(cell.a, casts)
    if not ok then
        return false, reason
    end
    if cell.p ~= nil then
        if type(cell.p) ~= "table" or not IsCount(cell.p.c) or cell.p.c > cell.c then
            return false, "the pool part does not fit the totals"
        end
        return CheckItems(cell.p.i, cell.p.c)
    end
    return true
end

-- Casting per seq step (specs/004-public-channel-sync, research.md R9): the seq is bumped at most once a minute, on
-- the first settled cast after it, so one step holds at most a minute plus two casts of casting. A record never holds
-- more than STEP_SECONDS per step of its seq, whoever sends it: a copy made up at a seq its owner published can add
-- only that much, and the limit needs no other version, so no copy can block the owner's next one.
-- VERIFY(V26): a fishing cast lasts at most about 30 s in Forever, so no honest step reaches STEP_SECONDS
local STEP_SECONDS = 180
CatchDB.STEP_SECONDS = STEP_SECONDS

-- True, or false and the reason, for a record received from another player (the store refuses the own ID). An item
-- this client does not know is accepted: WoW Forever reveals some items only when they are found (FR-017a).
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
    if not IsProof(record.proof) then
        return false, "the proof is not 16 base32 characters"
    end
    if type(record.builds) ~= "table" then
        return false, "no builds"
    end
    if CatchDB.CountPlaces(record, MAX_RECORD_PLACES) > MAX_RECORD_PLACES then
        return false, "more than " .. MAX_RECORD_PLACES .. " places"
    end
    local casts, seconds = 0, 0
    for build, cells in pairs(record.builds) do
        if not CatchDB.IsBuild(build) or type(cells) ~= "table" then
            return false, "build " .. tostring(build) .. " is not a game version"
        end
        for key, cell in pairs(cells) do
            if type(key) ~= "string" or not (key:find("^%d+:[0-4]:%d%d$") or key:find("^%d+:[0-4]:x$")) then
                return false, "place key " .. tostring(key) .. " is not <mapID>:<range>:<cell>"
            end
            local ok, reason = CheckCell(cell)
            if not ok then
                return false, key .. ": " .. reason
            end
            casts, seconds = casts + cell.c + cell.m, seconds + cell.t
        end
    end
    -- The seq grows only after a settled cast, so it is never above the casts; a higher one is made up (it would
    -- make the owner's real updates look older everywhere).
    if record.seq > casts then
        return false, "seq " .. record.seq .. " is above the record's " .. casts .. " casts"
    end
    if seconds > STEP_SECONDS * record.seq then
        return false, "more casting than " .. record.seq .. " version steps allow"
    end
    return true
end

---------------------------------------------------------------------------
-- Newer versions (specs/004-public-channel-sync, research.md R9)
---------------------------------------------------------------------------
-- Checks that a newer version of a unit continues the version held (the stored record, or { seq, proof } of the
-- seed's absorbed version): its proof, stepped down to the held seq, must be the held proof, which only the owner
-- can make. Walks at most `steps` links per call (all when nil) and returns "ok", "invalid" and the reason, or "more"
-- and the state to pass to the next call. The incoming record passed CheckRecord (and so the casting limit).
function CatchDB.CheckVersion(held, incoming, steps, state)
    if not state then
        if incoming.seq <= held.seq then
            return "invalid", "not newer than the version held"
        end
        if incoming.seq - held.seq > CHAIN_LENGTH then
            return "invalid", "a jump over a whole chain"
        end
        state = { link = incoming.proof, left = incoming.seq - held.seq }
    end
    for _ = 1, math.min(steps or state.left, state.left) do
        state.link = ns.ProofStep(state.link)
        state.left = state.left - 1
    end
    if state.left > 0 then
        return "more", state
    end
    if state.link ~= held.proof then
        return "invalid", "the proof does not continue the version held"
    end
    return "ok"
end

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
                local entry = { cell = cell, id = record.id, build = build, place = place, prefix = prefix,
                    other = true, mapID = KeyMapID(prefix), range = tonumber(prefix:match(":(%d)$")) }
                AddToSet(others.byKey, place, entry)
                AddToSet(others.byPrefix, prefix, entry)
                table.insert(entries, entry)
            end
        end
    end
    others.byRecord[key] = entries
end

local function RemoveFromSet(sets, name, entry)
    local set = sets[name]
    set[entry] = nil
    if next(set) == nil then
        sets[name] = nil
    end
end

local function UnindexRecord(key)
    for _, entry in ipairs(others.byRecord[key] or {}) do
        RemoveFromSet(others.byKey, entry.place, entry)
        RemoveFromSet(others.byPrefix, entry.prefix, entry)
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

-- True for a record key of the own ID: the live record, or one a roll froze under "<myID>@<epoch>".
local function IsOwnKey(key)
    local myID = ns.db.shared.myID
    return key == myID or (CatchDB.IsOtherKey(key) and CatchDB.ParseUnit(key) == myID)
end

local function OwnIndex()
    if not ownIndex then
        ownIndex = {}
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
    return ownIndex
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
    if not ownItems then
        ownItems = {}
        AddItemsOf(ownItems, ns.db.shared.mine)
        for key, record in pairs(ns.db.shared.records) do
            if type(record) == "table" and record.id == ns.db.shared.myID and type(record.builds) == "table"
                and (key == record.id or CatchDB.IsOtherKey(key)) then
                for _, cells in pairs(record.builds) do
                    AddItemsOf(ownItems, cells)
                end
            end
        end
    end
    return ownItems
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
    if cacheVersion ~= version then
        wipe(cache)
        wipe(reportersCache)
        cacheVersion = version
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
    if poolData == nil then
        poolData = AnyPool(Seed().cells) or AnyPool(ns.db.shared.mine)
        for _, record in pairs(ns.db.shared.records) do
            for _, cells in pairs(type(record) == "table" and type(record.builds) == "table" and record.builds or {}) do
                poolData = poolData or AnyPool(cells)
            end
        end
    end
    return poolData
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
    if type(record) == "table" and record.id == nil then
        record.id = shared.myID -- the one field that can be put back: the catches under this key are the account's
    end
    -- A damaged record (edited by hand, an interrupted write) would break every catch, or every HELLO when its ID
    -- is another account's: it starts over.
    if type(record) ~= "table" or type(record.builds) ~= "table" or type(record.seq) ~= "number"
        or type(record.epoch) ~= "number" or record.id ~= shared.myID then
        shared.records[shared.myID] = nil
        Roll()
    -- A record the seed holds (in part or whole) rolls, so it does not count twice next to the seed; what the seed
    -- lacks goes on to the next harvest. shared.mine keeps the lifetime counts either way.
    elseif CatchDB.AbsorbedSeq(shared.myID, record.epoch) then
        Roll()
    else
        -- The version chain of the live record (specs/004-public-channel-sync, data-model.md): resumed, or made for
        -- a record from before part 3 (no proof published yet, so a chain can start at its seq); a record whose
        -- published proofs lost their chain, or whose seq is past a chain's top, starts over.
        if OwnChain(record) then
            StartMarks()
        elseif record.proof == nil and record.seq < CHAIN_LENGTH then
            NewChain(record.epoch)
        else
            Roll()
        end
    end
    version = version + 1 -- the seed or the record may be new
    others, frozen, ownItems, ownIndex, poolData = nil, nil, nil, nil, nil
    BumpAll()
end)

-- The place is read at every cast start, also for a cast picked up after a /reload: nothing is counted here,
-- so nothing can count twice; its time runs from the pickup.
ns.On("FISHING_CAST_START", function()
    local mapID, range, cell, x, y = CatchDB.GetCurrentPlace()
    if mapID then
        casts[ns.GetFishingCastID()] = { key = CatchDB.PlaceKey(mapID, range, cell), x = x, y = y,
            area = x and CatchDB.GetArea(mapID, x, y), start = GetTime() }
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

-- The maps of a record's indexed entries move.
local function BumpEntries(entries)
    for _, entry in ipairs(entries or {}) do
        BumpMap(entry.mapID)
    end
end

-- Records under "<id>@<epoch>" came or went (other players', Share.lua, or the own one a roll kept), or sharing
-- was switched: the views and their index change. A change in another store (a protocol node of the tests) is not
-- this player's data. Named records move the stamps of their maps, before and after the change; anything else,
-- or an own record, moves every stamp.
ns.On("SHARED_DATA_CHANGED", function(keys, store)
    if store ~= nil and ns.db and store ~= ns.db.shared then
        return
    end
    version = version + 1
    frozen = nil
    if poolData == false then
        poolData = nil
    end
    local own = keys == nil
    for _, key in ipairs(keys or {}) do
        own = own or IsOwnKey(key)
    end
    if own then
        ownIndex = nil
    end
    if others and keys then
        for _, key in ipairs(keys) do
            BumpEntries(others.byRecord[key])
            UnindexRecord(key)
            IndexRecord(key)
            BumpEntries(others.byRecord[key])
        end
    else
        others = nil
    end
    if own or not others then
        BumpAll()
    end
end)

ns.RegisterEvent("PLAYER_LOGOUT", CatchDB.FlushSeq)
