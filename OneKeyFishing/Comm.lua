-- Comm: the transport of the catch exchange (Share.lua). Addon messages under the prefix OKF1 (the digit is the
-- protocol version) to the guild, the home group, the hidden public channel (Channel.lua, part 3) and by whisper,
-- and Battle.net game data to friends playing Forever. Long messages travel in parts; one paced send queue keeps
-- an hourly budget and reads every send result; everything pauses in combat, in instances, on loading screens and
-- in restricted game states. Comm knows nothing about records. Names live only in the queue, the part buffers and
-- the chat filter's lines of the last 10 s.
-- See specs/003-guild-group-sync/contracts/sync-protocol.md and research.md R2, R7, R8, R10, R11, and for the channel
-- and the part rules specs/004-public-channel-sync/contracts/protocol.md and research.md R6.
local _, ns = ...

local Comm = {}
ns.Comm = Comm

local PREFIX = "OKF1"
local MAX_MESSAGE = 255 -- bytes per message, the part header included
-- VERIFY(V10): the game throttles as on Retail (10 per prefix, +1 per s; whispers outside instances unthrottled)
local BROADCAST_PACE = 2 -- seconds between guild and group messages
local WHISPER_PACE = 0.5 -- seconds between whispers and Battle.net messages
local BUDGET = 50 * 1024 -- bytes sent per BUDGET_MINUTES, counted per minute; above it only BYE goes out
local BUDGET_MINUTES = 60
Comm.BUDGET = BUDGET -- Share.lua derives its per-sender limits from it
-- Seconds of hold after a throttle result, doubling while it repeats. The cap stays under the protocol's 15 s
-- session and part timeouts (Share.lua): a longer hold mid-session makes the peer give up and drop what it got.
local THROTTLE_BACKOFF, MAX_THROTTLE_BACKOFF = 2, 8
local LOCKDOWN_BACKOFF, MAX_LOCKDOWN_BACKOFF = 60, 15 * 60 -- seconds of pause after AddOnMessageLockdown
local PART_TIMEOUT = 15 -- seconds without a new part before an unfinished message is dropped
local PART_BUFFER = 64 * 1024 -- bytes of parts kept per sender
local PART_BUFFER_TOTAL = 128 * 1024 -- bytes of parts kept over all senders (part 3, FR-010)
local CHANNEL_REFUSALS = 2 -- refusals in a row on the channel path before Channel.lua moves on (research R4, R6)
local FILTER_WINDOW = 10 -- seconds a whispered name's "No player named ..." line is hidden
local PAUSE_RECHECK = 5 -- seconds between checks while paused
local MAX_REFUSALS = 5 -- refusals in a row before a path is left out until logout
local MAX_PARTS = 999
-- Dropped parts of one sender within PART_FLOOD_MINUTES before it is reported (FR-010): more than an honest client's
-- whole hourly budget can carry in parts (each but a message's last is a full MAX_MESSAGE, and a long message has at
-- least two), so the leftovers of a session that ended (a timeout, a /reload) never get an honest peer ignored.
local PART_FLOOD_LIMIT, PART_FLOOD_MINUTES = math.ceil(2 * BUDGET / MAX_MESSAGE), 10

-- Send results, read from Enum.SendAddonMessageResult (C_BattleNet.SendGameData returns the same values), so a
-- patch that renumbers them changes nothing here; the numbers of the 1.60.1 export are only the fallback.
local RESULT = Enum and Enum.SendAddonMessageResult or {}
local SUCCESS, NOT_IN_GROUP = RESULT.Success or 0, RESULT.NotInGroup or 5
local ADDON_THROTTLE, CHANNEL_THROTTLE = RESULT.AddonMessageThrottle or 3, RESULT.ChannelThrottle or 8
local GENERAL_ERROR, NOT_IN_GUILD = RESULT.GeneralError or 9, RESULT.NotInGuild or 10
local LOCKDOWN, TARGET_OFFLINE = RESULT.AddOnMessageLockdown or 11, RESULT.TargetOffline or 12

local VIA = { GUILD = "guild", PARTY = "group", RAID = "group", WHISPER = "whisper", CHANNEL = "channel" }
-- The restrictions of Enum.AddOnRestrictionType that block addon messages.
local RESTRICTIONS = { "Chat", "Encounter", "ChallengeMode", "PvPMatch", "Map" }

local queue = {} -- { text, address, path, broadcast, chatType, target, essential }
local queuedBytes = 0 -- bytes of the queued messages: CanSend counts them before they go out
local nextBroadcast, nextWhisper = 0, 0 -- GetTime() when the next message of each kind may go
local holdUntil, throttleBackoff = 0, nil
local lockdownUntil, lockdownBackoff = 0, nil
local combat, loading, unavailable = false, false, false
local lastPause, recheckPending = nil, false
local pumpAt -- GetTime() of the scheduled queue run
local traffic = {} -- minute -> bytes sent
local results = {} -- send result -> count, for /okf debug
local anySuccess = false -- a message went out since the login: the game takes this account's addon messages
local receivers, offlineHandlers, activityHandlers, floodHandlers = {}, {}, {}, {}
local partFilter -- fn(address): true when parts of long messages are taken from it (Share: its session's peer)
local dropped = {} -- address -> per-minute counts of the parts dropped by the part filter
local flooded = {} -- addresses reported through OnFlood: every message from them is dropped until logout
local channelRefusals = 0 -- in a row, on the current join of the channel
local channelJoins -- the join of the channel those refusals were counted on (CHANNEL_STATE)
local paths = {
    guild = { failures = 0, disabled = false },
    group = { failures = 0, disabled = false },
    whisper = { failures = 0, disabled = false },
    bnet = { failures = 0, disabled = false },
    channel = { failures = 0, disabled = false }, -- refusals move to the next channel (Channel.OnRefused) instead
}
local notFound = {} -- "No player named ..." line -> GetTime() of the whisper it would follow
local buffers = {} -- address -> { bytes, checking, messages = { [key] = { parts, count, total, bytes, lastPart } } }
local counter = 0 -- the part counter of this client's long messages

local function Enabled()
    return ns.db ~= nil and ns.Share.IsEnabled()
end

-- The queue changes only here, so queuedBytes stays right. first: at the front (a throttled message again).
local function Enqueue(message, first)
    table.insert(queue, first and 1 or #queue + 1, message)
    queuedBytes = queuedBytes + #message.text
end

local function Dequeue(index)
    local message = table.remove(queue, index)
    queuedBytes = queuedBytes - #message.text
    return message
end

local function ClearQueue()
    wipe(queue)
    queuedBytes = 0
end

---------------------------------------------------------------------------
-- Pause
---------------------------------------------------------------------------
-- VERIFY(V14): the open world out of combat has no active restriction, and these turn true where addon chat is
-- blocked
local function Restricted()
    local types = Enum.AddOnRestrictionType
    if C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive and types then
        for _, name in ipairs(RESTRICTIONS) do
            if types[name] and C_RestrictedActions.IsAddOnRestrictionActive(types[name]) then
                return true
            end
        end
    end
    -- Not AreOutgoingAddonChatMessagesRestricted: by its API doc it is about the chat messages addons send
    -- (allowed on tournament realms only), not addon messages, so it is true on a normal realm.
    return (C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()) or false
end

-- The reason the exchange cannot run now, or nil.
function Comm.GetPause()
    if unavailable then
        return "unavailable"
    end
    if combat or InCombatLockdown() then
        return "combat"
    end
    if loading then
        return "loading"
    end
    if IsInInstance() then
        return "instance"
    end
    if Restricted() then
        return "restricted"
    end
    if GetTime() < lockdownUntil then
        return "lockdown"
    end
end

-- Drops what waits while paused (a stale session would time out anyway), fires SHARE_PAUSE on a change and
-- checks again every few seconds until the pause ends.
local function UpdatePause()
    local reason = Comm.GetPause()
    if reason then
        ClearQueue()
        wipe(buffers)
    end
    if reason ~= lastPause then
        lastPause = reason
        ns.Fire("SHARE_PAUSE", reason)
    end
    if reason and reason ~= "unavailable" and not recheckPending then
        recheckPending = true
        C_Timer.After(PAUSE_RECHECK, function()
            recheckPending = false
            UpdatePause()
        end)
    end
end

---------------------------------------------------------------------------
-- Budget
---------------------------------------------------------------------------
function Comm.GetTraffic()
    return ns.CountRecent(traffic, GetTime(), 0, BUDGET_MINUTES)
end

local function AddTraffic(bytes)
    ns.CountRecent(traffic, GetTime(), bytes, BUDGET_MINUTES)
end

-- False while paused, or when one more full message would go over the budget, the messages still queued included
-- (a session queues DIFF, WANT and records one after another, each checked before the earlier ones went out).
-- bytes: a message about to be sent (its part headers come on top), so it goes out whole.
function Comm.CanSend(bytes)
    return Enabled() and not Comm.GetPause()
        and Comm.GetTraffic() + queuedBytes + math.ceil((bytes or 0) * 1.1) + MAX_MESSAGE <= BUDGET
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------
local Pump

local function Schedule(at)
    if pumpAt and pumpAt <= at then
        return
    end
    pumpAt = at
    C_Timer.After(math.max(0, at - GetTime()), function()
        if pumpAt == at then
            Pump()
        end
    end)
end

local function DropWhere(matches)
    for i = #queue, 1, -1 do
        if matches(queue[i]) then
            Dequeue(i)
        end
    end
end

-- A path the game refused MAX_REFUSALS times in a row is left out until logout; with every path left out the
-- exchange is unavailable (a Trial or Veteran account cannot send addon data).
local function Refused(name)
    local path = paths[name]
    path.failures = path.failures + 1
    if path.failures >= MAX_REFUSALS and not path.disabled then
        path.disabled = true
        DropWhere(function(message) return message.path == name end)
        local left = false
        for otherName, other in pairs(paths) do
            -- The channel carries HELLO only and sessions go by whisper: it alone keeps nothing available.
            left = left or (not other.disabled and otherName ~= "channel")
        end
        unavailable = not left
        UpdatePause()
    end
end

-- The game could not deliver to the message's player (whispers and Battle.net only): the rest queued to them would
-- fail the same way, so it is dropped, and the offline handlers drop the session with them and pause them.
local function Unreachable(message)
    if message.address then
        DropWhere(function(other) return other.address == message.address end)
        for _, fn in ipairs(offlineHandlers) do
            fn(message.address)
        end
    end
end

local function SendNow(message)
    local ok, result
    if message.path == "bnet" then
        -- VERIFY(V13): SendGameData carries OKF1 messages between Forever clients and returns a send result
        ok, result = pcall(C_BattleNet.SendGameData, message.target, PREFIX, message.text)
    else
        -- VERIFY(V10): SendAddonMessage works for GUILD, PARTY, RAID and WHISPER and shows nothing in chat
        -- VERIFY(V19): SendAddonMessage to a custom channel takes its number and reaches the addon users in it
        ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, message.text, message.chatType, message.target)
    end
    if not ok or result == false then
        return GENERAL_ERROR
    end
    if result == nil or result == true then
        return SUCCESS
    end
    return result
end

local function Deliver(message)
    -- Over the hourly budget a message is dropped (the session times out on the other side); the decision is
    -- made once per message, at its first part, so a message never goes out in part.
    local whole = message.whole
    if whole.allowed == nil then
        whole.allowed = message.essential or Comm.GetTraffic() + MAX_MESSAGE <= BUDGET
    end
    if not whole.allowed then
        return
    end
    if message.chatType == "CHANNEL" then
        message.target = ns.Channel.GetNumber() -- the number now: a move to a fallback channel changes it
        if not message.target then
            return -- left the channel meanwhile
        end
    end
    if message.chatType == "WHISPER" and ERR_CHAT_PLAYER_NOT_FOUND_S then
        for line, at in pairs(notFound) do
            if GetTime() - at > FILTER_WINDOW then
                notFound[line] = nil
            end
        end
        -- The line may name the player with or without the realm.
        notFound[ERR_CHAT_PLAYER_NOT_FOUND_S:format(message.target)] = GetTime()
        notFound[ERR_CHAT_PLAYER_NOT_FOUND_S:format((message.target:match("^[^-]+")))] = GetTime()
    end
    local result = SendNow(message)
    results[result] = (results[result] or 0) + 1
    if message.broadcast then
        nextBroadcast = GetTime() + BROADCAST_PACE
    else
        nextWhisper = GetTime() + WHISPER_PACE
    end
    if result == SUCCESS then
        AddTraffic(#message.text)
        anySuccess = true
        throttleBackoff, lockdownBackoff = nil, nil
        paths[message.path].failures = 0
        if message.path == "channel" then
            channelRefusals = 0
        end
    elseif result == ADDON_THROTTLE or result == CHANNEL_THROTTLE then
        -- VERIFY(V25): addon messages to a channel throttle as on Retail and report ChannelThrottle
        Enqueue(message, true)
        throttleBackoff = throttleBackoff and math.min(throttleBackoff * 2, MAX_THROTTLE_BACKOFF) or THROTTLE_BACKOFF
        holdUntil = GetTime() + throttleBackoff
    elseif result == LOCKDOWN then
        lockdownBackoff = lockdownBackoff and math.min(lockdownBackoff * 2, MAX_LOCKDOWN_BACKOFF) or LOCKDOWN_BACKOFF
        lockdownUntil = GetTime() + lockdownBackoff
        UpdatePause()
    elseif message.path == "channel" then
        -- A channel that cannot carry messages any more (InvalidChannel or GeneralError when moderated or muted, or
        -- any other refusal): the next one, never the part 2 path rule, which would keep the slot with no use.
        channelRefusals = channelRefusals + 1
        if channelRefusals >= CHANNEL_REFUSALS then
            channelRefusals = 0
            ns.Channel.OnRefused()
        end
    elseif result == TARGET_OFFLINE then
        -- VERIFY(V12): a whisper to a player who just went offline returns TargetOffline
        Unreachable(message)
    elseif result ~= NOT_IN_GUILD and result ~= NOT_IN_GROUP then
        -- Any other refusal. For one player it counts once against the path, not once per queued part: an
        -- unreachable player (reported with another code than TargetOffline) must not leave the path out.
        Unreachable(message)
        if not message.greeting then
            Refused(message.path)
        end
    end
end

-- GetTime() when the pace lets a message of this kind go.
local function NextSlot(message)
    return message.broadcast and nextBroadcast or nextWhisper
end

-- Sends the first message whose kind the pace allows, then waits for the next one that can go.
Pump = function()
    pumpAt = nil
    if not Enabled() or Comm.GetPause() then
        ClearQueue()
        return
    end
    local now = GetTime()
    if now < holdUntil then
        Schedule(holdUntil)
        return
    end
    for i, message in ipairs(queue) do
        if now >= NextSlot(message) then
            Deliver(Dequeue(i))
            break
        end
    end
    if #queue > 0 then
        local earliest = math.huge
        for _, message in ipairs(queue) do
            earliest = math.min(earliest, NextSlot(message))
        end
        Schedule(math.max(earliest, holdUntil, GetTime()))
    end
end

-- A message as it goes out: itself, or parts "<type><sid>#<msg>.<part>.<total> <chunk>" of the text after
-- "<type><sid> " (contracts/sync-protocol.md). A long text without that head cannot be split and is dropped.
function Comm.Split(text)
    if #text <= MAX_MESSAGE then
        return { text }
    end
    local head, body = text:match("^(%u%w%w) (.+)$")
    if not head then
        return {}
    end
    counter = (counter + 1) % 1024
    local id = ns.Base32(counter, 2)
    local room = MAX_MESSAGE - #("%s#%s.%d.%d "):format(head, id, MAX_PARTS, MAX_PARTS)
    local total = math.ceil(#body / room)
    if total > MAX_PARTS then
        return {}
    end
    local parts = {}
    for part = 1, total do
        parts[part] = ("%s#%s.%d.%d %s"):format(head, id, part, total, body:sub((part - 1) * room + 1, part * room))
    end
    return parts
end

local function Queue(message)
    Enqueue(message)
    Schedule(GetTime())
end

-- Queues a message to "w:<name>" (whisper) or "b:<gameAccountID>" (Battle.net); false when it cannot go.
-- messageKind: "bye" goes out even over the hourly budget; "greeting" (a HELLO to a friend) does not count
-- against its path when refused, since one odd friend name must not cut off the sessions that share the path.
function Comm.Send(address, text, messageKind)
    if not Enabled() or Comm.GetPause() then
        return false
    end
    local kind, target = tostring(address):match("^([wb]):(.+)$")
    local path = kind == "w" and "whisper" or "bnet"
    if not kind or paths[path].disabled or (kind == "b" and not tonumber(target)) then
        return false
    end
    local parts = Comm.Split(text)
    if #parts == 0 then
        return false -- cannot be split: dropped
    end
    local whole = {}
    for _, part in ipairs(parts) do
        Queue({ text = part, address = address, path = path, chatType = kind == "w" and "WHISPER" or nil,
            target = kind == "w" and target or tonumber(target), essential = messageKind == "bye",
            greeting = messageKind == "greeting", whole = whole })
    end
    return true
end

-- Queues a message to the guild and the home group, each only when the player is in one.
function Comm.Broadcast(text)
    if not Enabled() or Comm.GetPause() or #text > MAX_MESSAGE then
        return
    end
    if IsInGuild() and not paths.guild.disabled then
        Queue({ text = text, path = "guild", broadcast = true, chatType = "GUILD", whole = {} })
    end
    if IsInGroup(LE_PARTY_CATEGORY_HOME) and not paths.group.disabled then
        Queue({ text = text, path = "group", broadcast = true, whole = {},
            chatType = IsInRaid(LE_PARTY_CATEGORY_HOME) and "RAID" or "PARTY" })
    end
end

-- Queues a HELLO to the hidden public channel, only while Channel.lua is in it (part 3).
function Comm.ChannelBroadcast(text)
    if not Enabled() or Comm.GetPause() or #text > MAX_MESSAGE or paths.channel.disabled
        or ns.Channel.GetState() ~= "in" then
        return
    end
    Queue({ text = text, path = "channel", broadcast = true, chatType = "CHANNEL", whole = {} })
end

-- True while messages to `address` wait in the queue (the other side cannot answer before they arrive).
function Comm.IsSending(address)
    for _, message in ipairs(queue) do
        if message.address == address then
            return true
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Friends
---------------------------------------------------------------------------
-- fn(address) for every online character friend and every Battle.net game account playing Forever.
function Comm.ForEachFriend(fn)
    -- VERIFY(V11): a friend on the own realm is listed without the realm, while addon messages come as Name-Realm
    for i = 1, C_FriendList.GetNumFriends() or 0 do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and info.connected and type(info.name) == "string" then
            fn("w:" .. ns.WithRealm(info.name)) -- the address the friend's own messages arrive from
        end
    end
    -- VERIFY(V13): Battle.net friends playing Forever have clientProgram BNET_CLIENT_WOW and our WOW_PROJECT_ID
    for i = 1, BNGetNumFriends() or 0 do
        for j = 1, C_BattleNet.GetFriendNumGameAccounts(i) or 0 do
            local account = C_BattleNet.GetFriendGameAccountInfo(i, j)
            if account and account.isOnline and account.clientProgram == BNET_CLIENT_WOW
                and account.wowProjectID == WOW_PROJECT_ID and account.gameAccountID then
                fn("b:" .. account.gameAccountID)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------
function Comm.OnReceive(fn)
    table.insert(receivers, fn)
end

function Comm.OnOffline(fn)
    table.insert(offlineHandlers, fn)
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

---------------------------------------------------------------------------
-- The chat filter: a whisper to a player who just went offline may print "No player named ..."
---------------------------------------------------------------------------
-- VERIFY(V12): the line appears for a whisper to an offline player, and this filter hides it
local function HideNotFound(_, _, text)
    if (issecretvalue and issecretvalue(text)) or type(text) ~= "string" or next(notFound) == nil then
        return
    end
    local at = notFound[text]
    if at then
        if GetTime() - at <= FILTER_WINDOW then
            return true
        end
        notFound[text] = nil
    end
end

if ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter then
    ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_SYSTEM", HideNotFound)
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
function Comm.GetPaths()
    return paths
end

-- True while the game seems to refuse this account's addon messages (a Trial or Veteran account): nothing went out
-- since the login, and every path a message other than a greeting was tried on is left out. Only for the state:
-- unlike the "unavailable" pause (every path left out), a later success on a path not tried yet clears it.
function Comm.Refused()
    if anySuccess then
        return false
    end
    local leftOut = false
    for _, path in pairs(paths) do
        if path.disabled then
            leftOut = true
        elseif path.failures > 0 then
            return false -- still being tried
        end
    end
    return leftOut
end

-- Lines for /okf debug: no names, no addresses.
function Comm.Describe()
    local codes = {}
    for code, count in pairs(results) do
        table.insert(codes, ("%s=%d"):format(tostring(code), count))
    end
    table.sort(codes)
    local out = {}
    for name, path in pairs(paths) do
        if path.disabled or path.failures > 0 then
            table.insert(out, ("%s (%d refusals%s)"):format(name, path.failures, path.disabled and ", left out" or ""))
        end
    end
    table.sort(out)
    return {
        ("transport: pause %s, traffic %d of %d bytes in the last hour, queue %d (%d bytes)"):format(
            tostring(Comm.GetPause() or "none"), Comm.GetTraffic(), BUDGET, #queue, queuedBytes),
        "send results: " .. (#codes > 0 and table.concat(codes, " ") or "none"),
        ("back-off: throttle %s s, lockdown %s s"):format(tostring(throttleBackoff or 0),
            tostring(lockdownBackoff or 0)),
        "paths with refusals: " .. (#out > 0 and table.concat(out, ", ") or "none"),
        ("channel refusals in a row %d, senders flooding parts %d"):format(channelRefusals, ns.CountKeys(flooded)),
    }
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
ns.RegisterEvent("PLAYER_REGEN_DISABLED", function()
    combat = true
    UpdatePause()
end)

ns.RegisterEvent("PLAYER_REGEN_ENABLED", function()
    combat = false
    UpdatePause()
end)

ns.RegisterEvent("LOADING_SCREEN_ENABLED", function()
    loading = true
    UpdatePause()
end)

ns.RegisterEvent("LOADING_SCREEN_DISABLED", function()
    loading = false
    UpdatePause()
end)

-- ADDON_RESTRICTION_STATE_CHANGED fires before a restriction becomes active, and IsAddOnRestrictionActive is
-- false while it is dispatched: the state is read on the next frame.
ns.RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED", function()
    C_Timer.After(0, UpdatePause)
end)

for _, event in ipairs({ "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }) do
    ns.RegisterEvent(event, UpdatePause)
end

-- Every join of the channel (the same one again too) gets its own two tries (research R4, R6): a refusal counted
-- before a move that a notice caused does not count on the next channel.
ns.On("CHANNEL_STATE", function(_, _, joins)
    if joins ~= channelJoins then
        channelJoins, channelRefusals = joins, 0
    end
end)

C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
