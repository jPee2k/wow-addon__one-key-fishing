-- Share: the catch exchange with the guild, the group and friends (part 2 of the shared catch database).
-- Other players' records are kept next to the own one in shared.records under "<id>@<epoch>" (the store below).
-- A protocol node finds peers (HELLO) and moves only the missing records between two clients (SUM, DIFF, WANT,
-- REC, BYE) over Comm.lua. The node gets its clock, scheduler and transport from `env`, so the tests run several
-- nodes over a fake network; the game makes one, bound to Comm. The state shows in the "What can be caught here"
-- tab, on the "Shared database" settings page, in /okf share and in /okf debug; a one-time popup tells the player
-- before anything is exchanged. Peers' names live only in memory.
-- See specs/003-guild-group-sync/contracts/share-api.md and sync-protocol.md.
local _, ns = ...
local L = ns.L

local Share = {}
ns.Share = Share

local HASH_PRIME = 4294967291 -- the largest prime below 2^32
local MAX_OTHER_PLACES = 20000 -- other players' records together (about 2 MB of saved data)
local MAX_RECORD_BYTES = 32 * 1024 -- one encoded record
local SESSION_BYTES = 8 * 1024 -- encoded records per direction and session (but always one record)
local SESSION_TIMEOUT = 15 -- seconds without a message from the peer
local SESSION_MAX_LIFE = 5 * 60 -- seconds a session may run in all: a peer that only keeps sending parts holds no slot
local PEER_PAUSE = 30 * 60 -- no session with a peer that timed out or went offline
local SESSION_GAP = 120 -- seconds between session starts
local GROUP_COOLDOWN, OTHER_COOLDOWN = 10 * 60, 30 * 60 -- between sessions with the same peer
-- The responder's side of the cooldown: a SUM this soon after the last one answered with a DIFF gets BYE busy, so a
-- peer that ignores the cooldowns cannot spend the hourly budget on DIFFs. Shorter than GROUP_COOLDOWN by
-- SESSION_GAP, since the initiator's SUM may wait longer in its queue (pace, throttle) one time than the next.
local RESPONDER_GAP = GROUP_COOLDOWN - SESSION_GAP
local START_DELAY_MIN, START_DELAY_MAX = 2, 20 -- seconds a hearer waits before it starts a session
local FRIENDS_PER_ROUND = 20 -- HELLOs by whisper and Battle.net per round
local HELLO_LIMIT = 60 -- seconds between HELLOs taken from one sender
local SESSION_RECORDS = 25 -- records per direction and session, within SESSION_BYTES
-- Links of a version chain walked per frame step while a received record is checked (research R9 of part 3).
-- VERIFY(V26): PROOF_STEPS proof steps take well under 5 ms in the game (the spike times 64 of them)
local PROOF_STEPS = 32
local HOUR = 3600
local ALONE_AFTER = 30 * 60 -- nobody heard for this long: "Nobody to exchange with right now"
local FIRST_HELLO_MIN, FIRST_HELLO_MAX = 60, 120 -- seconds after the login (or the closed popup)
local ROUND_MIN, ROUND_MAX = 10 * 60, 15 * 60 -- between HELLO rounds
local EXTRA_HELLO_MIN, EXTRA_HELLO_MAX = 5, 30 -- after a group change, a resumed pause or turning sharing on
local EXTRA_HELLO_GAP = 120 -- at most one extra HELLO per this many seconds for group changes
local HELLO_STALE = 10 * 60 -- after a pause, a HELLO only when the last one is older
local FULL_REFRESH_GAP = 10 * 60 -- seconds between refreshes of every record's seen
-- The hidden public channel (part 3: specs/004-public-channel-sync/contracts/protocol.md, research R5).
local CHANNEL_TARGET = 2 -- sessions started per channel HELLO, on average, whatever the number of hearers
local CHANNEL_WINDOW = 40 -- minutes of channel HELLOs counted: about the number of clients in the channel
local NEAR_WINDOW = 15 * 60 -- a guild, group or friend peer heard this recently comes before channel peers
local BUSY_RETRY_MIN, BUSY_RETRY_MAX = 120, 180 -- a near peer that answered BYE busy is tried again once
local MAX_CHANNEL_PEERS = 300 -- peers known only from the channel kept in memory (FR-009)
local MAX_ANNOUNCERS = 2000 -- addresses heard announcing in the channel, apart from the peers (Channel.lua's locks)
local CHANNEL_FIRST_MIN, CHANNEL_FIRST_MAX = 30, 90 -- seconds after joining before the first channel HELLO
local CHANNEL_ROUND_MIN, CHANNEL_ROUND_MAX = 30 * 60, 50 * 60 -- between channel HELLOs
local CHANNEL_MOVE_MIN, CHANNEL_MOVE_MAX = 5, 30 -- after a move to another channel
-- Limits per sender and hour; above one the sender is ignored until logout. Derived from what one honest client can
-- send to one peer in an hour, so an honest peer never reaches them:
-- - sessions: one per GROUP_COOLDOWN (both sides keep it), one more at the edges of the hour;
-- - records: SESSION_RECORDS in each session;
-- - messages, in units of MESSAGE_UNIT bytes (a message counts at least one): the sender's whole hourly budget
--   (Comm.lua), plus one unit for each message it can send: HELLOs (rounds, after a pause, after a group change;
--   up to 3 copies by guild, group and whisper), SESSION_MESSAGES per session, a BYE busy to each session start
--   of ours, and the records; then twice that. A flood of one message per second is still ignored within 20 min.
local SESSIONS_PER_HOUR = HOUR / GROUP_COOLDOWN + 1
local RECORD_LIMIT = SESSION_RECORDS * SESSIONS_PER_HOUR
local MESSAGE_UNIT = 240
local SESSION_MESSAGES = 5 -- SUM or DIFF, DIFF, WANT, BYE and a BYE limit
local HELLOS_PER_HOUR = HOUR / ROUND_MIN + HOUR / HELLO_STALE + HOUR / EXTRA_HELLO_GAP
local MESSAGE_LIMIT = 2 * (math.ceil(ns.Comm.BUDGET / MESSAGE_UNIT) + 3 * HELLOS_PER_HOUR
    + SESSION_MESSAGES * SESSIONS_PER_HOUR + HOUR / SESSION_GAP + RECORD_LIMIT)
Share.MESSAGE_LIMIT, Share.RECORD_LIMIT = MESSAGE_LIMIT, RECORD_LIMIT

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
-- CatchDB owns the record format: the "<id>@<epoch>" keys, counts, the seed (it loads earlier in the TOC).
local IsOther, IsCount, SeedAbsorbed = ns.CatchDB.IsOtherKey, ns.CatchDB.IsCount, ns.CatchDB.SeedAbsorbed
local IsProof = ns.CatchDB.IsProof

local function UnitOf(record)
    if type(record) == "table" and type(record.id) == "string" and IsCount(record.epoch) then
        return ns.CatchDB.UnitKey(record.id, record.epoch)
    end
end

-- True when `absorbed` (ID -> { [epoch] = seq }: the game's seed, or a test's own) holds this version of the unit
-- whole. A newer seq is held only in part: it is kept and passed on, so the rest reaches the next harvest.
local function Absorbed(absorbed, unit, seq)
    local id, epoch = ns.CatchDB.ParseUnit(unit)
    return id ~= nil and ns.CatchDB.IsAbsorbed(id, epoch, seq, absorbed)
end

-- Places of other players' records, counted once per stored table (a stored record is never changed).
local placeCache = setmetatable({}, { __mode = "k" })

local function OtherPlaces(record)
    local places = placeCache[record]
    if not places then
        places = ns.CatchDB.CountPlaces(record)
        placeCache[record] = places
    end
    return places
end

---------------------------------------------------------------------------
-- The store: other players' records in a `shared` table (OneKeyFishingDB.shared or a test's own)
---------------------------------------------------------------------------
local Store = {}
Share.Store = Store

-- A node's summary is current while both versions match: the store's own, bumped when Share changes that store, and
-- dataVersion, bumped by a SHARED_DATA_CHANGED from elsewhere (a roll of the own record, sharing switched). One
-- listener for every node, so a node of the tests is not kept alive by it, and a change in one test node's store
-- leaves the others' summaries alone.
local dataVersion = 0
local storeVersions = setmetatable({}, { __mode = "k" })
ns.On("SHARED_DATA_CHANGED", function(_, store)
    if store == nil then
        dataVersion = dataVersion + 1
    end
end)

-- keys: the record keys of `store` that came, changed or went (CatchDB updates its index of them).
local function Changed(store, keys)
    storeVersions[store] = (storeVersions[store] or 0) + 1
    ns.Fire("SHARED_DATA_CHANGED", keys, store)
end

-- store -> { unit -> seq } of the records Evict deleted this session: they are not wanted back, or eviction and
-- the next session would trade the same records forever while the network holds more than the limit.
local evicted = setmetatable({}, { __mode = "k" })

local function WasEvicted(store, unit, seq)
    local units = evicted[store]
    return units ~= nil and units[unit] ~= nil and seq <= units[unit]
end

local function CleanItems(items)
    local out = {}
    for itemID, entry in pairs(items or {}) do
        out[itemID] = { entry[1], entry[2] }
    end
    return out
end

local function CleanCell(cell)
    local out = { c = cell.c, m = cell.m, t = cell.t, px = cell.px, py = cell.py, i = CleanItems(cell.i) }
    if cell.p then
        out.p = { c = cell.p.c, i = CleanItems(cell.p.i) }
    end
    if cell.a then
        out.a = {} -- the subzone counts (part 4): a fresh table of the same numbers
        for areaID, count in pairs(cell.a) do
            out.a[areaID] = count
        end
    end
    return out
end

-- A checked record with only the record's fields (part 1 and the proof of part 3), so nothing else a peer sends
-- reaches the saved data.
local function CleanRecord(record, seen)
    local builds = {}
    for build, cells in pairs(record.builds) do
        builds[build] = {}
        for key, cell in pairs(cells) do
            builds[build][key] = CleanCell(cell)
        end
    end
    return { id = record.id, epoch = record.epoch, seq = record.seq, proof = record.proof, builds = builds,
        seen = seen }
end

-- store -> { unit -> the stored record whose chain the background walk (SeedChainWork) has not reached yet }: not
-- sent before it is checked (a peer with the seed would blame this client for a made-up copy), and not what a newer
-- version must continue.
local pendingChains = setmetatable({}, { __mode = "k" })

local function Pending(store, unit, record)
    local pending = pendingChains[store]
    return pending ~= nil and pending[unit] == record
end

-- The seed's absorbed version of the record's unit ({ seq, proof }: the chain alone), or nil.
local function SeedHeld(record, absorbed)
    local seq = ns.CatchDB.AbsorbedSeq(record.id, record.epoch, absorbed)
    local proof = seq and ns.CatchDB.SeedProof(record.id, record.epoch)
    return proof and { seq = seq, proof = proof, seed = true } or nil
end

-- The version a newer record of the unit must continue (specs/004-public-channel-sync, research.md R9): the stored
-- record (once its walk to the seed's proof is done), or the seed's absorbed version of it; nil when there is none.
function Store.HeldFor(store, record, absorbed)
    local unit = UnitOf(record)
    local stored = store.records[unit]
    if type(stored) == "table" and IsCount(stored.seq) and IsProof(stored.proof)
        and not Pending(store, unit, stored) then
        return stored
    end
    return SeedHeld(record, absorbed or SeedAbsorbed())
end

-- Keeps a received record (data-model.md "Rules for other players' records"): "new", "newer", "same" (only seen
-- is refreshed), "older" or "refused" with the reason. now: time() it was received; absorbed: the seed's table.
-- A newer version must continue the version held (CatchDB.CheckVersion); a merge that checked the record and walked
-- its chain over several frame steps passes verified = true, otherwise both run here ("refused", "invalid: ...").
function Store.Accept(store, record, now, absorbed, verified)
    absorbed = absorbed or SeedAbsorbed()
    if type(record) == "table" and record.id == store.myID then
        return "refused", "the own ID"
    end
    if type(record) == "table" and ns.CatchDB.IsBlocked(record.id) then
        Store.blocked = Store.blocked + 1
        return "refused", "blocked" -- by the author, in the bundled data: no fault of the sender (FR-020)
    end
    if not verified then
        local ok, reason = ns.CatchDB.CheckRecord(record)
        if not ok then
            return "refused", reason
        end
    end
    local unit = UnitOf(record)
    if Absorbed(absorbed, unit, record.seq) then
        return "refused", "already in the bundled data"
    end
    local stored = store.records[unit]
    if type(stored) == "table" and type(stored.seq) == "number" then
        if record.seq < stored.seq then
            return "older"
        end
        if record.seq == stored.seq then
            stored.seen = now or time()
            return "same"
        end
    end
    if not verified then
        local held = Store.HeldFor(store, record, absorbed)
        if held and record.seq > held.seq then
            local result, why = ns.CatchDB.CheckVersion(held, record)
            if result ~= "ok" then
                return "refused", "invalid: " .. tostring(why)
            end
        end
    end
    store.records[unit] = CleanRecord(record, now or time())
    Changed(store, { unit })
    return stored and "newer" or "new"
end

-- Records refused or deleted as blocked by the bundled data this session (/okf debug).
Store.blocked = 0

-- Deletes the records under "<id>@<epoch>" the seed holds whole, and damaged ones (another player's without a
-- valid proof among them); returns how many went.
function Store.CleanUp(store, absorbed)
    absorbed = absorbed or SeedAbsorbed()
    local removed = {}
    for key, record in pairs(store.records) do
        local blocked = IsOther(key) and type(record) == "table" and record.id ~= store.myID
            and ns.CatchDB.IsBlocked(record.id)
        if blocked then
            Store.blocked = Store.blocked + 1
        end
        if IsOther(key) and (blocked or type(record) ~= "table" or type(record.builds) ~= "table"
            or not IsCount(record.seq) or UnitOf(record) ~= key or Absorbed(absorbed, key, record.seq)
            or (record.id ~= store.myID and not IsProof(record.proof))) then
            store.records[key] = nil
            table.insert(removed, key)
        end
    end
    if #removed > 0 then
        Changed(store, removed)
    end
    return #removed
end

-- The stored versions of units the seed holds in part that must still be shown to continue the seed's proof (a copy
-- made up before a release named the unit). Each entry: { key, held, record, state }.
function Store.SeedChainWork(store, absorbed)
    absorbed = absorbed or SeedAbsorbed()
    local work = {}
    for key, record in pairs(store.records) do
        if IsOther(key) and type(record) == "table" and record.id ~= store.myID and IsProof(record.proof) then
            local held = SeedHeld(record, absorbed)
            if held and record.seq > held.seq then
                table.insert(work, { key = key, held = held, record = record })
                pendingChains[store] = pendingChains[store] or {}
                pendingChains[store][key] = record
            end
        end
    end
    return work
end

-- Walks the chains of SeedChainWork, at most `budget` links (all when nil); a record whose chain does not reach the
-- seed's proof is deleted. Returns true when the work is done.
function Store.CheckSeedChains(store, work, budget)
    while #work > 0 do
        local entry = work[1]
        local result, state = ns.CatchDB.CheckVersion(entry.held, entry.record, budget, entry.state)
        if result == "more" then
            entry.state = state
            return false
        end
        table.remove(work, 1)
        if Pending(store, entry.key, entry.record) then
            pendingChains[store][entry.key] = nil
        end
        if result ~= "ok" and store.records[entry.key] == entry.record then
            store.records[entry.key] = nil
            Changed(store, { entry.key })
        end
        if budget then
            return #work == 0
        end
    end
    return true
end

-- The eviction order by new information (specs/004-public-channel-sync, data-model.md "Eviction by new information"):
-- A, records about places the seed knows well, go first; then B, records no peer confirmed for long; then C; and D,
-- records about places with little data in the seed, go last.
local SATURATED_CATCHES = 1000 -- a place the seed holds this many catches of gains little from another record
local RARE_CATCHES = 50 -- a place the seed holds fewer catches of (part 1's "little data"; no seed cell counts too)
local STALE_SECONDS = 60 * 86400 -- not confirmed by any peer for this long

-- Shares of a record's places that are saturated and rare in the seed, once per stored table (a stored record never
-- changes; a new seed comes only with a new release, after a /reload at the least).
local shareCache = setmetatable({}, { __mode = "k" })

local function SeedShares(record)
    local shares = shareCache[record]
    if not shares then
        local places, saturated, rare, seen = 0, 0, 0, {}
        for _, cells in pairs(type(record.builds) == "table" and record.builds or {}) do
            for key in pairs(type(cells) == "table" and cells or {}) do
                if not seen[key] then
                    seen[key] = true
                    places = places + 1
                    local cell = ns.CatchDB.SeedCell(key)
                    local catches = cell and (tonumber(cell.r) or tonumber(cell.c)) or 0 -- r: raw, when weighted
                    if catches >= SATURATED_CATCHES then
                        saturated = saturated + 1
                    elseif catches < RARE_CATCHES then
                        rare = rare + 1
                    end
                end
            end
        end
        shares = { saturated = places > 0 and saturated / places or 0, rare = places > 0 and rare / places or 0 }
        shareCache[record] = shares
    end
    return shares
end

-- 1 (A) to 4 (D): the first class a record fits, D before B and C.
local function EvictionClass(record, now)
    local shares = SeedShares(record)
    if shares.rare > 0.5 then
        return 4
    elseif shares.saturated >= 0.5 then
        return 1
    elseif (tonumber(record.seen) or 0) < now - STALE_SECONDS then
        return 2
    end
    return 3
end

-- Above MAX_OTHER_PLACES, deletes other records until they fit: by class (EvictionClass), the one seen longest ago
-- first within a class; never one of the own ID (the live record, or one frozen by a roll: maybe the only copy left).
function Store.Evict(store)
    local total = 0
    for key, record in pairs(store.records) do
        if IsOther(key) then
            total = total + OtherPlaces(record)
        end
    end
    if total <= MAX_OTHER_PLACES then
        return 0
    end
    local removed, now = {}, time()
    evicted[store] = evicted[store] or {}
    while total > MAX_OTHER_PLACES do
        -- The first by class, then seen, then key: one pass per deletion, since usually one or two go.
        local pick, pickClass, pickSeen
        for key, record in pairs(store.records) do
            if IsOther(key) and record.id ~= store.myID then
                local class, seen = EvictionClass(record, now), tonumber(record.seen) or 0
                if not pick or class < pickClass or (class == pickClass
                    and (seen < pickSeen or (seen == pickSeen and key < pick))) then
                    pick, pickClass, pickSeen = key, class, seen
                end
            end
        end
        if not pick then
            break
        end
        evicted[store][pick] = store.records[pick].seq
        total = total - OtherPlaces(store.records[pick])
        store.records[pick] = nil
        table.insert(removed, pick)
    end
    if #removed > 0 then
        Changed(store, removed)
    end
    return #removed
end

local function OwnRecord(store)
    local own = store.records[store.myID]
    if type(own) == "table" and IsCount(own.seq) and IsCount(own.epoch) then
        return own
    end
end

-- Every unit held ("<id>@<epoch>" -> seq): the own record (when it has data) and those under "<id>@<epoch>" (other
-- players' and the own frozen ones) the seed does not hold whole.
function Store.Units(store, absorbed)
    absorbed = absorbed or SeedAbsorbed()
    local units = {}
    for key, record in pairs(store.records) do
        if IsOther(key) and type(record) == "table" and IsCount(record.seq)
            and not Absorbed(absorbed, key, record.seq)
            and (record.id == store.myID or not ns.CatchDB.IsBlocked(record.id)) then
            units[key] = record.seq
        end
    end
    local own = OwnRecord(store)
    if own and ns.CatchDB.HasCells(Store.ForSending(own)) then -- the record as it is sent
        units[UnitOf(own)] = own.seq
    end
    return units
end

function Store.Get(store, unit)
    local own = OwnRecord(store)
    if own and unit == UnitOf(own) then
        return own
    end
    if IsOther(unit) then
        return store.records[unit]
    end
end

-- A record as it is sent: the record's fields only (seen is local), without builds a peer would refuse (the own
-- record keeps "unknown" when the game gave no version; the harvest skips such builds too).
function Store.ForSending(record)
    local builds = {}
    for build, cells in pairs(record.builds) do
        if ns.CatchDB.IsBuild(build) then
            builds[build] = cells
        end
    end
    return { id = record.id, epoch = record.epoch, seq = record.seq, proof = record.proof, builds = builds }
end

---------------------------------------------------------------------------
-- Hashes (research R5)
---------------------------------------------------------------------------
-- Plain arithmetic, no bit library: the hash must agree between the game (Lua 5.1) and the tests (fengari).
function Share.Hash(text)
    local hash = 5381
    for i = 1, #text do
        hash = (hash * 31 + text:byte(i)) % HASH_PRIME
    end
    return hash
end

local function BucketIndex(id)
    return ns.BASE32:find(id:sub(1, 1), 1, true)
end

-- The 32 buckets (by the first character of the ID) of sorted "id.epoch.seq" lines.
function Share.Buckets(units)
    local buckets = {}
    for i = 1, #ns.BASE32 do
        buckets[i] = {}
    end
    for unit, seq in pairs(units) do
        local id, epoch = ns.CatchDB.ParseUnit(unit)
        local index = id and BucketIndex(id)
        if index then
            table.insert(buckets[index], ("%s.%d.%d"):format(id, epoch, seq))
        end
    end
    for _, lines in ipairs(buckets) do
        table.sort(lines)
    end
    return buckets
end

-- The hash of each bucket of Share.Buckets, as SUM sends it (7 base32 characters).
function Share.BucketHashes(buckets)
    local texts = {}
    for i, lines in ipairs(buckets) do
        texts[i] = ns.Base32(Share.Hash(table.concat(lines, " ")), 7)
    end
    return texts
end

-- The whole hash over the bucket hash texts, as HELLO sends it.
function Share.WholeHash(hashTexts)
    return ns.Base32(Share.Hash(table.concat(hashTexts)), 7)
end

---------------------------------------------------------------------------
-- Encoding (research R4)
---------------------------------------------------------------------------
-- VERIFY(V15): C_EncodingUtil round-trips a record, and the Base64 text holds only Base64 characters
function Share.Encode(record)
    local ok, text = pcall(function()
        local util = C_EncodingUtil
        return util.EncodeBase64(util.CompressString(util.SerializeCBOR(record), Enum.CompressionMethod.Deflate))
    end)
    return ok and type(text) == "string" and text or nil
end

function Share.Decode(text)
    local ok, record = pcall(function()
        local util = C_EncodingUtil
        local raw = util.DecodeBase64(text)
        local plain = raw and util.DecompressString(raw, Enum.CompressionMethod.Deflate)
        return plain and util.DeserializeCBOR(plain)
    end)
    return ok and type(record) == "table" and record or nil
end

---------------------------------------------------------------------------
-- The protocol node (contracts/sync-protocol.md)
---------------------------------------------------------------------------
local Node = {}
Node.__index = Node

-- env: { now, time, after, send(address, text, kind), broadcast, forEachFriend, canSend(bytes), absorbed, seedEpoch,
-- encode, decode, busy (optional: messages to an address still queued), prepare (optional: before the units are
-- read for a peer), clock (optional: milliseconds, for the longest merge step), random (optional: math.random) }.
function Share.NewNode(store, env)
    env.random = env.random or math.random
    -- chainRefused: "<unit>.<seq>" of a newer version that failed to continue the stored copy -> that copy (weak:
    -- gone with the copy).
    local node = setmetatable({ store = store, env = env, tag = ns.RandomBase32(4, env.random), peers = {},
        byTag = {}, cursor = 1, merges = {}, rejected = 0, longestStep = 0, cache = {}, ownData = {},
        channelHeard = {}, skippedNear = {}, channelCount = 0, ignored = {}, announcers = {}, announcerCount = 0,
        chainRefused = setmetatable({}, { __mode = "v" }) }, Node)
    return node
end

-- The units held and how many places they cover.
local function CountUnits(store, units)
    local own, count, places = OwnRecord(store), 0, 0
    for unit in pairs(units) do
        count = count + 1
        local record = Store.Get(store, unit)
        places = places + (record == own and ns.CatchDB.CountPlaces(own) or OtherPlaces(record))
    end
    return count, places
end

-- The units, buckets and hashes held, recomputed after a change of the store or of the own record's seq.
-- hashTexts: the 32 bucket hashes as sent in SUM; wholeText: the whole hash as sent in HELLO.
-- cached: the summary as it is; otherwise env.prepare runs first (the own record's waiting seq bump), so what
-- goes to a peer has a seq for all its cells. Only a HELLO round and the start of a session prepare: a catch may
-- not re-encode the own record on every message heard.
function Node:Summary(cached)
    if self.env.prepare and not cached then
        self.env.prepare()
    end
    local own = OwnRecord(self.store)
    local cache = self.cache
    local storeVersion = storeVersions[self.store]
    -- Compared field by field, not as a built string: a summary is read on every message heard.
    if cache.dataVersion ~= dataVersion or cache.storeVersion ~= storeVersion or cache.own ~= own
        or (own and (cache.ownID ~= own.id or cache.ownEpoch ~= own.epoch or cache.ownSeq ~= own.seq
            or cache.ownProof ~= own.proof)) then
        local units = Store.Units(self.store, self.env.absorbed())
        for unit in pairs(units) do
            local record = Store.Get(self.store, unit)
            if record.id == self.store.myID and not self:OwnData(record) then
                units[unit] = nil -- an offer that is never sent would keep every hash different
            end
        end
        local buckets = Share.Buckets(units)
        local hashTexts = Share.BucketHashes(buckets)
        local count, places = CountUnits(self.store, units)
        cache = { dataVersion = dataVersion, storeVersion = storeVersion, own = own, ownID = own and own.id,
            ownEpoch = own and own.epoch, ownSeq = own and own.seq, ownProof = own and own.proof, units = units,
            buckets = buckets, hashTexts = hashTexts, wholeText = Share.WholeHash(hashTexts), count = count,
            places = places }
        self.cache = cache
    end
    return cache
end

-- Refreshes `seen` of the other records among `units` (unit -> anything): a peer confirmed them.
function Node:Touch(units)
    local now = self.env.time()
    for unit in pairs(units) do
        local record = IsOther(unit) and self.store.records[unit]
        if record then
            record.seen = now
        end
    end
end

-- Touches the units held in the given buckets (index -> true; all when nil).
function Node:RefreshSeen(buckets)
    if not buckets then
        -- Every record: at most every FULL_REFRESH_GAP, since a HELLO with the same hash comes from many players and
        -- seen only ages records over 60 days (eviction).
        local now = self.env.now()
        if self.fullRefresh and now - self.fullRefresh < FULL_REFRESH_GAP then
            return
        end
        self.fullRefresh = now
    end
    local units = self:Summary(true).units
    if buckets then
        local picked = {}
        for unit in pairs(units) do
            if buckets[BucketIndex(unit)] then
                picked[unit] = true
            end
        end
        units = picked
    end
    self:Touch(units)
end

-- Adds `weight` to a per-minute counter and returns the total of the last hour (Data.lua).
local function Recent(counts, now, weight)
    return ns.CountRecent(counts, now, weight, HOUR / 60)
end

-- Above MAX_CHANNEL_PEERS peers known only from the channel, the one heard longest ago is forgotten, its tag too;
-- never a guild, group or friend peer, nor the session's (FR-009). An ignored one stays ignored (node.ignored).
function Node:BoundChannelPeers(keep)
    while self.channelCount > MAX_CHANNEL_PEERS do
        local oldest, oldestAt
        for address, peer in pairs(self.peers) do
            local at = peer.heard or 0
            if peer.via == "channel" and address ~= keep and not (self.session and self.session.peer == address)
                and (not oldestAt or at < oldestAt) then
                oldest, oldestAt = address, at
            end
        end
        if not oldest then
            return
        end
        local peer = self.peers[oldest]
        if peer.node and self.byTag[peer.node] == oldest then
            self.byTag[peer.node] = nil
        end
        self.peers[oldest] = nil
        self.channelCount = self.channelCount - 1
    end
end

-- Notes an address heard announcing in the channel. Kept apart from the peers, which the peer bound forgets: an
-- owner forgotten there would make its undo of a lock read as a lock. Bounded on its own, the one heard longest ago
-- forgotten first.
function Node:Announced(address, now)
    if not self.announcers[address] then
        self.announcerCount = self.announcerCount + 1
        if self.announcerCount > MAX_ANNOUNCERS then
            local oldest, oldestAt
            for known, at in pairs(self.announcers) do
                if not oldestAt or at < oldestAt then
                    oldest, oldestAt = known, at
                end
            end
            self.announcers[oldest] = nil
            self.announcerCount = self.announcerCount - 1
        end
    end
    self.announcers[address] = now
end

function Node:Peer(address, via)
    local peer = self.peers[address]
    if not peer then
        peer = { via = via, messages = {}, records = {}, ignored = self.ignored[address] }
        self.peers[address] = peer
        if via == "channel" then
            self.channelCount = self.channelCount + 1
            self:BoundChannelPeers(address)
        end
    end
    return peer
end

-- The path of a peer: a guild, group or friend path is never replaced by the channel, except for a stranger who
-- only whispered so far (a session it started after hearing this client in the channel).
function Node:SetVia(address, peer, via)
    if via ~= "channel" then
        if peer.via == "channel" then
            self.channelCount = self.channelCount - 1
        end
        peer.via = via
    elseif peer.via == "whisper" and not peer.heard then
        peer.via = "channel"
        self.channelCount = self.channelCount + 1
        self:BoundChannelPeers(address)
    end
end

-- Sends a session message; one that would not fit the budget whole (a long DIFF or WANT) ends the session
-- with BYE limit instead of going out in part. Returns false then.
function Node:Send(address, text)
    if self.session and self.session.peer == address and not self.env.canSend(#text) then
        self:Bye(address, self.session.sid, "limit")
        self:DropSession()
        return false
    end
    if self.env.send(address, text) == false then
        self:DropSessionWith(address)
        return false
    end
    return true
end

-- BYE goes out even over the traffic budget, so the other side is not left waiting.
function Node:Bye(address, sid, reason)
    self.env.send(address, "B" .. sid .. " " .. reason, "bye")
end

function Node:NewSession(sid, address, role)
    local session = { sid = sid, peer = address, role = role, started = self.env.now(), lastHeard = self.env.now(),
        ourWants = {}, received = {} }
    self.session = session
    return session
end

function Node:DropSession()
    self.session = nil
    self:Reconsider()
end

-- The near peers whose HELLO came while a session ran or a start was too recent: considered again once that is over
-- (research R5 of part 3), so a channel session never costs a guild, group or friend session its part 2 timing.
function Node:Reconsider()
    local skipped = self.skippedNear
    if next(skipped) == nil or self.session or self.paused then
        return -- kept until the session or the pause is over
    end
    local now = self.env.now()
    if self.lastStart and now - self.lastStart < SESSION_GAP then
        if not self.reconsidering then
            self.reconsidering = true
            -- At least 1 s: a clock that stops exactly at the gap may read a hair under it and wait again forever.
            self.env.after(math.max(1, SESSION_GAP - (now - self.lastStart)), function()
                self.reconsidering = nil
                self:Reconsider()
            end)
        end
        return
    end
    self.skippedNear = {}
    for address in pairs(skipped) do
        local peer = self.peers[address]
        if peer and peer.hash and peer.hash ~= self:HashText() then
            self:ConsiderSession(address, peer)
        end
    end
end

-- True when parts of long messages from `address` are expected: from the session's peer, or the one that just ended,
-- also while a new session runs (Comm drops every other part before buffering it, part 3 FR-010).
function Node:ExpectsParts(address)
    local session, recent = self.session, self.recent
    return (session ~= nil and session.peer == address)
        or (recent ~= nil and recent.peer == address and self.env.now() - recent.finished < SESSION_TIMEOUT)
end

function Node:DropSessionWith(address)
    if self.session and self.session.peer == address then
        self:DropSession()
    end
end

-- The sender flooded or sent bad data: ignored until logout, also after the peer bound forgot it.
function Node:Ignore(address, peer)
    if not peer.ignored then
        peer.ignored = true
        self.rejected = self.rejected + 1
    end
    self.ignored[address] = true
    self:DropSessionWith(address)
end

function Node:Confirmed(peer)
    local now = self.env.now()
    peer.synced = now
    self.lastExchange = now
end

-- A record of the own ID as sent, or false and why when a peer would not take it: its proof not ready yet (the
-- chain's marks are still being built), without cells of a game version (a build the game gave no version for is
-- left out), refused by the check (over the place limit) or over MAX_RECORD_BYTES encoded. Encoded once per version
-- of each unit.
function Node:OwnData(record)
    if ns.CatchDB.IsBlocked(record.id) then
        return false, "blocked by the bundled data" -- peers refuse it (FR-020); it still counts for this player
    end
    local unit = UnitOf(record)
    local cached = self.ownData[unit]
    if not cached or cached.seq ~= record.seq or cached.proof ~= record.proof then
        local outgoing, data, problem = Store.ForSending(record), false, nil
        if not IsProof(record.proof) then
            problem = "proof not ready"
        elseif not ns.CatchDB.HasCells(outgoing) then
            problem = "no cells to send"
        elseif not ns.CatchDB.CheckRecord(outgoing) then
            problem = "a peer's check would refuse it"
        else
            data = self.env.encode(outgoing) or false
            if not data or #data > MAX_RECORD_BYTES then
                data, problem = false, "too large for a peer"
            end
        end
        cached = { seq = record.seq, proof = record.proof, data = data, problem = problem }
        self.ownData[unit] = cached
    end
    return cached.data, cached.problem
end

function Node:Finish(session)
    if self.session == session then
        self.session = nil
    end
    local peer = self.peers[session.peer]
    if peer then
        self:Confirmed(peer)
        -- Nothing wanted either way, yet the hashes differ (another bundled seed, an evicted record): the same
        -- session would move nothing again until one side changes.
        local moved = next(session.ourWants) ~= nil or (session.theirWants and #session.theirWants > 0)
        peer.idle = not moved and session.gotDiff and { theirs = peer.hash, ours = self:HashText() } or nil
        -- Nothing came, and the budget held back every record the peer wanted: the same session would only repeat
        -- (its SUM, DIFF and WANT) until the budget has room for the first one. Only for a peer whose HELLO says what
        -- it holds: one that only whispered may have changed unseen.
        if next(session.ourWants) == nil and session.heldBack and peer.hash then
            peer.idle = { theirs = peer.hash, ours = self:HashText(), room = session.heldBack }
        end
    end
    session.finished = self.env.now()
    self.recent = session -- records still on their way are taken for a while
    self:Reconsider()
end

-- The session a message belongs to: the running one, or (for late records) the one that just ended.
function Node:SessionFor(address, sid, late)
    local session = self.session
    if session and session.peer == address and session.sid == sid then
        return session
    end
    session = self.recent
    if late and session and session.peer == address and session.sid == sid
        and self.env.now() - session.finished < SESSION_TIMEOUT then
        return session
    end
end

function Node:ArmTimeout(session, delay)
    self.env.after(delay or SESSION_TIMEOUT, function()
        if self.session ~= session then
            return
        end
        local now = self.env.now()
        if self.env.busy and self.env.busy(session.peer) then
            session.lastHeard = now -- our own messages are still going out
        end
        local quiet, age = now - session.lastHeard, now - session.started
        if quiet >= SESSION_TIMEOUT or age >= SESSION_MAX_LIFE then
            self:DropSession()
            local peer = self.peers[session.peer]
            if peer then
                peer.pausedUntil = now + PEER_PAUSE
            end
        else
            self:ArmTimeout(session, math.min(SESSION_TIMEOUT - quiet, SESSION_MAX_LIFE - age))
        end
    end)
end

-- True when the addresses are one client: the same address, or the same node tag on its other path (guild and
-- Battle.net).
function Node:SameClient(a, b)
    if a == b then
        return true
    end
    local peerA, peerB = self.peers[a], self.peers[b]
    return peerA ~= nil and peerB ~= nil and peerA.node ~= nil and peerA.node == peerB.node
end

-- True when a near (guild, group or friend) peer that cannot start now must be considered again once the pause, or a
-- session or a recent start with another client, is over (skippedNear, Reconsider). Not for one with the same client
-- (also by its other address): that exchanges what this start would.
function Node:WaitsForOther(address, peer, now)
    if peer.via == "channel" then
        return false
    end
    if self.paused then
        return true
    end
    if self.session then
        return not self:SameClient(self.session.peer, address)
    end
    return self.lastStart ~= nil and now - self.lastStart < SESSION_GAP
        and not self:SameClient(self.lastStartWith, address)
end

-- True while a session with the peer would move nothing again: neither side changed since the last one, which moved
-- nothing, or whose records the budget held back and still would.
function Node:Idle(peer)
    local idle = peer.idle
    return idle ~= nil and idle.theirs == peer.hash and idle.ours == self:HashText()
        and (not idle.room or not self.env.canSend(idle.room))
end

function Node:CanStart(address, peer, now)
    if self.paused or self.session or peer.ignored or not self.env.canSend() then
        return false
    end
    if (self.lastStart and now - self.lastStart < SESSION_GAP) or (peer.pausedUntil and now < peer.pausedUntil) then
        return false
    end
    if self:Idle(peer) then
        return false
    end
    local cooldown = peer.via == "group" and GROUP_COOLDOWN or OTHER_COOLDOWN
    if peer.lastSession and now - peer.lastSession < cooldown then
        return false
    end
    -- The same client by its other address (guild and Battle.net) had a session just now: its cooldown holds too. A
    -- channel stranger has one address (and its tag may match another stranger's by chance).
    if peer.node and peer.via ~= "channel" then
        for other, otherPeer in pairs(self.peers) do
            if other ~= address and otherPeer.via ~= "channel" and otherPeer.node == peer.node and otherPeer.lastSession
                and now - otherPeer.lastSession < cooldown then
                return false
            end
        end
    end
    return true
end

function Node:HashText()
    return self:Summary(true).wholeText
end

-- Only the hearer of a HELLO starts a session, after a random wait, if it is still needed then.
function Node:ConsiderSession(address, peer)
    local now = self.env.now()
    if peer.starting then
        return
    end
    if not self:CanStart(address, peer, now) then
        if self:WaitsForOther(address, peer, now) then
            self.skippedNear[address] = true -- again when it is over
            self:Reconsider()
        end
        return
    end
    peer.starting = true
    self.env.after(self.env.random(START_DELAY_MIN, START_DELAY_MAX), function()
        peer.starting = nil
        local now = self.env.now()
        if self.peers[address] ~= peer or peer.hash == self:HashText() then
            return
        end
        if peer.via == "channel" and self:NearWaiting(now) then
            return -- a near peer heard in the start delay goes first (research R5 of part 3)
        end
        if not self:CanStart(address, peer, now) then
            -- A pause, or a session or a start with another client in the start delay (a channel stranger's SUM).
            if self:WaitsForOther(address, peer, now) then
                self.skippedNear[address] = true
                self:Reconsider()
            end
            return
        end
        local sid = ns.RandomBase32(2, self.env.random)
        local text = "S" .. sid .. " " .. table.concat(self:Summary().hashTexts)
        if not self.env.canSend(#text) then
            return -- the budget: no session, no BYE to a peer that heard of none, the cooldowns stay free
        end
        local session = self:NewSession(sid, address, "initiator")
        if not self:Send(address, text) then
            return -- a path left out: no session ran, the cooldowns stay free for the next HELLO
        end
        self.lastStart, self.lastStartWith = now, address
        peer.previousSession, peer.lastSession = peer.lastSession, now
        self:ArmTimeout(session)
    end)
end

local Handlers = {}

function Handlers.H(self, address, peer, via, text)
    local tag, hash = text:match("^H (%w%w%w%w) %d+ %d+ (%w+)$")
    if not tag or tag == self.tag then
        return -- malformed, or our own broadcast echoing back
    end
    local now = self.env.now()
    if via == "channel" then
        -- Heard announcing in the channel (Channel.lua tells a lock from its undo with it), also when the HELLO goes
        -- no further below (too soon after its guild one, or the same client by another path).
        self:Announced(address, now)
    end
    local first = self.byTag[tag]
    local other = first and first ~= address and self.peers[first]
    if other and other.heard and now - other.heard < ALONE_AFTER then
        -- The same client by another path is one peer. Its tag is noted on this address too, so a SUM from here is
        -- told from a stranger's; only for the other kind of address (a client has one whisper and at most one
        -- Battle.net address), so a tag heard in the guild cannot be used from another name to take over a session.
        if address:sub(1, 1) ~= first:sub(1, 1) then
            peer.node = tag
        end
        return
    end
    if peer.heard and now - peer.heard < HELLO_LIMIT then
        if via == "group" or (via ~= "channel" and peer.via == "channel") then
            self:SetVia(address, peer, via) -- a guild member in the group: the group's shorter cooldown
        end
        return
    end
    self.byTag[tag] = address
    local heard -- channel HELLOs in the last CHANNEL_WINDOW minutes, this one included
    if via == "channel" then
        heard = ns.CountRecent(self.channelHeard, now, 1, CHANNEL_WINDOW)
    end
    self:SetVia(address, peer, via)
    peer.node, peer.hash, peer.heard, peer.busyRetried = tag, hash, now, nil
    peer.pausedUntil = nil -- a peer that timed out (a pause on its side) is back
    if hash == self:HashText() then
        self:RefreshSeen(nil) -- the same database: nothing to exchange, every record confirmed
        self:Confirmed(peer)
        return
    end
    -- A stranger from the channel: only by chance (about CHANNEL_TARGET of all hearers start), and not while a near
    -- peer could start a session now (research R5 of part 3).
    if peer.via == "channel" then -- only when this HELLO came by the channel (SetVia never makes a peer one otherwise)
        if self.env.random() >= math.min(1, CHANNEL_TARGET / math.max(1, heard or 0)) or self:NearWaiting(now) then
            return
        end
    end
    self:ConsiderSession(address, peer)
end

-- True when a guild, group or friend peer heard in the last NEAR_WINDOW with another database is about to get a
-- session: its start is armed, its busy retry is due, or it waits in skippedNear for a session or a start to be over.
-- One that nothing will start a session with (in its cooldown, paused, idle, refused busy twice) does not keep the
-- channel waiting.
function Node:NearWaiting(now)
    local mine = self:HashText()
    for address, peer in pairs(self.peers) do
        if peer.via ~= "channel" and peer.heard and now - peer.heard < NEAR_WINDOW and peer.hash ~= mine
            and (peer.starting or peer.retrying or self.skippedNear[address]) then
            return true
        end
    end
    return false
end

function Handlers.S(self, address, peer, _, text)
    local sid, hashes = text:match("^S(%w%w) (%w+)$")
    if not sid or #hashes ~= 7 * #ns.BASE32 then
        return
    end
    local session = self.session
    if session then
        -- The session's peer, also when its SUM came by the client's other address (guild and Battle.net).
        local sessionPeer = self.peers[session.peer]
        if not self:SameClient(session.peer, address) or session.role ~= "initiator" or session.gotReply then
            self:Bye(address, sid, "busy")
            return
        end
        -- Crossing SUMs: the smaller node tag stays the initiator, the other answers; equal tags both give way.
        if peer.node and self.tag < peer.node then
            return
        end
        self:DropSession()
        if peer.node == self.tag then
            if sessionPeer then
                sessionPeer.lastSession = sessionPeer.previousSession -- no session follows
            end
            return
        end
        -- A session follows as the responder: the cooldown stays on the address the dropped one was for, and the
        -- responder's goes on this one, so the client gets no second session by its other address.
    end
    if peer.answered and self.env.now() - peer.answered < RESPONDER_GAP then
        self:Bye(address, sid, "busy")
        return
    end
    if not self.env.canSend() or (self:Idle(peer) and peer.idle.room) then
        self:Bye(address, sid, "limit")
        return
    end
    session = self:NewSession(sid, address, "responder")
    peer.lastSession = self.env.now()
    local summary = self:Summary()
    local equal, differing = {}, {}
    for i = 1, #ns.BASE32 do
        if hashes:sub(i * 7 - 6, i * 7) == summary.hashTexts[i] then
            equal[i] = true
        else
            table.insert(differing, i)
        end
    end
    self:RefreshSeen(equal)
    if #differing == 0 then
        self:Bye(address, sid, "done")
        self:Finish(session)
        return
    end
    session.buckets = differing
    peer.answered = self.env.now()
    self:SendDiff(session)
    self:ArmTimeout(session)
end

function Node:SendDiff(session)
    local summary, chars, entries = self:Summary(true), {}, {}
    for _, index in ipairs(session.buckets) do
        table.insert(chars, ns.BASE32:sub(index, index))
        for _, line in ipairs(summary.buckets[index]) do
            table.insert(entries, line)
        end
    end
    local text = "D" .. session.sid .. " " .. table.concat(chars)
    return self:Send(session.peer, #entries > 0 and (text .. " " .. table.concat(entries, " ")) or text)
end

-- Not wanted: the own ID (the own record changes only by fishing), units the seed already holds and versions
-- evicted for the size limit.
function Node:Wanted(unit, seq)
    local id = ns.CatchDB.ParseUnit(unit)
    local refused = self.chainRefused[unit .. "." .. seq]
    return id ~= self.store.myID and not Absorbed(self.env.absorbed(), unit, seq)
        and not WasEvicted(self.store, unit, seq) and not ns.CatchDB.IsBlocked(id)
        and not (refused and refused == self.store.records[unit])
end

function Handlers.D(self, address, _, _, text)
    local sid, rest = text:match("^D(%w%w) (%S.*)$")
    local session = sid and self:SessionFor(address, sid)
    if not session or session.gotDiff then
        return
    end
    session.lastHeard, session.gotReply = self.env.now(), true
    local words = {}
    for word in rest:gmatch("%S+") do
        table.insert(words, word)
    end
    local buckets, indices = {}, {}
    for char in words[1]:gmatch(".") do
        local index = ns.BASE32:find(char, 1, true)
        if not index then
            return
        end
        buckets[index] = true
        table.insert(indices, index)
    end
    if session.role == "responder" then
        buckets = {}
        for _, index in ipairs(session.buckets) do
            buckets[index] = true
        end
    end
    local summary, equal = self:Summary(true), {}
    for i = 2, #words do
        local id, epoch, seq = words[i]:match("^([a-z2-7]+)%.(%d+)%.(%d+)$")
        if id and #id == ns.CatchDB.ID_LENGTH and buckets[BucketIndex(id)] then
            local unit, mine = id .. "@" .. epoch, summary.units[id .. "@" .. epoch]
            seq = tonumber(seq)
            if mine == seq then
                equal[unit] = true
            elseif (not mine or mine < seq) and self:Wanted(unit, seq) then
                session.ourWants[unit] = seq
            end
        end
    end
    self:Touch(equal)
    session.gotDiff = true
    if session.role == "initiator" then
        session.buckets = indices
        if not self:SendDiff(session) or not self:SendWant(session) then
            return
        end
    end
    self:Advance(session)
end

function Node:SendWant(session)
    local units = {}
    for unit in pairs(session.ourWants) do
        table.insert(units, unit)
    end
    table.sort(units)
    session.sentWant, session.wantCount = true, #units -- more records than this from the peer is a flood
    return self:Send(session.peer, "W" .. session.sid .. (#units > 0 and (" " .. table.concat(units, " ")) or ""))
end

function Handlers.W(self, address, _, _, text)
    local sid, rest = text:match("^W(%w%w) ?(.*)$")
    local session = sid and self:SessionFor(address, sid)
    if not session or session.theirWants then
        return
    end
    session.lastHeard = self.env.now()
    local summary, wants = self:Summary(true), {}
    for unit in rest:gmatch("%S+") do
        if summary.units[unit] then
            table.insert(wants, unit)
        end
    end
    session.theirWants = wants
    self:Advance(session)
end

-- The records the peer wants: the own one first, then the newest seen, within SESSION_BYTES (at least one).
function Node:SendRecords(session)
    local own = OwnRecord(self.store)
    local ownUnit = own and UnitOf(own)
    local wants, seen = session.theirWants, {}
    for _, unit in ipairs(wants) do
        local record = self.store.records[unit]
        seen[unit] = unit == ownUnit and math.huge or (record and tonumber(record.seen) or 0)
    end
    table.sort(wants, function(a, b)
        if seen[a] ~= seen[b] then
            return seen[a] > seen[b]
        end
        return a < b
    end)
    local sent, count = 0, 0
    for _, unit in ipairs(wants) do
        if count >= SESSION_RECORDS then
            break -- the rest comes in a later session
        end
        -- Those of the own ID only go when a peer takes them. Others' records passed the check when they were
        -- stored, and are checked again: one damaged in the saved file since would get this client ignored by the
        -- peer, so it is dropped instead.
        local record, data = Store.Get(self.store, unit), nil
        if record and record.id == self.store.myID then
            data = self:OwnData(record)
        elseif record and not Pending(self.store, unit, record) then
            if ns.CatchDB.CheckRecord(record) then
                data = self.env.encode(Store.ForSending(record))
            else
                self.store.records[unit] = nil
                Changed(self.store, { unit })
            end
        end
        if data and #data <= MAX_RECORD_BYTES then
            -- Within the session size, and only what the budget still lets go out whole: checked once, on the text
            -- as it goes out, so Node:Send never ends the session with BYE limit here; the records just end, and
            -- the rest comes in a later session. A failed send ended the session: nothing more goes.
            local text = "R" .. session.sid .. " " .. data
            if sent > 0 and sent + #data > SESSION_BYTES then
                break
            end
            if not self.env.canSend(#text) then
                session.heldBack = count == 0 and #text or nil -- the room the first record waits for
                break
            end
            if not self:Send(session.peer, text) then
                break
            end
            sent, count = sent + #data, count + 1
        end
    end
end

-- Does the next step of a session once everything it waits for has arrived (Battle.net may reorder messages).
function Node:Advance(session)
    if self.session ~= session then
        return
    end
    if session.role == "responder" then
        if session.gotDiff and session.theirWants and not session.sentWant then
            if not self:SendWant(session) then
                return
            end
            self:SendRecords(session)
            if self.session == session then -- not ended by the budget
                self:Bye(session.peer, session.sid, "sent")
            end
        end
    elseif session.theirWants and session.gotSent and not session.sentRecords then
        session.sentRecords = true
        self:SendRecords(session)
        if self.session == session then -- not ended by the budget
            self:Bye(session.peer, session.sid, "done")
            self:Finish(session)
        end
    end
end

function Handlers.B(self, address, peer, _, text)
    local sid, reason = text:match("^B(%w%w) (%a+)$")
    local session = sid and self:SessionFor(address, sid)
    if not session then
        return
    end
    session.lastHeard, session.gotReply = self.env.now(), true
    if reason == "sent" then
        session.gotSent = true
        self:Advance(session)
    elseif reason == "done" then
        if not session.gotDiff then
            self:RefreshSeen(nil) -- every bucket was equal
        end
        self:Finish(session)
    else -- busy, limit or an unknown reason: the peer tries again after the next HELLO
        self:DropSession()
        if reason == "busy" then
            peer.lastSession = peer.previousSession
            if peer.via ~= "channel" and not peer.busyRetried then
                -- A near peer is tried again once soon (part 3, FR-007): a channel session may be what kept it busy.
                peer.busyRetried, peer.retrying = true, true
                self.env.after(self.env.random(BUSY_RETRY_MIN, BUSY_RETRY_MAX), function()
                    peer.retrying = nil
                    if self.peers[address] == peer and peer.hash and peer.hash ~= self:HashText() then
                        self:ConsiderSession(address, peer)
                    end
                end)
            end
        end
    end
end

function Handlers.R(self, address, peer, _, text)
    local sid, data = text:match("^R(%w%w) (.+)$")
    local session = sid and self:SessionFor(address, sid, true)
    if not session then
        return
    end
    local now = self.env.now()
    session.lastHeard = now
    session.recordsIn = (session.recordsIn or 0) + 1
    if session.recordsIn > (session.wantCount or 0) or Recent(peer.records, now, 1) > RECORD_LIMIT
        or #data > MAX_RECORD_BYTES or not data:find("^[A-Za-z0-9+/=]+$") then
        self:Ignore(address, peer)
        return
    end
    table.insert(self.merges, { address = address, peer = peer, session = session, data = data })
    self:ScheduleMerge()
end

-- Received records are decoded, checked and stored one per frame step (SC-006).
function Node:ScheduleMerge()
    if self.merging or #self.merges == 0 then
        return
    end
    self.merging = true
    self.env.after(0, function()
        self.merging = false
        local item = self.merges[1]
        -- Data no check foresaw must not stop the merges or reach the player as a Lua error.
        if not pcall(self.MergeOne, self) and item then
            self:Ignore(item.address, item.peer)
        end
        self:ScheduleMerge()
    end)
end

-- Decodes and checks a received record: false for broken or unwanted data, true when it is ready to store
-- (item.record), or "more" when a newer version's chain still has to be walked (item.verify keeps the state).
function Node:MergeStart(item)
    local record = self.env.decode(item.data)
    local unit = UnitOf(record)
    local session = item.session
    if not (unit and session.ourWants[unit] and not session.received[unit]) or record.id == self.store.myID
        or not ns.CatchDB.CheckRecord(record) then
        return false
    end
    session.received[unit] = true
    local held = Store.HeldFor(self.store, record, self.env.absorbed())
    if held and record.seq > held.seq then
        item.verify = { held = held, record = record }
        return "more"
    end
    item.record = record
    return true
end

-- Stores a checked record; false when the store refuses it.
function Node:MergeStore(record)
    local result, reason = Store.Accept(self.store, record, self.env.time(), self.env.absorbed(), true)
    if result == "new" or result == "newer" then
        Store.Evict(self.store)
    end
    return result ~= "refused" or reason == "blocked" -- a blocked ID is no fault of the sender (FR-020)
end

-- One frame step of the merge queue: a record's decode and check, or PROOF_STEPS links of its chain (a record whose
-- chain is longer keeps the front of the queue), then its store.
function Node:MergeOne()
    local item = table.remove(self.merges, 1)
    if not item or item.peer.ignored then
        return
    end
    local clock = self.env.clock
    local started = clock and clock()
    -- VERIFY(V16): one decode, check and merge per frame step stays smooth with 20,000 stored places
    local ok
    if item.verify then
        local verify = item.verify
        local result, state = ns.CatchDB.CheckVersion(verify.held, verify.record, PROOF_STEPS, verify.state)
        if result == "more" then
            verify.state = state
            table.insert(self.merges, 1, item)
            ok = true
        elseif result == "ok" then
            ok = self:MergeStore(verify.record)
        else
            -- Refused either way, but only the seed's proof shows the sender wrong: a stored version may be a made-up
            -- copy taken first (research R9), and then the one relaying the owner's real version is no forger. That
            -- version is not wanted again while the copy is held (it would fail the same way); another seq still is,
            -- since the forgery may be this version and not the copy.
            if not verify.held.seed then
                self.chainRefused[UnitOf(verify.record) .. "." .. verify.record.seq] = verify.held
            end
            ok = not verify.held.seed
        end
    else
        ok = self:MergeStart(item)
        if ok == "more" then
            table.insert(self.merges, 1, item)
        elseif ok then
            ok = self:MergeStore(item.record)
        end
    end
    if not ok then
        self:Ignore(item.address, item.peer) -- broken, unwanted or invalid
    end
    local finished = clock and clock()
    if started and finished then
        self.longestStep = math.max(self.longestStep, finished - started)
    end
end

function Node:Receive(address, via, text)
    if self.paused or type(text) ~= "string" or text == "" then
        return
    end
    local peer = self:Peer(address, via)
    if peer.ignored then
        return
    end
    if Recent(peer.messages, self.env.now(), math.max(1, math.ceil(#text / MESSAGE_UNIT))) > MESSAGE_LIMIT then
        self:Ignore(address, peer)
        return
    end
    if via == "channel" and text:sub(1, 1) ~= "H" then
        return -- the channel carries HELLO only; sessions go by whisper (counted above: a flooder is ignored, FR-010)
    end
    local handler = Handlers[text:sub(1, 1)]
    if handler then
        handler(self, address, peer, via, text) -- unknown types are ignored
    end
end

-- A part of a long message arrived from `address`: the peer is still there.
function Node:Heard(address)
    if self.session and self.session.peer == address then
        self.session.lastHeard = self.env.now()
    end
end

-- A send to `address` reported the player offline.
function Node:Offline(address)
    self:DropSessionWith(address)
    local peer = self.peers[address]
    if peer then
        peer.pausedUntil = self.env.now() + PEER_PAUSE
    end
end

-- Drops the running session (without a message: the peer times out) and the records not merged yet: nothing
-- received is kept while paused or off.
function Node:Pause(reason)
    self.paused = reason
    self:DropSession()
    wipe(self.merges)
end

function Node:Resume()
    self.paused = nil
    self:Reconsider()
end

-- A HELLO to the hidden public channel (part 3; the rounds of research R5).
function Node:ChannelHello()
    if self.paused or not self.env.channelBroadcast or not self.env.canSend() then
        return
    end
    self.env.channelBroadcast(self:HelloText())
end

-- The HELLO as it goes out (on the wire "H <node tag> <epoch> <count> <hash>").
function Node:HelloText()
    local summary = self:Summary()
    return ("H %s %d %d %s"):format(self.tag, self.env.seedEpoch(), summary.count, self:HashText())
end

-- A HELLO round: the guild and the group, then up to FRIENDS_PER_ROUND friends, those known as peers first and
-- the rest in turn from a cursor that moves on each round (research R3).
function Node:Hello()
    if self.paused or not self.env.canSend() then
        return false
    end
    local text = self:HelloText()
    self.env.broadcast(text)
    local known, others = {}, {}
    self.env.forEachFriend(function(address)
        local peer = self.peers[address]
        if not (peer and peer.ignored) then
            table.insert(peer and peer.node and known or others, address)
        end
    end)
    local greeted = 0
    for _, address in ipairs(known) do
        if greeted >= FRIENDS_PER_ROUND then
            break
        end
        self.env.send(address, text, "greeting")
        greeted = greeted + 1
    end
    if #others > 0 then
        local start = (self.cursor - 1) % #others
        local count = math.min(#others, FRIENDS_PER_ROUND - greeted)
        for i = 0, count - 1 do
            self.env.send(others[(start + i) % #others + 1], text, "greeting")
        end
        self.cursor = start + count + 1
    end
    self.lastHello = self.env.now()
    return true
end

local function NoActivity()
    return { heard = { guild = 0, group = 0, friend = 0, bnet = 0, channel = 0 }, exchanged = 0, recent = false }
end

-- The peers of the last hour: heard per path, exchanged with, anybody in the last 30 minutes, the last exchange.
function Node:Activity()
    local now, activity = self.env.now(), NoActivity()
    for _, peer in pairs(self.peers) do
        if peer.heard and now - peer.heard < HOUR then
            local path = peer.via == "whisper" and "friend" or peer.via
            activity.heard[path] = (activity.heard[path] or 0) + 1
        end
        activity.recent = activity.recent or (peer.heard ~= nil and now - peer.heard < ALONE_AFTER)
        if peer.synced and now - peer.synced < HOUR then
            activity.exchanged = activity.exchanged + 1
        end
    end
    activity.lastExchange = self.lastExchange and now - self.lastExchange
    return activity
end

function Node:Status()
    local status, summary = self:Activity(), self:Summary(true)
    status.records, status.places = summary.count, summary.places
    status.channelPeers = self.channelCount
    status.population = ns.CountRecent(self.channelHeard, self.env.now(), 0, CHANNEL_WINDOW)
    status.rejected, status.longestStep = self.rejected, self.longestStep
    status.session, status.merges = self.session ~= nil, #self.merges
    return status
end

---------------------------------------------------------------------------
-- The game node
---------------------------------------------------------------------------
local NOTICE_POPUP = "ONEKEYFISHING_SHARE_NOTICE"
Share.NOTICE_POPUP = NOTICE_POPUP -- shown by UI/ShareNotice.lua
local node
local commPause -- the last SHARE_PAUSE reason
local lastExtraHello
local groupSize = 0

local function HomeGroupSize()
    return IsInGroup(LE_PARTY_CATEGORY_HOME) and GetNumGroupMembers(LE_PARTY_CATEGORY_HOME) or 0
end

function Share.IsEnabled()
    return ns.db.settings.shareDB == true
end

local function Hello()
    if node then
        node:Hello()
    end
end

-- One extra HELLO at a time: pauses or group changes in a row do not stack their timers.
local helloPending = false

local function HelloSoon()
    if helloPending then
        return
    end
    helloPending = true
    C_Timer.After(math.random(EXTRA_HELLO_MIN, EXTRA_HELLO_MAX), function()
        helloPending = false
        Hello()
    end)
end

local function Round()
    Hello()
    C_Timer.After(math.random(ROUND_MIN, ROUND_MAX), Round)
end

-- The node pauses for the setting or Comm's reason, and greets again soon when a pause ends.
local function SyncPause()
    if not node then
        return
    end
    local reason = not Share.IsEnabled() and "off" or commPause
    local was = node.paused
    if reason then
        node:Pause(reason)
    elseif was then
        node:Resume()
        if was ~= "off" and (not node.lastHello or GetTime() - node.lastHello > HELLO_STALE) then
            HelloSoon()
        end
    end
end

local function DebugClock()
    local ms = debugprofilestop and debugprofilestop()
    return type(ms) == "number" and ms or nil
end

-- Starts the exchange once the popup was closed (or at login when it was closed before).
local function Start()
    if node or not ns.db.shareNotice then
        return
    end
    node = Share.NewNode(ns.db.shared, {
        now = GetTime,
        time = time,
        after = C_Timer.After,
        send = ns.Comm.Send,
        broadcast = ns.Comm.Broadcast,
        channelBroadcast = ns.Comm.ChannelBroadcast,
        forEachFriend = ns.Comm.ForEachFriend,
        canSend = ns.Comm.CanSend,
        busy = ns.Comm.IsSending,
        absorbed = SeedAbsorbed,
        seedEpoch = ns.CatchDB.SeedEpoch,
        encode = Share.Encode,
        decode = Share.Decode,
        prepare = ns.CatchDB.FlushSeq,
        clock = DebugClock,
    })
    ns.Comm.OnReceive(function(address, via, text) node:Receive(address, via, text) end)
    ns.Comm.OnActivity(function(address) node:Heard(address) end)
    ns.Comm.OnOffline(function(address) node:Offline(address) end)
    ns.Comm.SetPartFilter(function(address) return node:ExpectsParts(address) end)
    ns.Comm.OnFlood(function(address) node:Ignore(address, node:Peer(address, "whisper")) end)
    commPause = ns.Comm.GetPause()
    groupSize = HomeGroupSize()
    SyncPause()
    C_Timer.After(math.random(FIRST_HELLO_MIN, FIRST_HELLO_MAX), Round)
end

-- True while a notice is owed: the part 2 one, or (while the release has the channel) the one that names it, which a
-- player who closed the part 2 notice in an earlier release gets once more (FR-022). Channel.lua waits for it too.
local function NoticeOwed()
    return not ns.db.shareNotice or (ns.Channel.AVAILABLE and not ns.db.shareNoticeChannel)
end
Share.NoticeOwed = NoticeOwed

-- Closing the notice (any button, Escape, or a setting changed on the page that says what is shared): the exchange
-- starts, and while the release has the channel its notice counts as read too (part 3, FR-022).
local function NoticeRead()
    ns.db.shareNotice = true
    if ns.Channel.AVAILABLE then
        ns.db.shareNoticeChannel = true
    end
    Start()
    ns.Channel.Update()
end
Share.NoticeRead = NoticeRead

-- A setting changed on the page that says what is shared (the exchange's or the channel's) counts as reading the
-- notice: the popup goes and the exchange starts.
function Share.CloseNotice()
    if NoticeOwed() then
        StaticPopup_Hide(NOTICE_POPUP)
        NoticeRead()
    end
end

-- Turns the exchange on or off: off sends and accepts nothing and leaves other players' records out of the
-- views (they stay saved); on counts them again at once and greets soon. The player set it on the page that says
-- what is shared, so the one-time popup is not needed any more.
function Share.SetEnabled(on)
    ns.db.settings.shareDB = on and true or false
    Share.CloseNotice()
    SyncPause()
    if on and node then
        HelloSoon()
    end
    ns.Fire("SHARED_DATA_CHANGED")
    ns.Fire("SETTINGS_CHANGED", "shareDB")
end

ns.On("SHARE_PAUSE", function(reason)
    commPause = reason
    SyncPause()
end)

ns.RegisterEvent("GROUP_ROSTER_UPDATE", function()
    local size = HomeGroupSize()
    local grew = size > groupSize
    groupSize = size
    if not node or not grew or (lastExtraHello and GetTime() - lastExtraHello < EXTRA_HELLO_GAP) then
        return
    end
    lastExtraHello = GetTime()
    HelloSoon()
end)

ns.RegisterEvent("ADDON_LOADED", function(_, loadedName)
    if loadedName ~= "OneKeyFishing" or not ns.db then
        return
    end
    Store.CleanUp(ns.db.shared)
    Store.Evict(ns.db.shared)
    -- Copies of units the seed holds in part must continue the seed's proof: walked in the background.
    local work = Store.SeedChainWork(ns.db.shared)
    local function Step()
        if not Store.CheckSeedChains(ns.db.shared, work, PROOF_STEPS) then
            C_Timer.After(0, Step)
        end
    end
    if #work > 0 then
        C_Timer.After(0, Step)
    end
end)

ns.RegisterEvent("PLAYER_LOGIN", Start)

-- Channel HELLO rounds (research R5 of part 3): the first 30-90 s after joining (also the same channel again, after a
-- kick, a slot given back or the setting turned off and on), then every 30-50 min, and 5-30 s after a move to another
-- channel; a round outside the channel sends nothing, but checks the free slots again.
local channelRound, channelIndex, channelJoins

local function ChannelRound(token)
    if token ~= channelRound then
        return
    end
    if node and ns.Channel.GetState() == "in" then
        node:ChannelHello()
    end
    ns.Channel.CheckSlots()
    C_Timer.After(math.random(CHANNEL_ROUND_MIN, CHANNEL_ROUND_MAX), function() ChannelRound(token) end)
end

ns.On("CHANNEL_STATE", function(state, index, joins)
    -- Only a new join starts a round: the end of a pause on the same join is none (the client stayed in the channel,
    -- and its round goes on), a join completed during a pause is one.
    if state ~= "in" or joins == channelJoins then
        return
    end
    local moved = channelIndex ~= nil and index ~= channelIndex
    channelIndex, channelJoins = index, joins
    local token = {}
    channelRound = token
    C_Timer.After(moved and math.random(CHANNEL_MOVE_MIN, CHANNEL_MOVE_MAX)
        or math.random(CHANNEL_FIRST_MIN, CHANNEL_FIRST_MAX), function() ChannelRound(token) end)
end)

-- True when a player of that name (with or without the realm) announced in the channel this session.
function Share.HeardInChannel(name)
    if not node or type(name) ~= "string" or name == "" then
        return false
    end
    for address in pairs(node.announcers) do
        local sender = address:match("^w:(.+)$")
        if sender and ns.SameCharacter(sender, name) then
            return true
        end
    end
    return false
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
-- The status without a running node (before the popup was closed).
local function IdleStatus()
    local status = NoActivity()
    status.records, status.places = CountUnits(ns.db.shared, Store.Units(ns.db.shared))
    status.rejected, status.longestStep, status.session, status.merges = 0, 0, false, 0
    status.channelPeers, status.population = 0, 0
    return status
end

-- data-model.md "State of the exchange": off, notice, unavailable, paused (with the reason), alone or active.
-- Unavailable: every path left out, or nothing ever went out and every path tried was refused (Comm.Refused).
local function State(activity)
    local reason = ns.Comm.GetPause() or commPause
    if not Share.IsEnabled() then
        return "off"
    elseif not ns.db.shareNotice then
        return "notice"
    elseif reason == "unavailable" or ns.Comm.Refused() then
        return "unavailable"
    elseif reason then
        return "paused", reason
    end
    return activity.recent and "active" or "alone"
end

function Share.GetStatus()
    local status = node and node:Status() or IdleStatus()
    status.state, status.reason = State(status)
    status.traffic = ns.Comm.GetTraffic()
    status.channel, status.channelIndex = ns.Channel.GetState()
    status.blocked, status.ownBlocked = Store.blocked, ns.CatchDB.IsBlocked(ns.db.shared.myID)
    return status
end

-- The channel's line for /okf share and the settings page (contracts/channel.md "Texts"), nil while the release
-- ships without the channel. Built at runtime: the texts need the language.
function Share.ChannelLine()
    local state, index = ns.Channel.GetState()
    if state == "unavailable" then
        return nil
    elseif state == "in" then
        return index and index > 1 and L["Public channel: in use (fallback channel %d)"]:format(index)
            or L["Public channel: in use"]
    end
    local texts = {
        off = L["Public channel: off"],
        noslot = L["Public channel: no free chat channel slot"],
        locked = L["Public channel: locked or refused by the game"],
        left = L["Public channel: you left it, back at the next login"],
    }
    return texts[state] or L["Public channel: waiting"] -- notice and paused too: the exchange's own line says why
end

-- Built at runtime: the texts need the language, which is set after the files load.
local function PauseText(reason)
    local texts = {
        combat = L["Exchange paused: in combat"],
        instance = L["Exchange paused: in an instance"],
        loading = L["Exchange paused: loading screen"],
        restricted = L["Exchange paused: the game restricts addon messages here"],
        lockdown = L["Exchange paused: the game asked to slow down"],
    }
    return texts[reason] or texts.restricted
end

-- The short line for the tab and the settings page (every second: no counting of records).
function Share.StatusLine()
    local status = node and node:Activity() or NoActivity()
    local state, reason = State(status)
    if state == "off" then
        return L["Shared catch database is off"]
    elseif state == "notice" then
        return L["Waiting for you to read the notice"]
    elseif state == "unavailable" then
        return L["Exchange unavailable: the game refuses addon messages"]
    elseif state == "paused" then
        return PauseText(reason)
    elseif state == "alone" then
        return L["Nobody to exchange with right now"]
    elseif status.exchanged > 0 then
        return (L["Exchange: %d players, %s ago"]):format(status.exchanged,
            ns.Stats.FormatShortTime(status.lastExchange))
    elseif status.lastExchange then
        return (L["Last exchange: %s ago"]):format(ns.Stats.FormatShortTime(status.lastExchange))
    end
    return L["Exchange: waiting for the first exchange"]
end

-- /okf share: the full state in the interface language (FR-022).
function Share.PrintStatus()
    local status = Share.GetStatus()
    local epoch, seedPlaces = ns.CatchDB.SeedInfo()
    local heard = status.heard
    local heardLine
    if ns.Channel.AVAILABLE then
        heardLine = (L["Players heard in the last hour: guild %d, group %d, friends %d, Battle.net %d, channel %d"])
            :format(heard.guild, heard.group, heard.friend, heard.bnet, heard.channel)
    else
        heardLine = (L["Players heard in the last hour: guild %d, group %d, friends %d, Battle.net %d"]):format(
            heard.guild, heard.group, heard.friend, heard.bnet)
    end
    local lines = {
        (L["Bundled data: version %d, %d places"]):format(epoch, seedPlaces),
        (L["Records held: %d, %d places"]):format(status.records, status.places),
        heardLine,
        (L["Players exchanged with in the last hour: %d"]):format(status.exchanged),
        status.lastExchange and (L["Last exchange: %s ago"]):format(ns.Stats.FormatShortTime(status.lastExchange))
            or L["Last exchange: none yet"],
        (L["Traffic in the last hour: %d KB"]):format(math.ceil(status.traffic / 1024)),
        Share.StatusLine(),
    }
    local channel = Share.ChannelLine()
    if channel then
        table.insert(lines, channel)
    end
    ns.Print(L["Shared database"])
    for _, line in ipairs(lines) do
        DEFAULT_CHAT_FRAME:AddMessage("  " .. line)
    end
end

-- Whether the own record goes to peers, and why not (no cells of a game version, over 1,000 places or 32 KB
-- encoded); its size per place is what ROLL_PLACES (CatchDB.lua) was measured on.
local function OwnOffered()
    local own = node and OwnRecord(ns.db.shared)
    if not own then
        return "not yet"
    end
    local data, problem = node:OwnData(own)
    if not data then
        return "no, " .. problem
    end
    return ("yes, %d bytes encoded for %d places"):format(#data, ns.CatchDB.CountPlaces(own))
end

-- English lines for /okf debug (FR-023): no anonymous ID, no names.
function Share.Describe()
    local status = Share.GetStatus()
    local heard = status.heard
    return {
        ("state %s%s, setting %s, notice closed %s"):format(status.state,
            status.reason and (" (" .. status.reason .. ")") or "", tostring(Share.IsEnabled()),
            tostring(ns.db.shareNotice)),
        ("records %d, places %d"):format(status.records, status.places),
        ("heard in the last hour: guild %d, group %d, friend %d, bnet %d, channel %d; exchanged with %d"):format(
            heard.guild, heard.group, heard.friend, heard.bnet, heard.channel, status.exchanged),
        ("channel HELLOs in the last %d min (population) %d, channel peers kept %d"):format(CHANNEL_WINDOW,
            status.population, status.channelPeers),
        ("blocked by the bundled data: %d records refused or deleted, own ID blocked %s"):format(status.blocked,
            tostring(status.ownBlocked)),
        "version chain: " .. ns.CatchDB.ChainState(),
        "last exchange: " .. (status.lastExchange and (math.floor(status.lastExchange) .. " s ago") or "none"),
        ("rejected senders %d, session running %s, merges queued %d, longest merge step %.2f ms"):format(
            status.rejected, tostring(status.session), status.merges, status.longestStep),
        "own record offered: " .. OwnOffered(),
    }
end
