-- CatchDB: what is caught where, account-wide, for the "What can be caught here" tab and the bundled seed
-- (SeedData.lua, written by npm run harvest). A place is "<mapID>:<skill range>:<cell>", numbers only, so
-- clients in every language agree. Every catch and miss in fishing mode goes into two tables of the same cell
-- shape: shared.mine (this account's catches, never reset) and the account's contribution record (what the
-- harvest reads; split by game version). See specs/002-local-catch-db/data-model.md.
-- The module spans the CatchDB/ folder: this file (places, the seed, the own record, its chain, roll and settle),
-- Checks.lua (other players' records), Views.lua (sums and queries) and Events.lua (the game's events).
local _, ns = ...

local CatchDB = {}
ns.CatchDB = CatchDB
local P = {}
CatchDB.private = P -- internals shared by the CatchDB/*.lua files (not an API); exported at the end

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

-- State shared by the CatchDB/*.lua files lives on P (reassigned, so never re-bound into a local):
--   P.version   grows with every change the views must see (GetVersion)
--   P.ownItems  item ID -> true: the items of the own catch, for the views (Views.lua OwnItems)
--   P.ownIndex  "<mapID>:<range>" -> { place key -> true }: the keys of the own tables (mine, the own record and
--               the frozen own records), so a map's sum does not walk every own cell (Views.lua OwnIndex). Built on
--               first use, grown by Settle.
--   P.poolData  CatchDB.HasPoolData's answer: nil until read, false until a pool part shows up
--   P.others, P.frozen, P.lastPool: Views.lua
P.version = 0
local lastSeqBump -- GetTime() of the last seq bump
local seqWaiting = false -- a change since the last bump

function CatchDB.GetVersion()
    return P.version
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
        P.ownIndex[prefix] = P.ownIndex[prefix] or {}
        P.ownIndex[prefix][key] = true
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
CatchDB.IsProof = IsProof

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
    P.ownIndex = nil
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
    P.version = P.version + 1
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
                P.poolData = true
                cell.p = cell.p or { c = 0, i = {} } -- catches only: a miss has no loot source
                cell.p.c = cell.p.c + 1
                AddItems(cell.p, caught)
            end
        else
            cell.m = cell.m + 1
        end
    end
    if P.ownItems and caught then
        for itemID in pairs(caught) do
            if not P.ownItems[itemID] then
                -- An item new to the own catch may now show on other maps too (BuildView's rule for new items).
                BumpAll()
            end
            P.ownItems[itemID] = true
        end
    end
    if P.ownIndex then
        AddToOwnIndex(cast.key)
    end
    BumpMap(KeyMapID(cast.key))
    Changed(CatchDB.IsBuild(build))
end

-- Shared with the other CatchDB/*.lua files through CatchDB.private; the names a later file re-binds are never
-- reassigned here. The reassigned state lives on P itself (P.version, P.ownItems, P.ownIndex, P.poolData, P.others,
-- P.frozen, P.lastPool).
P.MAX_PIECES, P.MAX_AREAS, P.mapCache = MAX_PIECES, MAX_AREAS, mapCache
P.BumpMap, P.BumpAll, P.MapRange, P.KeyMapRange, P.KeyMapID = BumpMap, BumpAll, MapRange, KeyMapRange, KeyMapID
P.AddToOwnIndex, P.BuildKey, P.Seed, P.SeedField, P.OlderBuild = AddToOwnIndex, BuildKey, Seed, SeedField, OlderBuild
P.OwnRecord, P.OwnChain, P.StartMarks, P.NewChain, P.Roll = OwnRecord, OwnChain, StartMarks, NewChain, Roll
P.CatchItems, P.Settle = CatchItems, Settle
