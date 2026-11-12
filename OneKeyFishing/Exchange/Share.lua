-- Share: the catch exchange with the guild, the group and friends (part 2 of the shared catch database).
-- Other players' records are kept next to the own one in shared.records under "<id>@<epoch>" (the store below).
-- A protocol node finds peers (HELLO) and moves only the missing records between two clients (SUM, DIFF, WANT,
-- REC, BYE) over Comm.lua. The node gets its clock, scheduler and transport from `env`, so the tests run several
-- nodes over a fake network; the game makes one, bound to Comm. The state shows in the "What can be caught here"
-- tab, on the "Shared database" settings page, in /okf share and in /okf debug; a one-time popup tells the player
-- before anything is exchanged. Peers' names live only in memory.
-- See specs/003-guild-group-sync/contracts/share-api.md and sync-protocol.md.
-- The module spans four files (TOC order): this one (constants, the store, hashes, the codec), ShareNode.lua (the
-- protocol node: peers and sessions), ShareProtocol.lua (the messages and the merges) and ShareGame.lua (the one
-- node bound to Comm, the state); the one-time popup is UI/ShareNotice.lua.
local _, ns = ...

local Share = {}
ns.Share = Share
local P = {}
Share.private = P -- internals shared by the Exchange/Share*.lua files (not an API); exported at the end

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
-- A version chain is walked in chunks of PROOF_CHUNK links while a received record or a copy the seed holds in part is
-- checked, until PROOF_BUDGET_MS of the frame step are spent (research R9 of part 3, R3 of spec 010).
-- debugprofilestop measures ms; a proof step takes about 0.3 ms, and the longest merge step of a real exchange was
-- 3.10 ms (V26, seen in game)
local PROOF_CHUNK = 4
local PROOF_BUDGET_MS = 4
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

local storeVersions = setmetatable({}, { __mode = "k" })

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

-- Calls step() (one chunk of a chain walk, true while more is left) until it is done or another chunk, as long as the
-- last one took, would pass PROOF_BUDGET_MS since `started` on `clock`: at least once, and exactly once without a
-- clock. Returns true while more is left.
local function WithinBudget(clock, started, step)
    local more, before = nil, started
    repeat
        more = step()
        local now = more and started and clock()
        local stop = not now or now + (now - before) > started + PROOF_BUDGET_MS
        before = now
    until not more or stop
    return more
end
P.WithinBudget = WithinBudget

-- One frame step of the login check of the seed's copies (SeedChainWork): chunks within the budget. True when done.
function Store.CheckSeedStep(store, work, clock)
    return not WithinBudget(clock, clock and clock(), function()
        return not Store.CheckSeedChains(store, work, PROOF_CHUNK)
    end)
end

-- The eviction order by new information (specs/004-public-channel-sync, data-model.md "Eviction by new information"):
-- A, records about places the seed knows well, go first; then B, records no peer confirmed for long; then C; and D,
-- records about places with little data in the seed, go last.
local SATURATED_CATCHES = 1000 -- a place the seed holds this many catches of gains little from another record
local RARE_CATCHES = ns.CatchDB.LITTLE_DATA -- a place the seed holds fewer catches of (part 1's "little data"; no
-- seed cell counts too)
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

local OwnRecord = ns.CatchDB.OwnRecord -- the own record of a store, nil when missing or damaged

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
-- C_EncodingUtil round-trips a record, and the Base64 text holds only Base64 characters (V15, seen in game)
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

-- Shared with the other Exchange/Share*.lua files through Share.private; none of these is ever reassigned.
P.MAX_RECORD_BYTES, P.SESSION_BYTES, P.SESSION_TIMEOUT = MAX_RECORD_BYTES, SESSION_BYTES, SESSION_TIMEOUT
P.SESSION_MAX_LIFE, P.PEER_PAUSE, P.SESSION_GAP = SESSION_MAX_LIFE, PEER_PAUSE, SESSION_GAP
P.GROUP_COOLDOWN, P.OTHER_COOLDOWN, P.RESPONDER_GAP = GROUP_COOLDOWN, OTHER_COOLDOWN, RESPONDER_GAP
P.START_DELAY_MIN, P.START_DELAY_MAX, P.FRIENDS_PER_ROUND = START_DELAY_MIN, START_DELAY_MAX, FRIENDS_PER_ROUND
P.HELLO_LIMIT, P.SESSION_RECORDS, P.HOUR = HELLO_LIMIT, SESSION_RECORDS, HOUR
P.PROOF_CHUNK, P.PROOF_BUDGET_MS = PROOF_CHUNK, PROOF_BUDGET_MS
P.ALONE_AFTER, P.FIRST_HELLO_MIN, P.FIRST_HELLO_MAX = ALONE_AFTER, FIRST_HELLO_MIN, FIRST_HELLO_MAX
P.ROUND_MIN, P.ROUND_MAX, P.EXTRA_HELLO_MIN = ROUND_MIN, ROUND_MAX, EXTRA_HELLO_MIN
P.EXTRA_HELLO_MAX, P.EXTRA_HELLO_GAP, P.HELLO_STALE = EXTRA_HELLO_MAX, EXTRA_HELLO_GAP, HELLO_STALE
P.FULL_REFRESH_GAP, P.CHANNEL_TARGET, P.CHANNEL_WINDOW = FULL_REFRESH_GAP, CHANNEL_TARGET, CHANNEL_WINDOW
P.NEAR_WINDOW, P.BUSY_RETRY_MIN, P.BUSY_RETRY_MAX = NEAR_WINDOW, BUSY_RETRY_MIN, BUSY_RETRY_MAX
P.MAX_CHANNEL_PEERS, P.MAX_ANNOUNCERS, P.CHANNEL_FIRST_MIN = MAX_CHANNEL_PEERS, MAX_ANNOUNCERS, CHANNEL_FIRST_MIN
P.CHANNEL_FIRST_MAX, P.CHANNEL_ROUND_MIN = CHANNEL_FIRST_MAX, CHANNEL_ROUND_MIN
P.CHANNEL_ROUND_MAX, P.CHANNEL_MOVE_MIN, P.CHANNEL_MOVE_MAX = CHANNEL_ROUND_MAX, CHANNEL_MOVE_MIN, CHANNEL_MOVE_MAX
P.MESSAGE_UNIT, P.UnitOf, P.Absorbed, P.OtherPlaces = MESSAGE_UNIT, UnitOf, Absorbed, OtherPlaces
P.storeVersions, P.Changed, P.WasEvicted, P.Pending = storeVersions, Changed, WasEvicted, Pending
P.OwnRecord, P.BucketIndex = OwnRecord, BucketIndex
