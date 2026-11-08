-- Channel.lua: the hidden public channel (specs/004-public-channel-sync, contracts/channel.md): names, slots,
-- joining after a login, hiding, the filters, pauses, the settings and CHANNEL_STATE. Locks are in lock_test.lua
-- and join_lock_test.lua, giving the slot up in slot_test.lua, /reload in reload_test.lua (this folder). The notice
-- was closed in an earlier session. The tests run in order and share one login.

channel_on = true

local MAIN = "OneKeyFishingShare"
local FISH = 6291

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
-- What the last logout saved for a /reload: a real login forgets it (the main channel is joined below).
OneKeyFishingCharDB = { channelSession = { left = true, locked = { [1] = true }, kicks = 2 } }
player_map_id = 1415
player_map_position = { 0.43, 0.78 }
chat_window_add(1, MAIN) -- the game put the channel in two windows (as after joining by hand once)
chat_window_add(3, MAIN)
chat_window_add(2, "Trade")
load_addon()

local Channel = ns.Channel
local states = {}
ns.On("CHANNEL_STATE", function(state, index) table.insert(states, { state = state, index = index }) end)

test("the main channel and five fallbacks, matched without case", function()
    eq(Channel.AVAILABLE, true, "available")
    eq(#Channel.NAMES, 6, "names")
    eq(Channel.NAMES[1], "OneKeyFishingShare", "main")
    eq(Channel.NAMES[6], "OneKeyFishingShare6", "last fallback")
    eq(Channel.IsOurs("onekeyfishingshare3"), true, "any case")
    eq(Channel.IsOurs("General"), false, "another channel")
    eq(Channel.IsOurs(nil), false, "nil")
    secret_values.OneKeyFishingShare = true
    eq(Channel.IsOurs("OneKeyFishingShare"), false, "a secret value is never read")
    secret_values.OneKeyFishingShare = nil
end)

test("free slots count every active channel against the game's 20", function()
    eq(Channel.FreeSlots(), 20, "none taken")
    channel_extra = 18
    eq(Channel.FreeSlots(), 2, "the player's own channels")
    channel_extra = 0
end)

test("the state follows the switch and both settings", function()
    eq(Channel.IsEnabled(), true, "on by default")
    ns.db.settings.shareChannel = false
    eq(Channel.GetState(), "off", "channel setting off")
    ns.db.settings.shareChannel = true
    ns.db.settings.shareDB = false
    eq(Channel.GetState(), "off", "shared database off")
    ns.db.settings.shareDB = true
    ns.db.shareNoticeChannel = false
    eq(Channel.GetState(), "notice", "the channel's notice not read")
    ns.db.shareNoticeChannel = true
    Channel.AVAILABLE = false
    eq(Channel.GetState(), "unavailable", "not shipped")
    Channel.AVAILABLE = true
    eq(Channel.GetState(), "waiting", "everything on")
end)

test("nothing joins in the first 30 s after a login; the join comes by 60 s, without a password or a window", function()
    eq(ns.charDB.channelSession, nil, "the last session's state is gone at a login")
    local login = GetTime()
    advance(29)
    eq(#channel_joins, 0, "the player's own channels come first")
    while #channel_joins == 0 and GetTime() - login < 60 do
        advance(1)
    end
    eq(#channel_joins, 1, "joined by 60 s")
    eq(channel_joins[1].name, MAIN, "the main channel")
    eq(channel_joins[1].password, nil, "no password")
    eq(channel_joins[1].frameID, nil, "no chat window")
    eq(Channel.GetState(), "waiting", "until the game confirms it")
    eq(ns.Mode.IsActive(), false, "not fishing: the channel does not wait for fishing mode (FR-001)")
end)

test("the join notice confirms it, takes it out of every window that lists it, and fires CHANNEL_STATE once", function()
    states = {}
    channel_notice("CHAT_MSG_CHANNEL_NOTICE", "YOU_CHANGED", MAIN)
    eq(Channel.GetState(), "in", "in")
    eq(Channel.GetNumber(), 1, "its number")
    eq(#states, 1, "one CHANNEL_STATE")
    eq(states[1].state, "in", "state")
    eq(states[1].index, 1, "index")
    eq(#window_removals, 2, "two windows listed it")
    eq(window_removals[1].window, 1, "the first")
    eq(window_removals[2].window, 3, "the third")
    eq(ChatFrame2.channelList[1], "Trade", "another channel's window untouched")
    advance(10)
    eq(#states, 1, "no CHANNEL_STATE without a change")
    eq(#channel_joins, 1, "not joined again")
end)

test("UPDATE_CHAT_WINDOWS takes it out again; YOU_JOINED does the same as YOU_CHANGED", function()
    chat_window_add(4, MAIN) -- the game restored a window's list
    fire("UPDATE_CHAT_WINDOWS")
    eq(#window_removals, 3, "removed again")
    eq(window_removals[3].window, 4, "from that window")
    chat_window_add(5, MAIN)
    channel_notice("CHAT_MSG_CHANNEL_NOTICE", "YOU_JOINED", MAIN)
    eq(#window_removals, 4, "removed after YOU_JOINED")
    eq(Channel.GetState(), "in", "still in")
end)

test("the filters drop every line of our channels, in any case, and nothing else", function()
    for _, event in ipairs({ "CHAT_MSG_CHANNEL", "CHAT_MSG_CHANNEL_NOTICE", "CHAT_MSG_CHANNEL_NOTICE_USER",
        "CHAT_MSG_CHANNEL_JOIN", "CHAT_MSG_CHANNEL_LEAVE" }) do
        eq(filter_hides(event, "x", "Someone", "", "1. " .. MAIN, "", "", 0, 1, MAIN), true, event .. ": ours")
        eq(filter_hides(event, "x", "Someone", "", "9. onekeyfishingshare4", "", "", 0, 9, "onekeyfishingshare4"),
            true, event .. ": a fallback in another case")
        eq(filter_hides(event, "x", "Someone", "", "2. Trade", "", "", 0, 2, "Trade"), false, event .. ": Trade")
    end
    eq(channel_text(MAIN, "hello?", "Typist"), true, "text typed in by hand")
    secret_values.Secret = true
    eq(filter_hides("CHAT_MSG_CHANNEL", "x", "Someone", "", "1. Secret", "", "", 0, 1, "Secret"), false,
        "a secret channel name is left alone")
    secret_values.Secret = nil
end)

test("a pause keeps the joined channel and says paused; the end of the pause says in again", function()
    in_combat = true
    fire("PLAYER_REGEN_DISABLED")
    eq(Channel.GetState(), "paused", "paused in combat")
    eq(#channel_leaves, 0, "the channel stays")
    in_combat = false
    fire("PLAYER_REGEN_ENABLED")
    advance(1)
    eq(Channel.GetState(), "in", "in again")
end)

test("the setting off leaves at once; other players' records keep counting (FR-012); on joins at once", function()
    local peer = { id = "pppppppp", epoch = 1, seq = 1,
        builds = { ["1.60.1"] = { ["1415:3:47"] = catch_cell(5, 1, { [FISH] = { 5, 5 } }) } } }
    eq(ns.Share.Store.Accept(ns.db.shared, prove(peer), time()), "new", "a peer's record from the channel")
    local before = ns.CatchDB.Query(1415, "47", { range = 3, source = "all" }).catches
    Channel.SetEnabled(false)
    eq(ns.db.settings.shareChannel, false, "saved")
    eq(channel_leaves[#channel_leaves], MAIN, "left")
    eq(Channel.GetState(), "off", "off")
    eq(ns.CatchDB.Query(1415, "47", { range = 3, source = "all" }).catches, before, "still counted")
    local joins = #channel_joins
    Channel.SetEnabled(true)
    eq(#channel_joins, joins + 1, "joined at once, without the login delay")
    advance(5)
    eq(Channel.GetState(), "in", "in (confirmed by its number)")
end)

test("the shared database off leaves the channel too, and on again joins it", function()
    local leaves = #channel_leaves
    ns.Share.SetEnabled(false)
    eq(#channel_leaves, leaves + 1, "left")
    eq(Channel.GetState(), "off", "off")
    ns.Share.SetEnabled(true)
    advance(5)
    eq(Channel.GetState(), "in", "in again")
end)

test("left by hand: out until the next login, with the setting still on", function()
    local joins = #channel_joins
    channel_notice("CHAT_MSG_CHANNEL_NOTICE", "YOU_LEFT", MAIN)
    eq(Channel.GetState(), "left", "left")
    eq(ns.db.settings.shareChannel, true, "the setting stays on")
    advance(3600)
    eq(#channel_joins, joins, "not joined again this session")
end)
