-- ShareNode: the protocol node of the catch exchange (Exchange/Share.lua): its summary, its peers, the session
-- lifecycle and the bounds on what it remembers. The messages themselves are in ShareProtocol.lua.
local _, ns = ...
local Share = ns.Share
local P = Share.private
local IsOther, IsProof = ns.CatchDB.IsOtherKey, ns.CatchDB.IsProof
local Store = Share.Store
local MAX_RECORD_BYTES, SESSION_TIMEOUT, SESSION_MAX_LIFE = P.MAX_RECORD_BYTES, P.SESSION_TIMEOUT, P.SESSION_MAX_LIFE
local PEER_PAUSE, SESSION_GAP, GROUP_COOLDOWN = P.PEER_PAUSE, P.SESSION_GAP, P.GROUP_COOLDOWN
local OTHER_COOLDOWN, START_DELAY_MIN, START_DELAY_MAX = P.OTHER_COOLDOWN, P.START_DELAY_MIN, P.START_DELAY_MAX
local FULL_REFRESH_GAP, MAX_CHANNEL_PEERS, MAX_ANNOUNCERS = P.FULL_REFRESH_GAP, P.MAX_CHANNEL_PEERS, P.MAX_ANNOUNCERS
local UnitOf, OtherPlaces, storeVersions, OwnRecord = P.UnitOf, P.OtherPlaces, P.storeVersions, P.OwnRecord
local BucketIndex = P.BucketIndex

---------------------------------------------------------------------------
-- The protocol node (contracts/sync-protocol.md)
---------------------------------------------------------------------------
-- A node's summary is current while both versions match: the store's own, bumped when Share changes that store, and
-- dataVersion, bumped by a SHARED_DATA_CHANGED from elsewhere (a roll of the own record, sharing switched). One
-- listener for every node, so a node of the tests is not kept alive by it, and a change in one test node's store
-- leaves the others' summaries alone.
local dataVersion = 0
ns.On("SHARED_DATA_CHANGED", function(_, store)
    if store == nil then
        dataVersion = dataVersion + 1
    end
end)

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

-- Shared with ShareProtocol.lua and ShareGame.lua through Share.private.
P.Node, P.CountUnits = Node, CountUnits
