-- CommReceive: the receiving side of the catch exchange's transport (Comm.lua, part of the module ns.Comm): addon
-- messages and Battle.net game data under the prefix, long messages put together from their parts within the
-- buffer limits, parts nobody asked for dropped and a sender who floods them reported once (part 3, FR-010).
-- See specs/003-guild-group-sync/contracts/sync-protocol.md and specs/004-public-channel-sync research.md R6.
local _, ns = ...
local Comm = ns.Comm
local P = Comm.private
local PREFIX, MAX_MESSAGE, MAX_PARTS, Enabled = P.PREFIX, P.MAX_MESSAGE, P.MAX_PARTS, P.Enabled
local buffers, flooded = P.buffers, P.flooded

local PART_TIMEOUT = 15 -- seconds without a new part before an unfinished message is dropped
local PART_BUFFER = 64 * 1024 -- bytes of parts kept per sender
local PART_BUFFER_TOTAL = 128 * 1024 -- bytes of parts kept over all senders (part 3, FR-010)
-- Dropped parts of one sender within PART_FLOOD_MINUTES before it is reported (FR-010): more than an honest client's
-- whole hourly budget can carry in parts (each but a message's last is a full MAX_MESSAGE, and a long message has at
-- least two), so the leftovers of a session that ended (a timeout, a /reload) never get an honest peer ignored.
local PART_FLOOD_LIMIT, PART_FLOOD_MINUTES = math.ceil(2 * Comm.BUDGET / MAX_MESSAGE), 10

local VIA = { GUILD = "guild", PARTY = "group", RAID = "group", WHISPER = "whisper", CHANNEL = "channel" }
local receivers, activityHandlers, floodHandlers = {}, {}, {}
local partFilter -- fn(address): true when parts of long messages are taken from it (Share: its session's peer)
local dropped = {} -- address -> per-minute counts of the parts dropped by the part filter

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------
function Comm.OnReceive(fn)
    table.insert(receivers, fn)
end

-- fn(address) for every message or part that arrives: a long message is still on its way.
function Comm.OnActivity(fn)
    table.insert(activityHandlers, fn)
end

-- fn(address): true when parts of long messages are taken from that address (part 3, FR-010).
function Comm.SetPartFilter(fn)
    partFilter = fn
end

-- fn(address) once when a sender's dropped parts pass PART_FLOOD_LIMIT within PART_FLOOD_MINUTES.
function Comm.OnFlood(fn)
    table.insert(floodHandlers, fn)
end

-- A part nobody asked for: dropped before any buffering; a sender who keeps sending them is reported once.
local lastSweep -- GetTime() of the last sweep of `dropped`

local function DropPart(address)
    local now = GetTime()
    if not lastSweep or now - lastSweep >= 60 then
        lastSweep = now
        for sender, counts in pairs(dropped) do
            if ns.CountRecent(counts, now, 0, PART_FLOOD_MINUTES) == 0 then
                dropped[sender] = nil -- nothing dropped from it for a while: its counts go
            end
        end
    end
    dropped[address] = dropped[address] or {}
    if ns.CountRecent(dropped[address], now, 1, PART_FLOOD_MINUTES) > PART_FLOOD_LIMIT then
        flooded[address], dropped[address] = true, nil
        for _, fn in ipairs(floodHandlers) do
            fn(address)
        end
    end
end

-- Keeps the parts of all senders within PART_BUFFER_TOTAL: the buffer that got its last part longest ago goes first.
local function CapBuffers()
    local total, oldest, oldestAt = 0, nil, math.huge
    for address, buffer in pairs(buffers) do
        total = total + buffer.bytes
        for _, entry in pairs(buffer.messages) do
            if entry.lastPart and entry.lastPart < oldestAt then
                oldest, oldestAt = address, entry.lastPart
            end
        end
    end
    if total > PART_BUFFER_TOTAL and oldest then
        buffers[oldest] = nil
        CapBuffers()
    end
end

local function Whole(address, via, text)
    for _, fn in ipairs(receivers) do
        fn(address, via, text)
    end
end

-- Drops the messages of a sender whose last part came PART_TIMEOUT ago, and checks again when the next one
-- would expire: a long record takes longer than that to arrive, but its parts keep coming.
-- buffer: the one the timer was set for; a sender's buffer that was dropped and made anew has its own timer.
local function DropExpired(address, buffer)
    if buffers[address] ~= buffer then
        return
    end
    buffer.checking = false
    local soonest
    for key, entry in pairs(buffer.messages) do
        local quiet = GetTime() - entry.lastPart
        if quiet >= PART_TIMEOUT then
            buffer.bytes = buffer.bytes - entry.bytes
            buffer.messages[key] = nil
        else
            soonest = math.min(soonest or PART_TIMEOUT, PART_TIMEOUT - quiet)
        end
    end
    if not soonest then
        buffers[address] = nil
    else
        buffer.checking = true
        C_Timer.After(soonest, function() DropExpired(address, buffer) end)
    end
end

local function OnMessage(address, via, text)
    if not Enabled() or Comm.GetPause() or type(text) ~= "string" or text:find("\0", 1, true) or flooded[address] then
        return
    end
    for _, fn in ipairs(activityHandlers) do
        fn(address)
    end
    local head, id, part, total, chunk = text:match("^(%u%w%w)#(%w+)%.(%d+)%.(%d+) (.*)$")
    if not head then
        Whole(address, via, text)
        return
    end
    -- Long messages come only inside a session, by whisper or Battle.net from its peer: never from the channel.
    if via == "channel" or (partFilter and not partFilter(address)) then
        DropPart(address)
        return
    end
    part, total = tonumber(part), tonumber(total)
    if part < 1 or part > total or total > MAX_PARTS then
        return
    end
    local buffer = buffers[address] or { bytes = 0, messages = {} }
    buffers[address] = buffer
    local key = head .. "#" .. id
    local entry = buffer.messages[key]
    if not entry then
        entry = { parts = {}, count = 0, total = total, bytes = 0 }
        buffer.messages[key] = entry
    end
    if entry.total ~= total or entry.parts[part] then
        return
    end
    entry.lastPart = GetTime()
    if not buffer.checking then
        buffer.checking = true
        C_Timer.After(PART_TIMEOUT, function() DropExpired(address, buffer) end)
    end
    buffer.bytes = buffer.bytes + #chunk
    if buffer.bytes > PART_BUFFER then
        buffers[address] = nil -- a flood: everything of this sender goes
        return
    end
    CapBuffers()
    if buffers[address] ~= buffer then
        return -- this sender's buffer made room for the others
    end
    entry.parts[part], entry.count, entry.bytes = chunk, entry.count + 1, entry.bytes + #chunk
    if entry.count == total then
        buffer.messages[key] = nil
        buffer.bytes = buffer.bytes - entry.bytes
        Whole(address, via, head .. " " .. table.concat(entry.parts))
    end
end

ns.RegisterEvent("CHAT_MSG_ADDON", function(_, prefix, text, channel, sender, target, _, _, name)
    if prefix ~= PREFIX or type(sender) ~= "string" or not VIA[channel] then
        return
    end
    -- VERIFY(V19): a channel message names its channel in the name argument (or in target)
    if channel == "CHANNEL" and not ns.Channel.IsOurs((type(name) == "string" and name ~= "") and name or target) then
        return
    end
    -- VERIFY(V11): the sender is "Name-Realm" and works as the WHISPER target as it is
    OnMessage("w:" .. sender, VIA[channel], text)
end)

ns.RegisterEvent("BN_CHAT_MSG_ADDON", function(_, prefix, text, _, senderID)
    if prefix ~= PREFIX or senderID == nil then
        return
    end
    OnMessage("b:" .. tostring(senderID), "bnet", text)
end)
