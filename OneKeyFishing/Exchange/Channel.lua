-- Channel: the hidden public channel of the catch exchange (part 3 of the shared catch database). It joins one chat
-- channel shared by every addon user the game lets meet there, keeps it out of every chat window, filters its lines,
-- leaves the player a chat channel slot, and walks a fixed list of fallback channels when one is locked. It knows
-- nothing about records: Comm sends the HELLO through it and Share listens to its state (CHANNEL_STATE).
-- See specs/004-public-channel-sync/contracts/channel.md and api.md, research.md R2-R4; it ships again since spec 016
-- (specs/016-public-channel-return).
local _, ns = ...
local L = ns.L

local Channel = {}
ns.Channel = Channel

-- V19 failed on 2026-11-06 (the server refused addon messages in a custom channel; spec 010 switched the channel off)
-- and passes again since 2026-11-16 (docs/forever-api.md). False is the kill switch: no join, and a channel of ours
-- left joined is left once at login (spec 004 FR-026, spec 016).
Channel.AVAILABLE = true

-- The main channel and its fallbacks, walked in this order by every client (contracts/channel.md "Names").
Channel.NAMES = { "OneKeyFishingShare", "OneKeyFishingShare2", "OneKeyFishingShare3", "OneKeyFishingShare4",
    "OneKeyFishingShare5", "OneKeyFishingShare6" }

local JOIN_DELAY_MIN, JOIN_DELAY_MAX = 30, 60 -- seconds after a login: the player's own channels come first
local JOIN_CHECK = 5 -- seconds between the checks of a join without a notice by the channel's number
local JOIN_TRIES = 3 -- checks before such a join counts as locked: a slow server (a login's lag) confirms late
local LEAVE_ECHO = 5 -- seconds in which a YOU_LEFT is the answer to the addon's own leave
local LOCK_GRACE_MIN, LOCK_GRACE_MAX = 10, 20 -- seconds an addon owner has to undo a lock before everybody moves
local KICK_REJOIN = 60 -- seconds before joining again after a kick
local REJOIN_MARGIN = 0.5 -- a timer may read GetTime() a hair before rejoinAt: that counts as reached
local MAX_KICKS = 3 -- the third kick in a session counts as a ban
local FREE_SLOTS = 2 -- chat channel slots that must be free to join: one always stays the player's (FR-005)
local NIL_JOINS = 3 -- joins with no result in a session before they count as the game refusing the channel
local POPUP = "CHAT_CHANNEL_PASSWORD" -- the game's password prompt for a locked channel

local lowerNames = {}
for index, name in ipairs(Channel.NAMES) do
    lowerNames[name:lower()] = index
end

local current -- the index joined or being joined (1 main, 2..6 fallback)
local joined, joining = false, false
local joins = 0 -- joins started this session (CHANNEL_STATE passes it: a new one, not a pause's end, means a new join)
-- The addon's own leaves whose YOU_LEFT has not come yet: index -> GetTime() of each, oldest first. A YOU_LEFT of
-- that name is the answer to the oldest one still within LEAVE_ECHO (while a join of the name waits, as long as that
-- join may wait), not the player's leave, and uses it up; older ones (a leave the server never answered) are dropped.
local echoes = {}
local locked = {} -- index -> true: found locked or banned this session
-- Why the channel is refused until the next real login (a /reload keeps it), or false (spec 016 data model):
--   "game"    the game refuses the channel itself (a Trial account, an invalid name, a join with no result);
--   "server"  the server refuses addon messages in custom channels (two NOT_ALLOWED_IN_CHANNEL on one join): every name
--             would be refused alike, so no fallback is tried (research R1).
local refused = false
local left = false -- the player left by hand: out until the next login
local gaveWay = false -- the slot was given up for the player: back when two slots are free
local wayLinePrinted = false
local loginReady = false -- the login delay has passed (or a /reload: the channel was there already)
local kicks, rejoinAt = 0, nil -- rejoinAt: GetTime() before which a kicked client does not join again
local nilJoins = 0 -- joins this session that returned nothing (Join)
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
    if type(name) ~= "string" or ns.IsSecret(name) then
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
        ns.Fire("CHANNEL_STATE", state, index, joins)
    end
end

---------------------------------------------------------------------------
-- Hiding (FR-003, FR-004; research R2)
---------------------------------------------------------------------------
-- A chat window shows the lines and notices of the channels in its own list only, so the channel is taken out of
-- every list that has it (also after the game reloads the lists).
-- VERIFY(V21): removing the channel from every chat window and the CHAT_MSG_CHANNEL* filters hide all its lines
-- index: one of the names (default: the current one).
local function RemoveFromWindows(index)
    index = index or current
    if not index then
        return
    end
    local name = Channel.NAMES[index]
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

-- Every leave of one of our names goes through here, so its YOU_LEFT is known for the addon's own.
-- VERIFY(V41): one YOU_LEFT per leave of addon code, answered before a later join of the name
-- (one per typed leave seen on 2026-11-06; a join typed right after a leave in one macro was lost).
local function LeaveName(index)
    echoes[index] = echoes[index] or {}
    table.insert(echoes[index], GetTime())
    pcall(LeaveChannelByName, Channel.NAMES[index])
end

-- A leave of the name may still get its answer (as long as a join may wait): a second join notice of a name already
-- left is not a new join.
local function Owed(index)
    local owed = echoes[index]
    return owed ~= nil and GetTime() - owed[#owed] < JOIN_CHECK * JOIN_TRIES
end

local function Leave()
    if current and (joined or joining) then
        LeaveName(current)
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
    current, joining, joins = index, true, joins + 1
    local join = joins
    -- An addon can join a custom channel this way, without a key press (seen on 2026-11-06, 2026-11-16 and
    -- 2026-11-17: it returns 0, then YOU_CHANGED).
    local ok, kind = pcall(JoinTemporaryChannel, Channel.NAMES[index])
    if not ok then
        joining, refused = false, "game"
        Notify()
        return
    end
    if kind == nil then
        -- At the 20-channel limit the join returns nothing (seen 2026-11-17), also when the count of active channels
        -- has not caught up with the player's joins still on their way: wait for two free slots, as after giving
        -- way. A refusal of the channel itself (a Trial account, not seen) may look the same, so the NIL_JOINS-th
        -- empty result in a session counts as the game's refusal and stops the retries.
        nilJoins = nilJoins + 1
        joining = false
        if nilJoins >= NIL_JOINS then
            refused = "game"
        else
            gaveWay = true
        end
        Notify()
        return
    end
    local tries = 0
    local function Check()
        if not joining or joins ~= join then
            return
        end
        tries = tries + 1
        if NumberOf(index) then
            OnJoined()
        elseif tries < JOIN_TRIES then
            C_Timer.After(JOIN_CHECK, Check)
        else
            Lock(index) -- no notice and not in it: the channel cannot be used (a password, a ban)
        end
    end
    C_Timer.After(JOIN_CHECK, Check)
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
    if left or refused or not loginReady or joined or joining or pause
        or (rejoinAt and GetTime() < rejoinAt - REJOIN_MARGIN) then
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
    ns.Share.CloseNotice() -- set on the page that says what is shared: the notice counts as read
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

-- Comm: two refusals on the channel path. reason "server": two NOT_ALLOWED_IN_CHANNEL notices on one join, the server
-- refusing addon messages in every custom channel (as on 2026-11-06): leave and stop until the next login, since a
-- fallback would only be joined, refused and left in turn (spec 016 research R1). No reason: refused sends, which
-- belong to this channel (moderated, muted, gone): lock it and move to the next one.
function Channel.OnRefused(reason)
    if reason == "server" then
        Leave()
        refused = "server"
        Notify()
        return
    end
    Lock(current)
end

---------------------------------------------------------------------------
-- Notices: joins, leaves, locks, kicks, bans, owners (research R4)
---------------------------------------------------------------------------
local function IsMe(name)
    local me = ns.PlayerName()
    return type(name) == "string" and name ~= "" and type(me) == "string" and ns.SameCharacter(name, me)
end

-- Clears a password on a channel this client owns (an addon client undoing a lock, as Total RP 3 does).
local function SelfHeal()
    if current then
        -- An addon client that owns the channel can clear its password (V24, seen in game)
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

-- The tokens and arguments of the channel notices are as on Retail (research R4). Seen in game on 2026-11-16:
-- YOU_CHANGED (a join), YOU_LEFT, PASSWORD_CHANGED and OWNER_CHANGED with the player's "First Last" in argument 2
-- (argument 5 empty), WRONG_PASSWORD after the password request; SET_MODERATOR names the new owner by the first name
-- only and is not read (ownership follows OWNER_CHANGED and CHANNEL_OWNER).
local function OnNotice(_, token, player, _, _, actor, _, _, _, name)
    local index = IndexOf(name)
    if not index or ns.IsSecret(token) then
        return
    end
    local by = (type(actor) == "string" and actor ~= "") and actor or player
    if token == "YOU_CHANGED" or token == "YOU_JOINED" then
        if index == current and (joining or joined) then
            OnJoined()
        elseif index ~= current and not Owed(index) then
            LeaveName(index) -- another of ours (an old session's, or one the game rejoined with the channel off)
            RemoveFromWindows(index)
        end
    elseif token == "YOU_LEFT" then
        local owed, own = echoes[index] or {}, false
        local wait = (joining and index == current) and JOIN_CHECK * JOIN_TRIES or LEAVE_ECHO
        while owed[1] and not own do
            own = GetTime() - table.remove(owed, 1) < wait
        end
        if not owed[1] then
            echoes[index] = nil
        end
        if own or index ~= current then
            return
        elseif joined or joining then
            -- The player left it by hand (or another addon did), also before the join was confirmed: out until the
            -- next login.
            joined, joining, left = false, false, true
            Notify()
        end
    elseif index ~= current then
        return
    elseif token == "NOT_ALLOWED_IN_CHANNEL" then
        -- The server refused addon messages in the channel this way on 2026-11-06 (gone on 2026-11-16), though the
        -- send returned 0; two on one join stop the channel for the session (Comm.ChannelRefused, spec 016).
        if joined then
            ns.Comm.ChannelRefused(true)
        end
    elseif token == "WRONG_PASSWORD" or token == "BANNED" or token == "WRONG_FACTION" then
        Lock(index)
    elseif token == "TRIAL_RESTRICTED" or token == "INVALID_NAME" then
        Leave()
        refused = "game"
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
    -- VERIFY(V24): PLAYER_KICKED, PLAYER_BANNED and MUTED name the player in argument 2, as on Retail
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
        -- VERIFY(V21): hiding the password prompt in the same frame leaves no visible flash and no blocked action
        StaticPopup_Hide(POPUP)
        Lock(index)
    end
end)

---------------------------------------------------------------------------
-- The player's channel limit (FR-005; research R3)
---------------------------------------------------------------------------
-- The refused join at the 20-channel limit comes as this text ("You can only be in 20 channels at a time."), read on
-- CHAT_MSG_SYSTEM and UI_ERROR_MESSAGE; the addon gave way on it in game (2026-11-17, V23).
local limitText -- built once: every system line and UI error is compared with it

local function OnLimit(text)
    if not joined or joining or ns.IsSecret(text) then
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
    -- A 1.2.0 record holds true for the game's refusal (spec 016 data model).
    left = saved.left == true
    refused = (saved.refused == true or saved.refused == "game") and "game" or saved.refused == "server" and "server"
        or false
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

-- VERIFY(V22): joined 30-60 s after the login, General, Trade and the player's channels keep their numbers
ns.RegisterEvent("PLAYER_ENTERING_WORLD", function(_, isInitialLogin, isReloadingUi)
    local saved = ns.charDB.channelSession
    ns.charDB.channelSession = nil -- read once; a real login starts afresh
    if Gate() == "unavailable" then
        -- The channel is off in this release: one an earlier build left joined is left, out of the windows, and its
        -- notices are filtered (no chat line). The next login finds none.
        for index in ipairs(Channel.NAMES) do
            if NumberOf(index) then
                LeaveName(index)
                RemoveFromWindows(index)
            end
        end
        return
    end
    if isReloadingUi then
        local waitLock, password
        if type(saved) == "table" then
            waitLock, password = Restore(saved)
        end
        -- The client is still in it after a /reload: taken as joined (a second one of our names, or one found locked
        -- or refused whose leave the /reload cut off, is left). Not after a leave by hand: one joined again is the
        -- player's.
        for index in ipairs(Channel.NAMES) do
            if NumberOf(index) and not left then
                if joined or locked[index] or refused then
                    LeaveName(index)
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
        ("channel: %s%s, free slots %d, locked %s, kicks %d, owner %s, self-heals %d, refused %s"):format(state,
            index and (" (index " .. index .. ")") or "", Channel.FreeSlots(),
            #lockedList > 0 and table.concat(lockedList, ",") or "none", kicks, tostring(owner), selfHeals,
            tostring(refused)),
    }
end
