-- Comm: the transport of the catch exchange (Share.lua). Addon messages under the prefix OKF1 (the digit is the
-- protocol version) to the guild, the home group and by whisper, and Battle.net game data to friends playing
-- Forever. Long messages travel in parts; one paced send queue keeps an hourly budget and reads every send result;
-- everything pauses in combat, in instances, on loading screens and in restricted game states. Comm knows nothing
-- about records. Names live only in the queue, the part buffers and the chat filter's lines of the last 10 s.
-- See specs/003-guild-group-sync/contracts/sync-protocol.md and research.md R2, R7, R8, R10, R11.
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
local THROTTLE_BACKOFF, MAX_THROTTLE_BACKOFF = 2, 60 -- seconds, doubling while the game reports a throttle
local LOCKDOWN_BACKOFF, MAX_LOCKDOWN_BACKOFF = 60, 15 * 60 -- seconds of pause after AddOnMessageLockdown
local PART_TIMEOUT = 15 -- seconds without a new part before an unfinished message is dropped
local PART_BUFFER = 64 * 1024 -- bytes of parts kept per sender
local FILTER_WINDOW = 10 -- seconds a whispered name's "No player named ..." line is hidden
local PAUSE_RECHECK = 5 -- seconds between checks while paused
local MAX_REFUSALS = 5 -- refusals in a row before a path is left out until logout
local MAX_PARTS = 999

-- Enum.SendAddonMessageResult of the 1.60.1 export; C_BattleNet.SendGameData returns the same values.
local SUCCESS, NOT_IN_GROUP, ADDON_THROTTLE, CHANNEL_THROTTLE = 0, 5, 3, 8
local GENERAL_ERROR, NOT_IN_GUILD, LOCKDOWN, TARGET_OFFLINE = 9, 10, 11, 12

local VIA = { GUILD = "guild", PARTY = "group", RAID = "group", WHISPER = "whisper" }
-- The restrictions of Enum.AddOnRestrictionType that block addon messages.
local RESTRICTIONS = { "Chat", "Encounter", "ChallengeMode", "PvPMatch", "Map" }

local queue = {} -- { text, address, path, broadcast, chatType, target, essential }
local nextBroadcast, nextWhisper = 0, 0 -- GetTime() when the next message of each kind may go
local holdUntil, throttleBackoff = 0, nil
local lockdownUntil, lockdownBackoff = 0, nil
local combat, loading, unavailable = false, false, false
local lastPause, recheckPending = nil, false
local pumpAt -- GetTime() of the scheduled queue run
local traffic = {} -- minute -> bytes sent
local results = {} -- send result -> count, for /okf debug
local receivers, offlineHandlers, activityHandlers = {}, {}, {}
local paths = {
    guild = { failures = 0, disabled = false },
    group = { failures = 0, disabled = false },
    whisper = { failures = 0, disabled = false },
    bnet = { failures = 0, disabled = false },
}
local notFound = {} -- "No player named ..." line -> GetTime() of the whisper it would follow
local buffers = {} -- address -> { bytes, checking, messages = { [key] = { parts, count, total, bytes, lastPart } } }
local counter = 0 -- the part counter of this client's long messages

local function Enabled()
    return ns.db ~= nil and ns.Share.IsEnabled()
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
        wipe(queue)
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
local function Minute()
    return math.floor(GetTime() / 60)
end

function Comm.GetTraffic()
    local minute, total = Minute(), 0
    for at, bytes in pairs(traffic) do
        if at > minute - BUDGET_MINUTES then
            total = total + bytes
        else
            traffic[at] = nil
        end
    end
    return total
end

local function AddTraffic(bytes)
    local minute = Minute()
    traffic[minute] = (traffic[minute] or 0) + bytes
end

-- False while paused, or when one more full message would go over the budget.
-- bytes: a message about to be sent (its part headers come on top), so it goes out whole.
function Comm.CanSend(bytes)
    return Enabled() and not Comm.GetPause()
        and Comm.GetTraffic() + math.ceil((bytes or 0) * 1.1) + MAX_MESSAGE <= BUDGET
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
            table.remove(queue, i)
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
        for _, other in pairs(paths) do
            left = left or not other.disabled
        end
        unavailable = not left
        UpdatePause()
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
        throttleBackoff, lockdownBackoff = nil, nil
        paths[message.path].failures = 0
    elseif result == ADDON_THROTTLE or result == CHANNEL_THROTTLE then
        table.insert(queue, 1, message)
        throttleBackoff = throttleBackoff and math.min(throttleBackoff * 2, MAX_THROTTLE_BACKOFF) or THROTTLE_BACKOFF
        holdUntil = GetTime() + throttleBackoff
    elseif result == LOCKDOWN then
        lockdownBackoff = lockdownBackoff and math.min(lockdownBackoff * 2, MAX_LOCKDOWN_BACKOFF) or LOCKDOWN_BACKOFF
        lockdownUntil = GetTime() + lockdownBackoff
        UpdatePause()
    elseif result == TARGET_OFFLINE then
        -- VERIFY(V12): a whisper to a player who just went offline returns TargetOffline
        if message.address then -- only whispers and Battle.net have one
            DropWhere(function(other) return other.address == message.address end)
            for _, fn in ipairs(offlineHandlers) do
                fn(message.address)
            end
        end
    elseif result ~= NOT_IN_GUILD and result ~= NOT_IN_GROUP and not message.greeting then
        Refused(message.path)
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
        wipe(queue)
        return
    end
    local now = GetTime()
    if now < holdUntil then
        Schedule(holdUntil)
        return
    end
    for i, message in ipairs(queue) do
        if now >= NextSlot(message) then
            Deliver(table.remove(queue, i))
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
    table.insert(queue, message)
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
    local realm = GetNormalizedRealmName and GetNormalizedRealmName()
    for i = 1, C_FriendList.GetNumFriends() or 0 do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and info.connected and type(info.name) == "string" then
            local name = info.name
            if realm and not name:find("-", 1, true) then
                name = name .. "-" .. realm -- the address the friend's own messages arrive from
            end
            fn("w:" .. name)
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
    if not Enabled() or Comm.GetPause() or type(text) ~= "string" or text:find("\0", 1, true) then
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
    entry.parts[part], entry.count, entry.bytes = chunk, entry.count + 1, entry.bytes + #chunk
    if entry.count == total then
        buffer.messages[key] = nil
        buffer.bytes = buffer.bytes - entry.bytes
        Whole(address, via, head .. " " .. table.concat(entry.parts))
    end
end

ns.RegisterEvent("CHAT_MSG_ADDON", function(_, prefix, text, channel, sender)
    if prefix ~= PREFIX or type(sender) ~= "string" or not VIA[channel] then
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
        ("transport: pause %s, traffic %d of %d bytes in the last hour, queue %d"):format(
            tostring(Comm.GetPause() or "none"), Comm.GetTraffic(), BUDGET, #queue),
        "send results: " .. (#codes > 0 and table.concat(codes, " ") or "none"),
        ("back-off: throttle %s s, lockdown %s s"):format(tostring(throttleBackoff or 0),
            tostring(lockdownBackoff or 0)),
        "paths with refusals: " .. (#out > 0 and table.concat(out, ", ") or "none"),
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

C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
