-- Channel: the hidden public channel of the catch exchange (part 3 of the shared catch database). It joins one chat
-- channel shared by every addon user the game lets meet there, keeps it out of every chat window, filters its lines,
-- leaves the player a chat channel slot, and walks a fixed list of fallback channels when one is locked. It knows
-- nothing about records: Comm sends the HELLO through it and Share listens to its state (CHANNEL_STATE).
-- See specs/004-public-channel-sync/contracts/channel.md and api.md, research.md R2-R4.
local _, ns = ...
local L = ns.L

local Channel = {}
ns.Channel = Channel

-- VERIFY(V19): addon messages in a custom channel work in Forever; false takes the channel out of the release (FR-026)
Channel.AVAILABLE = true

-- The main channel and its fallbacks, walked in this order by every client (contracts/channel.md "Names").
Channel.NAMES = { "OneKeyFishingShare", "OneKeyFishingShare2", "OneKeyFishingShare3", "OneKeyFishingShare4",
    "OneKeyFishingShare5", "OneKeyFishingShare6" }

local JOIN_DELAY_MIN, JOIN_DELAY_MAX = 30, 60 -- seconds after a login: the player's own channels come first
local JOIN_CHECK = 5 -- seconds until a join without a notice is checked by the channel's number
local LOCK_GRACE_MIN, LOCK_GRACE_MAX = 10, 20 -- seconds an addon owner has to undo a lock before everybody moves
local KICK_REJOIN = 60 -- seconds before joining again after a kick
local MAX_KICKS = 3 -- the third kick in a session counts as a ban
local FREE_SLOTS = 2 -- chat channel slots that must be free to join: one always stays the player's (FR-005)
local POPUP = "CHAT_CHANNEL_PASSWORD" -- the game's password prompt for a locked channel

local lowerNames = {}
for index, name in ipairs(Channel.NAMES) do
    lowerNames[name:lower()] = index
end

local current -- the index joined or being joined (1 main, 2..6 fallback)
local joined, joining = false, false
local leftAt -- GetTime() of the addon's own last leave: a YOU_LEFT soon after is its own, not the player's
local locked = {} -- index -> true: found locked or banned this session
local refused = false -- the game refuses the channel itself (a Trial account, an invalid name): until logout
local left = false -- the player left by hand: out until the next login
local gaveWay = false -- the slot was given up for the player: back when two slots are free
local wayLinePrinted = false
local loginReady = false -- the login delay has passed (or a /reload: the channel was there already)
local kicks, rejoinAt = 0, nil -- rejoinAt: GetTime() before which a kicked client does not join again
local owner = false -- this client owns the current channel (OWNER_CHANGED or CHANNEL_OWNER naming it)
local sawPassword = false -- a password set by a player not heard announcing, on the current channel
local lockTimer -- the token of the wait before moving on
local selfHeals = 0
local lastState, lastIndex

function Channel.IsEnabled()
    return ns.db ~= nil and ns.db.settings.shareChannel == true
end

local indexByName = {} -- a channel name as the game gives it -> its index or false (the filters see every line)

-- The index (1 main, 2..6 fallback) of one of our channel names, compared without case, or nil.
local function IndexOf(name)
    if type(name) ~= "string" or (issecretvalue and issecretvalue(name)) then
        return nil
    end
    local index = indexByName[name]
    if index == nil then
        index = lowerNames[name:lower()] or false
        indexByName[name] = index
    end
    return index or nil
end

function Channel.IsOurs(name)
    return IndexOf(name) ~= nil
end

-- The chat channels a player may be in (20 in Forever), or nil when the game does not say.
local function MaxChannels()
    return Constants and Constants.ChatFrameConstants and Constants.ChatFrameConstants.MaxChatChannels
end

-- Chat channel slots still free.
function Channel.FreeSlots()
    return (MaxChannels() or 20) - (C_ChatInfo.GetNumActiveChannels and C_ChatInfo.GetNumActiveChannels() or 0)
end

-- The channel's number while the player is in it (GetChannelName gives 0 otherwise), or nil.
local function NumberOf(index)
    local number = GetChannelName(Channel.NAMES[index])
    return (type(number) == "number" and number > 0) and number or nil
end

-- The first index not found locked this session, or nil.
local function NextIndex()
    for index = 1, #Channel.NAMES do
        if not locked[index] then
            return index
        end
    end
end

-- Why the channel must not be used at all, or nil: the release, the settings, the notice that names it.
local function Gate()
    if not Channel.AVAILABLE then
        return "unavailable"
    end
    if not (ns.db and ns.Share.IsEnabled() and Channel.IsEnabled()) then
        return "off"
    end
    if ns.Share.NoticeOwed() then
        return "notice"
    end
end

-- data-model.md "State of the channel", and the index.
function Channel.GetState()
    local gate = Gate()
    if gate then
        return gate
    end
    local pause = ns.Comm.GetPause()
    if pause and pause ~= "unavailable" then
        return "paused", current
    end
    if left then
        return "left"
    end
    if refused or pause == "unavailable" or (not joined and not joining and not NextIndex()) then
        return "locked"
    end
    if joined then
        return "in", current
    end
    if gaveWay or (loginReady and not joining and Channel.FreeSlots() < FREE_SLOTS) then
        return "noslot"
    end
    return "waiting"
end

function Channel.GetNumber()
    return joined and current and NumberOf(current) or nil
end

local function Notify()
    local state, index = Channel.GetState()
    if state ~= lastState or index ~= lastIndex then
        lastState, lastIndex = state, index
        ns.Fire("CHANNEL_STATE", state, index)
    end
end

---------------------------------------------------------------------------
-- Hiding (FR-003, FR-004; research R2)
---------------------------------------------------------------------------
-- A chat window shows the lines and notices of the channels in its own list only, so the channel is taken out of
-- every list that has it (also after the game reloads the lists).
-- VERIFY(V21): removing the channel from the chat windows hides it there; the filters drop its notices and lines
local function RemoveFromWindows()
    if not current then
        return
    end
    local name = Channel.NAMES[current]
    for i = 1, NUM_CHAT_WINDOWS or 10 do
        local window = _G["ChatFrame" .. i]
        if window and window.ContainsChannel and window:ContainsChannel(name) then
            window:RemoveChannel(name)
        end
    end
end

-- The second layer: every line whose channel (the 9th argument) is ours is dropped; a secret value is left alone.
local function HideOurs(_, _, ...)
    return IndexOf((select(9, ...))) ~= nil
end

if ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter then
    for _, event in ipairs({ "CHAT_MSG_CHANNEL", "CHAT_MSG_CHANNEL_NOTICE", "CHAT_MSG_CHANNEL_NOTICE_USER",
        "CHAT_MSG_CHANNEL_JOIN", "CHAT_MSG_CHANNEL_LEAVE" }) do
        ChatFrameUtil.AddMessageEventFilter(event, HideOurs)
    end
end

---------------------------------------------------------------------------
-- Joining and leaving
---------------------------------------------------------------------------
local Update

local function OnJoined()
    joining, joined = false, true
    sawPassword, lockTimer, owner = false, nil, false
    RemoveFromWindows()
    Notify()
end

local function Leave()
    if current and (joined or joining) then
        leftAt = GetTime()
        pcall(LeaveChannelByName, Channel.NAMES[current])
    end
    joined, joining = false, false
    sawPassword, lockTimer, owner = false, nil, false
end

-- Marks an index locked for the session and goes on with the next one.
local function Lock(index)
    if not index then
        return
    end
    locked[index] = true
    if index == current then
        Leave()
    end
    Notify()
    Update()
end

local function Join(index)
    current, joining = index, true
    -- VERIFY(V19): an addon can join a custom channel this way, without a key press; a nil first value means the game
    -- refuses the channel itself
    local ok, kind = pcall(JoinTemporaryChannel, Channel.NAMES[index])
    if not ok or kind == nil then
        joining, refused = false, true
        Notify()
        return
    end
    C_Timer.After(JOIN_CHECK, function()
        if joining and current == index then
            if NumberOf(index) then
                OnJoined()
            else
                Lock(index) -- no notice and not in it: the channel cannot be used (a password, a ban)
            end
        end
    end)
    Notify()
end

-- Joins or leaves as the settings, the notice, the pause, the slots, the locks and a kick allow.
Update = function()
    if Gate() then
        if joined or joining then
            Leave()
        end
        Notify()
        return
    end
    local pause = ns.Comm.GetPause()
    if pause == "unavailable" and (joined or joining) then
        Leave() -- the game refuses addon messages: the channel would only take a slot
    end
    if left or refused or not loginReady or joined or joining or pause or (rejoinAt and GetTime() < rejoinAt) then
        Notify()
        return
    end
    local index = NextIndex()
    if index and not gaveWay and Channel.FreeSlots() >= FREE_SLOTS then
        Join(index)
    end
    Notify()
end
Channel.Update = Update

-- The setting "Use the public channel" (FR-021): joins or leaves at once, with no login delay.
function Channel.SetEnabled(on)
    ns.db.settings.shareChannel = on and true or false
    if on then
        loginReady = true
    end
    Update()
    ns.Fire("SETTINGS_CHANGED", "shareChannel")
end

-- Two slots free again after giving way, or after none were free: join (Share's channel rounds and CHANNEL_UI_UPDATE).
function Channel.CheckSlots()
    if gaveWay and Channel.FreeSlots() >= FREE_SLOTS then
        gaveWay = false
    end
    Update()
end

-- Comm: two refusals in a row on the channel path; the channel cannot carry messages any more.
function Channel.OnRefused()
    Lock(current)
end

---------------------------------------------------------------------------
-- Notices: joins, leaves, locks, kicks, bans, owners (research R4)
---------------------------------------------------------------------------
local function IsMe(name)
    local me = UnitName("player")
    return type(name) == "string" and name ~= "" and type(me) == "string" and ns.SameCharacter(name, me)
end

-- Clears a password on a channel this client owns (an addon client undoing a lock, as Total RP 3 does).
local function SelfHeal()
    if current then
        -- VERIFY(V24): an addon client that owns the channel can clear its password
        pcall(SetChannelPassword, Channel.NAMES[current], "")
        selfHeals = selfHeals + 1
    end
    sawPassword, lockTimer = false, nil
end

-- The 10-20 s wait before moving on, in which an addon owner may undo the lock; one at a time.
local function WaitLock()
    if lockTimer then
        return
    end
    local token = {}
    lockTimer = token
    C_Timer.After(math.random(LOCK_GRACE_MIN, LOCK_GRACE_MAX), function()
        if lockTimer == token then
            lockTimer = nil
            Lock(current)
        end
    end)
end

-- A password ("password") or moderation ("moderation") set by `actor` on the channel the addon is in.
local function LockSeen(actor, kind)
    if ns.Share.HeardInChannel(actor) then
        lockTimer, sawPassword = nil, false -- an addon client: the undo of a lock (or its own change), nobody moves
        return
    end
    sawPassword = sawPassword or kind == "password"
    -- Only a password can be undone: Forever's interface code has no call that turns moderation off.
    if sawPassword then
        if owner then
            SelfHeal()
            return
        end
        pcall(DisplayChannelOwner, Channel.NAMES[current]) -- its CHANNEL_OWNER notice says whether this client owns it
    end
    WaitLock() -- or the wait for the first lock goes on
end

local function Kicked()
    kicks, left = kicks + 1, false
    joined, joining = false, false
    if kicks >= MAX_KICKS then
        Lock(current)
        return
    end
    rejoinAt = GetTime() + KICK_REJOIN -- no Update joins before then (slots, pauses and rounds call it too)
    Notify()
    C_Timer.After(KICK_REJOIN, Update)
end

-- VERIFY(V24): the tokens and arguments of the channel notices are as on Retail (research R4)
local function OnNotice(_, token, player, _, _, actor, _, _, _, name)
    local index = IndexOf(name)
    if not index or (issecretvalue and issecretvalue(token)) then
        return
    end
    local by = (type(actor) == "string" and actor ~= "") and actor or player
    if token == "YOU_CHANGED" or token == "YOU_JOINED" then
        if index == current and (joining or joined) then
            OnJoined()
        elseif index ~= current then
            pcall(LeaveChannelByName, Channel.NAMES[index]) -- another of ours (an old session's): one is enough
        end
    elseif token == "YOU_LEFT" then
        if index ~= current then
            return
        end
        if leftAt and GetTime() - leftAt < JOIN_CHECK then
            return -- the addon's own leave
        elseif joined then
            joined, left = false, true -- the player left it by hand (or another addon did): out until the next login
            Notify()
        end
    elseif index ~= current then
        return
    elseif token == "WRONG_PASSWORD" or token == "BANNED" or token == "WRONG_FACTION" then
        Lock(index)
    elseif token == "TRIAL_RESTRICTED" or token == "INVALID_NAME" then
        Leave()
        refused = true
        Notify()
    elseif token == "PASSWORD_CHANGED" or token == "MODERATION_ON" then
        if joined and not IsMe(by) then
            LockSeen(by, token == "PASSWORD_CHANGED" and "password" or "moderation")
        end
    elseif token == "OWNER_CHANGED" or token == "CHANNEL_OWNER" then
        owner = IsMe(player)
        if owner and sawPassword then
            SelfHeal()
        end
    elseif token == "PLAYER_KICKED" then
        if IsMe(player) then
            Kicked()
        end
    elseif token == "PLAYER_BANNED" then
        if IsMe(player) then
            left = false -- a YOU_LEFT before this notice was the ban's, not a leave by hand (as for a kick)
            Lock(index)
        end
    elseif token == "MUTED" then
        Lock(index)
    end
end

ns.RegisterEvent("CHAT_MSG_CHANNEL_NOTICE", OnNotice)
ns.RegisterEvent("CHAT_MSG_CHANNEL_NOTICE_USER", OnNotice)

-- The game's password prompt for one of our names: closed in the same frame, and the name counts as locked.
ns.RegisterEvent("CHANNEL_PASSWORD_REQUEST", function(_, channel)
    local index = IndexOf(channel)
    if index then
        -- VERIFY(V21): hiding the prompt in the same frame leaves no visible flash
        StaticPopup_Hide(POPUP)
        Lock(index)
    end
end)

---------------------------------------------------------------------------
-- The player's channel limit (FR-005; research R3)
---------------------------------------------------------------------------
-- VERIFY(V23): the game reports the refused join of the player's own channel with this text, on one of the events
local limitText -- built once: every system line and UI error is compared with it

local function OnLimit(text)
    if not joined or joining or (issecretvalue and issecretvalue(text)) then
        return
    end
    if limitText == nil then
        limitText = ERR_TOO_MANY_CHAT_CHANNELS and MaxChannels() and ERR_TOO_MANY_CHAT_CHANNELS:format(MaxChannels())
            or false
    end
    if text ~= limitText then
        return
    end
    Leave()
    gaveWay = true
    if not wayLinePrinted then
        wayLinePrinted = true
        ns.Print(L["OneKeyFishing left its hidden channel to free a chat channel slot. Try joining again."])
    end
    Notify()
end

ns.RegisterEvent("CHAT_MSG_SYSTEM", function(_, text) OnLimit(text) end)
ns.RegisterEvent("UI_ERROR_MESSAGE", function(_, _, text) OnLimit(text) end)
ns.RegisterEvent("CHANNEL_UI_UPDATE", Channel.CheckSlots)

---------------------------------------------------------------------------
-- Login, reload, settings, pauses
---------------------------------------------------------------------------
-- What lasts until the next login must survive a /reload (left by hand, locked names, kicks, a slot given up, a lock
-- still waited on): kept in the character's saved variables from PLAYER_LOGOUT, which a /reload fires too, to the
-- next PLAYER_ENTERING_WORLD.
ns.RegisterEvent("PLAYER_LOGOUT", function()
    ns.charDB.channelSession = { left = left, refused = refused, gaveWay = gaveWay, wayLinePrinted = wayLinePrinted,
        kicks = kicks, rejoinAt = rejoinAt, locked = locked, lockWait = lockTimer ~= nil, sawPassword = sawPassword }
end)

local function Restore(saved)
    left, refused = saved.left == true, saved.refused == true
    gaveWay, wayLinePrinted = saved.gaveWay == true, saved.wayLinePrinted == true
    kicks, rejoinAt = tonumber(saved.kicks) or 0, tonumber(saved.rejoinAt)
    for index in pairs(type(saved.locked) == "table" and saved.locked or {}) do
        if Channel.NAMES[index] then
            locked[index] = true
        end
    end
    if rejoinAt and rejoinAt > GetTime() then
        C_Timer.After(rejoinAt - GetTime(), Update) -- GetTime() goes on across a /reload
    end
    return saved.lockWait == true, saved.sawPassword == true
end

-- VERIFY(V22): joined this late, the channel leaves General, Trade and the player's channels on their numbers
ns.RegisterEvent("PLAYER_ENTERING_WORLD", function(_, isInitialLogin, isReloadingUi)
    local saved = ns.charDB.channelSession
    ns.charDB.channelSession = nil -- read once; a real login starts afresh
    if isReloadingUi then
        local waitLock, password
        if type(saved) == "table" then
            waitLock, password = Restore(saved)
        end
        -- The client is still in it after a /reload: taken as joined (a second one of our names is left).
        for index, name in ipairs(Channel.NAMES) do
            if NumberOf(index) then
                if joined then
                    pcall(LeaveChannelByName, name)
                else
                    current, joined = index, true
                end
            end
        end
        loginReady = true
        RemoveFromWindows()
        if joined and waitLock then
            -- A lock seen just before the /reload: the wait starts again, and who owns the channel is asked again.
            sawPassword = password
            if password then
                pcall(DisplayChannelOwner, Channel.NAMES[current])
            end
            WaitLock()
        end
        Update()
    elseif isInitialLogin then
        C_Timer.After(math.random(JOIN_DELAY_MIN, JOIN_DELAY_MAX), function()
            loginReady = true
            Update()
        end)
    elseif joined then
        RemoveFromWindows()
    end
end)

ns.RegisterEvent("UPDATE_CHAT_WINDOWS", function()
    if joined then
        RemoveFromWindows()
    end
end)

ns.On("SETTINGS_CHANGED", function(key)
    if key == "shareDB" then
        Update()
    end
end)

ns.On("SHARE_PAUSE", function()
    Update()
end)

-- English lines for /okf debug.
function Channel.Describe()
    local state, index = Channel.GetState()
    local lockedList = {}
    for i in pairs(locked) do
        table.insert(lockedList, tostring(i))
    end
    table.sort(lockedList)
    return {
        ("channel: %s%s, free slots %d, locked %s, kicks %d, owner %s, self-heals %d"):format(state,
            index and (" (index " .. index .. ")") or "", Channel.FreeSlots(),
            #lockedList > 0 and table.concat(lockedList, ",") or "none", kicks, tostring(owner), selfHeals),
    }
end
