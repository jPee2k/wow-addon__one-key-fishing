-- Comm: the transport of the catch exchange (Share.lua). Addon messages under the prefix OKF1 (the digit is the
-- protocol version) to the guild, the home group, the hidden public channel (Channel.lua, part 3) and by whisper,
-- and Battle.net game data to friends playing Forever. Long messages travel in parts; one paced send queue keeps
-- an hourly budget and reads every send result; everything pauses in combat, in instances, on loading screens and
-- in restricted game states. Comm knows nothing about records. Names live only in the queue, the part buffers and
-- the chat filter's lines of the last 10 s.
-- The module spans Comm.lua (the sending side, the pause, the paths, the state) and CommReceive.lua (messages and
-- parts coming in), which share Comm.private.
-- See specs/003-guild-group-sync/contracts/sync-protocol.md and research.md R2, R7, R8, R10, R11, and for the channel
-- and the part rules specs/004-public-channel-sync/contracts/protocol.md and research.md R6.
local _, ns = ...

local Comm = {}
ns.Comm = Comm
local P = {}
Comm.private = P -- internals shared by the Exchange/Comm*.lua files and read by the tests (not an API)

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
local CHANNEL_REFUSALS = 2 -- refusals in a row on the channel path before Channel.lua moves on (research R4, R6)
local FILTER_WINDOW = 10 -- seconds a whispered name's "No player named ..." line is hidden
local PAUSE_RECHECK = 5 -- seconds between checks while paused
local MAX_REFUSALS = 5 -- refusals in a row before a path is left out until logout
local MAX_PARTS = 999

-- Send results, read from Enum.SendAddonMessageResult (C_BattleNet.SendGameData returns the same values), so a
-- patch that renumbers them changes nothing here; the numbers of the 1.60.1 export are only the fallback.
local RESULT = Enum and Enum.SendAddonMessageResult or {}
local SUCCESS, NOT_IN_GROUP = RESULT.Success or 0, RESULT.NotInGroup or 5
local ADDON_THROTTLE, CHANNEL_THROTTLE = RESULT.AddonMessageThrottle or 3, RESULT.ChannelThrottle or 8
local GENERAL_ERROR, NOT_IN_GUILD = RESULT.GeneralError or 9, RESULT.NotInGuild or 10
local LOCKDOWN, TARGET_OFFLINE = RESULT.AddOnMessageLockdown or 11, RESULT.TargetOffline or 12

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
local offlineHandlers = {}
local flooded = {} -- addresses reported through OnFlood: every message from them is dropped until logout
local channelRefusals = 0 -- in a row, on the current join of the channel
-- NOT_ALLOWED_IN_CHANNEL notices on the current join: the send before each one returned success, which clears
-- channelRefusals, so the notices are counted on their own.
local channelNotices = 0
local channelJoins -- the join of the channel those refusals were counted on (CHANNEL_STATE)
local paths = {
    guild = { failures = 0, disabled = false },
    group = { failures = 0, disabled = false },
    whisper = { failures = 0, disabled = false },
    bnet = { failures = 0, disabled = false },
    channel = { failures = 0, disabled = false }, -- refusals move to the next channel (Channel.OnRefused) instead
}
-- "No player named ..." line -> { at = GetTime() of the whisper it would follow, address = its address (cleared once
-- the line ended the session) }
local notFound = {}
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
-- The open world out of combat has no active restriction, and these turn true where addon chat is blocked (V14,
-- seen in game: Map in an instance)
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

-- One refusal of the channel path: a refused send (in a row), or the server's NOT_ALLOWED_IN_CHANNEL notice
-- (`notice`, from Channel.lua: counted on the current join, since its send returned success). At CHANNEL_REFUSALS
-- the channel moves on.
function Comm.ChannelRefused(notice)
    if notice then
        channelNotices = channelNotices + 1
    else
        channelRefusals = channelRefusals + 1
    end
    if channelRefusals >= CHANNEL_REFUSALS or channelNotices >= CHANNEL_REFUSALS then
        channelRefusals, channelNotices = 0, 0
        ns.Channel.OnRefused()
    end
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
        for line, entry in pairs(notFound) do
            if GetTime() - entry.at > FILTER_WINDOW then
                notFound[line] = nil
            end
        end
        -- The line may name the player with or without the realm, and shows "A-B" as "A B" (seen, V12).
        local target = message.target
        for _, name in ipairs({ target, (target:match("^[^-]+")), (target:gsub("-", " ")) }) do
            notFound[ERR_CHAT_PLAYER_NOT_FOUND_S:format(name)] = { at = GetTime(), address = message.address }
        end
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
        -- Addon messages to a channel throttle as on Retail and report ChannelThrottle (not shipped, V19).
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
        Comm.ChannelRefused()
    elseif result == TARGET_OFFLINE then
        -- A whisper to a player who just went offline may return TargetOffline (on Forever it returns 0, and the
        -- hidden "No player named" line is the signal: HideNotFound)
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
    -- VERIFY(V11): the friends list names a friend as the friend's own messages do ("First Last"; a realm only
    -- when the game gives one)
    for i = 1, C_FriendList.GetNumFriends() or 0 do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and info.connected and type(info.name) == "string" then
            fn("w:" .. info.name) -- the address the friend's own messages arrive from
        end
    end
    -- Battle.net friends playing Forever have clientProgram BNET_CLIENT_WOW and our WOW_PROJECT_ID (V13, seen in game)
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
-- Offline peers (the receiving side is in CommReceive.lua)
---------------------------------------------------------------------------
function Comm.OnOffline(fn)
    table.insert(offlineHandlers, fn)
end

---------------------------------------------------------------------------
-- The chat filter: a whisper to a player who just went offline may print "No player named ..."
---------------------------------------------------------------------------
-- The recorded entry of a "No player named ..." line still within FILTER_WINDOW, or nil.
local function NotFoundEntry(text)
    if (issecretvalue and issecretvalue(text)) or type(text) ~= "string" or next(notFound) == nil then
        return nil
    end
    local entry = notFound[text]
    if entry and GetTime() - entry.at > FILTER_WINDOW then
        notFound[text] = nil
        return nil
    end
    return entry
end

-- VERIFY(V12): a whisper to an offline player returns 0 and the game prints 'No player named ...': the event is the
-- offline signal (whatever the chat windows show), once per address; the filter below only hides the line.
ns.RegisterEvent("CHAT_MSG_SYSTEM", function(_, text)
    local entry = NotFoundEntry(text)
    local address = entry and entry.address
    if address then
        -- The line with and without the realm, and a repeat, end nothing more.
        for _, other in pairs(notFound) do
            if other.address == address then
                other.address = nil
            end
        end
        Unreachable({ address = address })
    end
end)

local function HideNotFound(_, _, text)
    return NotFoundEntry(text) ~= nil
end

if ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter then
    ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_SYSTEM", HideNotFound)
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
-- The send paths and their failures, for the tests (Comm.private).
function P.GetPaths()
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
        channelJoins, channelRefusals, channelNotices = joins, 0, 0
    end
end)

C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)

-- Shared with CommReceive.lua through Comm.private; the tables are never reassigned (UpdatePause wipes buffers).
P.PREFIX, P.MAX_MESSAGE, P.MAX_PARTS, P.Enabled = PREFIX, MAX_MESSAGE, MAX_PARTS, Enabled
P.buffers, P.flooded = buffers, flooded
