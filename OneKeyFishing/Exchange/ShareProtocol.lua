-- ShareProtocol: the messages of the catch exchange on the protocol node (ShareNode.lua): the handlers of HELLO,
-- SUM, DIFF, WANT, BYE and REC, the diffs and wants, the records sent and merged, the hello rounds, the activity
-- and the status of a node.
local _, ns = ...
local Share = ns.Share
local P = Share.private
local MESSAGE_LIMIT, RECORD_LIMIT, Store = Share.MESSAGE_LIMIT, Share.RECORD_LIMIT, Share.Store
local MAX_RECORD_BYTES, SESSION_BYTES, PEER_PAUSE = P.MAX_RECORD_BYTES, P.SESSION_BYTES, P.PEER_PAUSE
local RESPONDER_GAP, FRIENDS_PER_ROUND, HELLO_LIMIT = P.RESPONDER_GAP, P.FRIENDS_PER_ROUND, P.HELLO_LIMIT
local SESSION_RECORDS, PROOF_CHUNK, HOUR, ALONE_AFTER = P.SESSION_RECORDS, P.PROOF_CHUNK, P.HOUR, P.ALONE_AFTER
local CHANNEL_TARGET, CHANNEL_WINDOW, NEAR_WINDOW = P.CHANNEL_TARGET, P.CHANNEL_WINDOW, P.NEAR_WINDOW
local BUSY_RETRY_MIN, BUSY_RETRY_MAX, MESSAGE_UNIT = P.BUSY_RETRY_MIN, P.BUSY_RETRY_MAX, P.MESSAGE_UNIT
local UnitOf, Absorbed, Changed, WasEvicted, Pending = P.UnitOf, P.Absorbed, P.Changed, P.WasEvicted, P.Pending
local OwnRecord, BucketIndex, Node = P.OwnRecord, P.BucketIndex, P.Node

-- Adds `weight` to a per-minute counter and returns the total of the last hour (Data.lua).
local function Recent(counts, now, weight)
    return ns.CountRecent(counts, now, weight, HOUR / 60)
end

-- A peer announcing a new tag: its previous one went with its old session (a relog draws a new one), so it leaves
-- byTag, unless it names another address (the same client by another path).
local function DropOldTag(self, address, peer, tag)
    if peer.node and peer.node ~= tag and self.byTag[peer.node] == address then
        self.byTag[peer.node] = nil
    end
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
            DropOldTag(self, address, peer, tag)
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
    DropOldTag(self, address, peer, tag)
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
            local unit = id .. "@" .. epoch
            local mine = summary.units[unit]
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

-- One frame step of the merge queue: a record's decode and check, or chunks of PROOF_CHUNK links of its chain within
-- the proof budget (P.WithinBudget; a record whose chain is longer keeps the front of the queue), then its store.
function Node:MergeOne()
    local item = table.remove(self.merges, 1)
    if not item or item.peer.ignored then
        return
    end
    local clock = self.env.clock
    local started = clock and clock()
    -- One decode, check and merge per frame step; assumed smooth with 20,000 stored places (V16, accepted)
    local ok
    if item.verify then
        local verify = item.verify
        local result
        P.WithinBudget(clock, started, function()
            local state
            result, state = ns.CatchDB.CheckVersion(verify.held, verify.record, PROOF_CHUNK, verify.state)
            verify.state = state
            return result == "more"
        end)
        if result == "more" then
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

-- Shared with ShareGame.lua through Share.private.
P.NoActivity = NoActivity
