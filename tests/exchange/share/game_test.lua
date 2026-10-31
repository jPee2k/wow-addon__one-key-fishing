-- Share.lua: the game node bound to Comm (HELLO triggers, a full exchange with a fake peer, pauses, the setting,
-- the state). The notice was closed in an earlier session. The tests run in order and share one login.

local FISH = 6291
local PEER_ID = "pppppppp"

OneKeyFishingDB = { shareNotice = true }
in_guild = true
player_map_id = 1415
player_map_position = { 0.43, 0.78 }
fishing_rank = 230
reset_popup()
load_addon()
local login = GetTime()

local Share, Store = ns.Share, ns.Share.Store
local L = ns.L
local ALL = { range = 3, source = "all" }

local sentSince = addon_sent_since

---------------------------------------------------------------------------
-- A fake peer: a test node whose messages reach the addon through CHAT_MSG_ADDON as "Peer-Realm", and which
-- hears what the addon sends to it (whispers joined from their parts) and to the group.
---------------------------------------------------------------------------
local peerStore = { myID = PEER_ID, mine = {}, records = { [PEER_ID] = prove({ id = PEER_ID, epoch = 0, seq = 3,
    builds = { ["1.60.1"] = { ["1415:3:47"] = catch_cell(30, 2, { [FISH] = { 30, 30 } }) } } }) } }
local peer = Share.NewNode(peerStore, {
    now = GetTime,
    time = GetTime,
    after = function(delay, fn) C_Timer.After(delay, fn) end,
    send = function(_, text)
        C_Timer.After(0.1, function() receive_addon("OKF1", text, "WHISPER", "Peer-Realm") end)
    end,
    broadcast = function(text)
        C_Timer.After(0.1, function() receive_addon("OKF1", text, "PARTY", "Peer-Realm") end)
    end,
    forEachFriend = function() end,
    canSend = function() return true end,
    absorbed = function() return {} end,
    seedEpoch = function() return 0 end,
    encode = Share.Encode,
    decode = Share.Decode,
})
local delivered, partsOf = #addon_sent, {}

-- Hands the addon's new whispers to Peer-Realm and its group messages to the peer.
local function pump()
    while delivered < #addon_sent do
        delivered = delivered + 1
        local message = addon_sent[delivered]
        local via = message.chatType == "WHISPER" and "whisper" or "group"
        if (message.chatType == "WHISPER" and message.target == "Peer-Realm") or message.chatType == "PARTY" then
            local head, id, part, total, chunk = message.text:match("^(%u%w%w)#(%w+)%.(%d+)%.(%d+) (.*)$")
            if head then
                local key = head .. id
                partsOf[key] = partsOf[key] or {}
                partsOf[key][tonumber(part)] = chunk
                if #partsOf[key] == tonumber(total) then
                    peer:Receive("w:Me-Realm", via, head .. " " .. table.concat(partsOf[key]))
                    partsOf[key] = nil
                end
            else
                peer:Receive("w:Me-Realm", via, message.text)
            end
        end
    end
end

-- Runs the clock in half-second steps, the peer greeting every 10 minutes like a real client; stops early when
-- until() is true.
local peerHello = -math.huge
local function run(seconds, untilFn)
    local stop = GetTime() + seconds
    while GetTime() < stop and not (untilFn and untilFn()) do
        if GetTime() - peerHello >= 600 then
            peerHello = GetTime()
            peer:Hello()
        end
        advance(0.5)
        pump()
    end
end

---------------------------------------------------------------------------
-- HELLO triggers
---------------------------------------------------------------------------
test("the popup is not shown again once it was closed", function()
    eq(rawget(_G, "last_popup"), nil, "no popup")
end)

test("the first HELLO goes to the guild 60-120 s after the login", function()
    advance(59)
    eq(#sentSince(0, "GUILD"), 0, "not before 60 s")
    advance(61)
    local hellos = sentSince(0, "GUILD")
    eq(#hellos, 1, "one HELLO")
    assert(hellos[1].text:find("^H %w%w%w%w 0 %d+ %w+$"), hellos[1].text)
    assert(hellos[1].at - login >= 60 and hellos[1].at - login <= 122, "within 60-120 s")
    assert(not hellos[1].text:find(ns.db.shared.myID, 1, true), "no anonymous ID")
end)

local joined

test("joining a group sends a HELLO to it within 30 s; another roster change within 2 min sends none", function()
    local before = #addon_sent
    group_type = "party"
    joined = GetTime()
    fire("GROUP_ROSTER_UPDATE")
    advance(32) -- 5-30 s, plus the 2 s broadcast pace behind the same HELLO to the guild
    eq(#sentSince(before, "PARTY"), 1, "HELLO to the party")
    group_members = 3
    fire("GROUP_ROSTER_UPDATE")
    advance(60)
    eq(#sentSince(before, "PARTY"), 1, "no extra HELLO")
end)

---------------------------------------------------------------------------
-- A full exchange
---------------------------------------------------------------------------
test("a full exchange with a peer in the group ends within 5 minutes of the join", function()
    run(600, function() return ns.db.shared.records[PEER_ID .. "@0"] ~= nil end)
    assert(GetTime() - joined <= 300, "within 5 minutes: " .. (GetTime() - joined))
    local view = ns.CatchDB.Query(1415, "47", ALL)
    eq(view.catches, 30, "the peer's catches count")
    eq(view.players, 1, "from one player")
    local stored = ns.db.shared.records[PEER_ID .. "@0"]
    eq(stored.seq, 3, "stored under <id>@<epoch>")
    assert(stored.seen, "with seen")
end)

test("the peer got this account's record too", function()
    fish_cast({ { FISH, 1 } })
    run(3600) -- the cooldowns run out; a later round finds the new catch
    local own = ns.db.shared.records[ns.db.shared.myID]
    eq(peerStore.records[ns.db.shared.myID .. "@" .. own.epoch].seq, own.seq, "the newest version")
end)

-- Every string in a saved table (keys and values), for the check that no name was saved.
local function strings(value, out, seen)
    out, seen = out or {}, seen or {}
    if type(value) == "string" then
        table.insert(out, value)
    elseif type(value) == "table" and not seen[value] then
        seen[value] = true
        for key, field in pairs(value) do
            strings(key, out, seen)
            strings(field, out, seen)
        end
    end
    return out
end

test("no name of a peer reaches the saved data", function()
    for _, text in ipairs(strings({ OneKeyFishingDB, OneKeyFishingCharDB })) do
        assert(not text:find("Peer", 1, true), "saved: " .. text)
    end
end)

test("the state is active with the exchange of the last hour", function()
    local status = Share.GetStatus()
    eq(status.state, "active", "state")
    eq(status.heard.group, 1, "heard in the group")
    eq(status.exchanged, 1, "exchanged with one player")
    eq(status.records, 2, "own and the peer's record")
    assert(status.traffic > 0, "traffic counted")
    eq(Share.StatusLine(), (L["Exchange: %d players, %s ago"]):format(1,
        ns.Stats.FormatShortTime(status.lastExchange)), "status line")
end)

---------------------------------------------------------------------------
-- Pauses
---------------------------------------------------------------------------
test("SHARE_PAUSE stops the sends, and its end greets again soon", function()
    ns.Fire("SHARE_PAUSE", "combat")
    -- Only the node is paused here (Comm drops its queue on a real pause): what Comm queued before still goes.
    advance(60)
    local before = #addon_sent
    advance(1740)
    eq(#sentSince(before), 0, "nothing sent while paused")
    ns.Fire("SHARE_PAUSE", nil)
    advance(30)
    assert(#sentSince(before, "GUILD") >= 1, "a HELLO after the pause")
end)

test("short pauses in a row after a long one greet once, not once per pause", function()
    local random = math.random
    math.random = function(low, high) -- the longest waits: rounds 15 minutes apart, extra HELLOs after 30 s
        if high then
            return high
        end
        return random(low)
    end
    local before = #addon_sent
    for _ = 1, 1000 do -- until a round greets: the next one is 15 minutes away
        advance(1)
        if #sentSince(before, "GUILD") > 0 then
            break
        end
    end
    assert(#sentSince(before, "GUILD") > 0, "a round greeted")
    ns.Fire("SHARE_PAUSE", "combat")
    advance(610) -- the last HELLO is older than 10 minutes
    before = #addon_sent
    for _ = 1, 5 do
        ns.Fire("SHARE_PAUSE", nil)
        advance(1)
        ns.Fire("SHARE_PAUSE", "combat")
        advance(1)
    end
    ns.Fire("SHARE_PAUSE", nil)
    advance(60)
    math.random = random
    eq(#sentSince(before, "GUILD"), 1, "one HELLO")
end)

test("each pause reason has its status line", function()
    in_combat = true
    eq(Share.GetStatus().state, "paused", "paused")
    eq(Share.StatusLine(), L["Exchange paused: in combat"], "combat")
    in_combat = false
    in_instance = true
    eq(Share.StatusLine(), L["Exchange paused: in an instance"], "instance")
    in_instance = false
    fire("LOADING_SCREEN_ENABLED")
    eq(Share.StatusLine(), L["Exchange paused: loading screen"], "loading")
    fire("LOADING_SCREEN_DISABLED")
    chat_lockdown = true
    eq(Share.StatusLine(), L["Exchange paused: the game restricts addon messages here"], "restricted")
    chat_lockdown = false
    addon_send_result.WHISPER = 11
    ns.Comm.Send("w:Someone", "Wab")
    advance(0)
    eq(Share.StatusLine(), L["Exchange paused: the game asked to slow down"], "lockdown")
    addon_send_result.WHISPER = nil
    advance(65)
    peerHello = -math.huge -- the peer greets again once the pause is over
    run(5)
    eq(Share.GetStatus().state, "active", "active again")
end)

---------------------------------------------------------------------------
-- The setting
---------------------------------------------------------------------------
test("off: nothing sent, nothing accepted, others' records kept but not counted", function()
    local changes = 0
    ns.On("SETTINGS_CHANGED", function() changes = changes + 1 end)
    Share.SetEnabled(false)
    eq(ns.db.settings.shareDB, false, "saved")
    eq(changes, 1, "SETTINGS_CHANGED")
    eq(Share.GetStatus().state, "off", "state")
    eq(Share.StatusLine(), L["Shared catch database is off"], "status line")
    eq(ns.CatchDB.Query(1415, "47", ALL).catches, 1, "only the own catch")
    assert(ns.db.shared.records[PEER_ID .. "@0"], "kept")
    local before, bnBefore = #addon_sent, #bn_sent
    receive_addon("OKF1", "H zzzz 0 1 aaaaaaa", "GUILD", "Other-Realm")
    receive_addon("OKF1", "Rab AAAA", "WHISPER", "Other-Realm")
    advance(3600)
    eq(#sentSince(before), 0, "nothing sent")
    eq(#bn_sent, bnBefore, "nothing sent by Battle.net")
    eq(Share.GetStatus().heard.guild, 0, "nothing heard")
end)

test("on again: others' records count at once and a HELLO follows within 30 s", function()
    local before = #addon_sent
    Share.SetEnabled(true)
    eq(ns.CatchDB.Query(1415, "47", ALL).catches, 31, "the peer's catches again")
    advance(30)
    assert(#sentSince(before, "GUILD") >= 1, "HELLO")
end)

test("nobody heard for 30 minutes: alone; the exchange count expires after an hour", function()
    group_type, group_members = nil, nil
    advance(3600)
    local status = Share.GetStatus()
    eq(status.state, "alone", "alone")
    eq(status.exchanged, 0, "nobody in the last hour")
    eq(status.heard.group, 0, "nobody heard in the last hour")
    eq(Share.StatusLine(), L["Nobody to exchange with right now"], "status line")
end)

test("/okf share prints every number of the state", function()
    wipe(chat)
    SlashCmdList.ONEKEYFISHING("share")
    assert(chat_contains("Shared database"), "header")
    assert(chat_contains("Bundled data: version 0, 0 places"), "the seed")
    assert(chat_contains("Records held: 2, "), "records held")
    assert(chat_contains("Players heard in the last hour: guild 0, group 0, friends 0, Battle.net 0"), "heard")
    assert(chat_contains("Players exchanged with in the last hour: 0"), "exchanged")
    assert(chat_contains("Last exchange: "), "last exchange")
    assert(chat_contains("Traffic in the last hour: "), "traffic")
    assert(chat_contains("Nobody to exchange with right now"), "state")
    assert(not chat_contains(ns.db.shared.myID), "no anonymous ID")
    assert(not chat_contains("Peer"), "no name")
end)

test("/okf debug has a Shared database section without the ID or a name", function()
    local report
    local show = ns.ShowCopyWindow
    ns.ShowCopyWindow = function(_, text) report = text end
    ns.ShowReport()
    ns.ShowCopyWindow = show
    assert(report:find("-- Shared database --", 1, true), "section")
    assert(report:find("state alone", 1, true), "state")
    assert(report:find("transport: pause", 1, true), "transport")
    assert(report:find("longest merge step", 1, true), "merge step")
    assert(report:find("own record offered: yes, %d+ bytes encoded for 1 places"), "the own record's size per place")
    assert(not report:find(ns.db.shared.myID, 1, true), "no own ID")
    assert(not report:find("Peer", 1, true), "no name")
end)

test("a peer heard again after an hour without an exchange: the line names the last one, not 0 players", function()
    peerStore.records[PEER_ID].seq = 30 -- the peer's hash differs, so a session is due but has not run yet
    peerHello = -math.huge
    run(1)
    local status = Share.GetStatus()
    eq(status.state, "active", "a peer was heard")
    eq(status.exchanged, 0, "nobody in the last hour")
    eq(Share.StatusLine(), (L["Last exchange: %s ago"]):format(ns.Stats.FormatShortTime(status.lastExchange)),
        "status line")
end)

test("the game refusing every path: unavailable", function()
    in_guild, group_type = true, "party"
    addon_send_result.default, bn_send_result = 9, 9
    for i = 1, 5 do -- one player counts once, so five of them on each path
        ns.Comm.Broadcast("H abcd 0 1 aaaaaaa")
        ns.Comm.Send("w:Someone" .. i, "Wab")
        ns.Comm.Send("b:" .. (10 + i), "Wab")
    end
    advance(60)
    eq(Share.GetStatus().state, "unavailable", "state")
    eq(Share.StatusLine(), L["Exchange unavailable: the game refuses addon messages"], "status line")
end)

---------------------------------------------------------------------------
-- The public channel in /okf share and /okf debug (specs/004-public-channel-sync, US3)
---------------------------------------------------------------------------
test("/okf share prints the channel's line for each state, and none while the release has no channel", function()
    local getState = ns.Channel.GetState
    local cases = {
        { "in", 1, L["Public channel: in use"] },
        { "in", 3, (L["Public channel: in use (fallback channel %d)"]):format(3) },
        { "off", nil, L["Public channel: off"] },
        { "noslot", nil, L["Public channel: no free chat channel slot"] },
        { "locked", nil, L["Public channel: locked or refused by the game"] },
        { "left", nil, L["Public channel: you left it, back at the next login"] },
        { "waiting", nil, L["Public channel: waiting"] },
        { "notice", nil, L["Public channel: waiting"] },
        { "paused", 1, L["Public channel: waiting"] },
    }
    for _, case in ipairs(cases) do
        ns.Channel.GetState = function() return case[1], case[2] end
        wipe(chat)
        SlashCmdList.ONEKEYFISHING("share")
        assert(chat_contains(case[3]), case[1] .. ": " .. case[3])
    end
    ns.Channel.GetState = function() return "unavailable" end
    wipe(chat)
    SlashCmdList.ONEKEYFISHING("share")
    assert(not chat_contains("Public channel"), "no channel line")
    ns.Channel.GetState = getState
end)

test("/okf share counts the channel among the players heard, while the release has the channel", function()
    local heard = Share.GetStatus().heard
    wipe(chat)
    SlashCmdList.ONEKEYFISHING("share")
    local line = L["Players heard in the last hour: guild %d, group %d, friends %d, Battle.net %d, channel %d"]
    assert(chat_contains(line:format(heard.guild, heard.group, heard.friend, heard.bnet, heard.channel)),
        "with the channel")
    ns.Channel.AVAILABLE = false
    wipe(chat)
    SlashCmdList.ONEKEYFISHING("share")
    local part2 = (L["Players heard in the last hour: guild %d, group %d, friends %d, Battle.net %d"]):format(
        heard.guild, heard.group, heard.friend, heard.bnet)
    local found
    for _, line in ipairs(chat) do
        found = found or line == "  " .. part2
    end
    assert(found, "the part 2 line")
    ns.Channel.AVAILABLE = true
end)

test("/okf debug has the channel, the population, the channel peers, the blocked counts and the chain state", function()
    local report
    local show = ns.ShowCopyWindow
    ns.ShowCopyWindow = function(_, text) report = text end
    ns.ShowReport()
    ns.ShowCopyWindow = show
    assert(report:find("channel: ", 1, true), "Channel.Describe")
    assert(report:find("free slots", 1, true), "the slots")
    assert(report:find("population", 1, true), "the population estimate")
    assert(report:find("channel peers kept", 1, true), "the channel peers")
    assert(report:find("blocked by the bundled data", 1, true), "the blocked counts")
    assert(report:find("version chain: ", 1, true), "the chain state")
    assert(not report:find(ns.db.shared.myID, 1, true), "no own ID")
    assert(not report:find(ns.db.shared.chain.secret, 1, true), "never the chain's secret")
    assert(not report:find("Peer", 1, true), "no name")
end)

test("GetStatus has the channel, its index, the channel peers and the blocked fields", function()
    local status = Share.GetStatus()
    eq(status.channel, ns.Channel.GetState(), "the channel's state")
    eq(type(status.channelPeers), "number", "channel peers")
    eq(type(status.blocked), "number", "blocked records")
    eq(status.ownBlocked, false, "the own ID is not blocked")
    ns.SeedData.blocked = { [ns.db.shared.myID] = true }
    eq(Share.GetStatus().ownBlocked, true, "blocked")
    local report
    local show = ns.ShowCopyWindow
    ns.ShowCopyWindow = function(_, text) report = text end
    ns.ShowReport()
    ns.ShowCopyWindow = show
    assert(report:find("own record offered: no, blocked by the bundled data", 1, true), "the debug report says so")
    ns.SeedData.blocked = nil
end)
