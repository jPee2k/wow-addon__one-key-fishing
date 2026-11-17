-- Channel.lua and Comm.lua: the server's "not permitted in this channel" notice (NOT_ALLOWED_IN_CHANNEL, seen in game
-- on 2026-11-06, gone on 2026-11-16). Two in a row on the current join mean the server refuses addon messages in custom
-- channels: the channel stops for the session, with no fallback walk (spec 016 US4, FR-008, contracts S2-S5, C4).

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
load_addon()

local Channel = ns.Channel
local MAIN = "OneKeyFishingShare"

local function Join()
    advance(61)
    channel_notice("CHAT_MSG_CHANNEL_NOTICE", "YOU_CHANGED", MAIN)
end

test("two NOT_ALLOWED_IN_CHANNEL notices stop the channel for the session; one alone does not", function()
    Join()
    eq(Channel.GetState(), "in", "joined")
    channel_notice("CHAT_MSG_CHANNEL_NOTICE", "NOT_ALLOWED_IN_CHANNEL", MAIN)
    eq(Channel.GetState(), "in", "one notice alone")
    -- The send before each notice returns success (seen on 2026-11-06): it must not clear the count of notices.
    local sent = #addon_sent
    ns.Comm.ChannelBroadcast("H abcd 0 0 aaaaaaaaaaaaaaaa")
    advance(3)
    eq(addon_sent[#addon_sent].chatType == "CHANNEL" and #addon_sent > sent, true, "a channel send succeeded")
    local leaves = #channel_leaves
    channel_notice("CHAT_MSG_CHANNEL_NOTICE", "NOT_ALLOWED_IN_CHANNEL", MAIN)
    eq(Channel.GetState(), "locked", "refused by the server")
    eq(#channel_leaves, leaves + 1, "left once")
    eq(channel_leaves[#channel_leaves], MAIN, "the main channel left")
    assert(Channel.Describe()[1]:find("refused server", 1, true), "the debug line: " .. Channel.Describe()[1])
    advance(3600)
    eq(#channel_joins, 1, "no fallback joined in the next hour")
    eq(channel_joins[1].name, MAIN, "only the main channel was ever joined")
end)

test("a notice for another channel changes nothing", function()
    local state, index = Channel.GetState()
    local leaves = #channel_leaves
    channel_notice("CHAT_MSG_CHANNEL_NOTICE", "NOT_ALLOWED_IN_CHANNEL", "Trade")
    channel_notice("CHAT_MSG_CHANNEL_NOTICE", "NOT_ALLOWED_IN_CHANNEL", "Trade")
    local now, nowIndex = Channel.GetState()
    eq(now, state, "the same state")
    eq(nowIndex, index, "the same channel")
    eq(#channel_leaves, leaves, "nothing left")
end)

test("the logout keeps the refusal for a /reload", function()
    fire("PLAYER_LOGOUT")
    eq(OneKeyFishingCharDB.channelSession.refused, "server", "the session record")
end)
