-- ShareGame: the one protocol node of the game, bound to Comm (Exchange/Comm.lua): its pauses, hello rounds and
-- the channel's rounds, the one-time notice's state (the popup is UI/ShareNotice.lua), the setting, and the
-- state the tab, the settings page, /okf share and /okf debug show.
local _, ns = ...
local Share = ns.Share
local P = Share.private
local SeedAbsorbed = ns.CatchDB.SeedAbsorbed
local Store = Share.Store
local FIRST_HELLO_MIN, FIRST_HELLO_MAX = P.FIRST_HELLO_MIN, P.FIRST_HELLO_MAX
local ROUND_MIN, ROUND_MAX, EXTRA_HELLO_MIN = P.ROUND_MIN, P.ROUND_MAX, P.EXTRA_HELLO_MIN
local EXTRA_HELLO_MAX, EXTRA_HELLO_GAP, HELLO_STALE = P.EXTRA_HELLO_MAX, P.EXTRA_HELLO_GAP, P.HELLO_STALE
local CHANNEL_WINDOW, CHANNEL_FIRST_MIN = P.CHANNEL_WINDOW, P.CHANNEL_FIRST_MIN
local CHANNEL_FIRST_MAX, CHANNEL_ROUND_MIN = P.CHANNEL_FIRST_MAX, P.CHANNEL_ROUND_MIN
local CHANNEL_ROUND_MAX, CHANNEL_MOVE_MIN = P.CHANNEL_ROUND_MAX, P.CHANNEL_MOVE_MIN
local CHANNEL_MOVE_MAX, OwnRecord, CountUnits = P.CHANNEL_MOVE_MAX, P.OwnRecord, P.CountUnits
local NoActivity = P.NoActivity
local L = ns.L

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
    if loadedName ~= ns.name or not ns.db then
        return
    end
    Store.CleanUp(ns.db.shared)
    Store.Evict(ns.db.shared)
    -- Copies of units the seed holds in part must continue the seed's proof: walked in the background.
    local work = Store.SeedChainWork(ns.db.shared)
    local function Step()
        if not Store.CheckSeedStep(ns.db.shared, work, DebugClock) then
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
