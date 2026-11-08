-- Channel.lua and Comm.lua: the server's "not permitted in this channel" notice (NOT_ALLOWED_IN_CHANNEL, V19 seen in
-- game) counts as a refusal of the channel path (specs/010-exchange-forever-fixes US2, contracts C4). The channel
-- ships off; this file switches it on.

channel_on = true
local MAIN = "OneKeyFishingShare"

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
load_addon()

local Channel = ns.Channel

local function Join()
    advance(61)
    channel_notice("CHAT_MSG_CHANNEL_NOTICE", "YOU_CHANGED", MAIN)
end

test("NOT_ALLOWED_IN_CHANNEL locks the channel after the refusals in a row; one alone does not", function()
    Join()
    eq(Channel.GetState(), "in", "joined")
    channel_notice("CHAT_MSG_CHANNEL_NOTICE", "NOT_ALLOWED_IN_CHANNEL", MAIN)
    eq(Channel.GetState(), "in", "one notice alone")
    -- The send before each notice returns success (V19 seen): it must not clear the count of notices.
    local sent = #addon_sent
    ns.Comm.ChannelBroadcast("H abcd 0 0 aaaaaaaaaaaaaaaa")
    advance(3)
    eq(addon_sent[#addon_sent].chatType == "CHANNEL" and #addon_sent > sent, true, "a channel send succeeded")
    local leaves = #channel_leaves
    channel_notice("CHAT_MSG_CHANNEL_NOTICE", "NOT_ALLOWED_IN_CHANNEL", MAIN)
    local state, index = Channel.GetState()
    eq(state == "in" and index == 1, false, "moved on from the main channel")
    eq(channel_leaves[leaves + 1], MAIN, "the main channel left")
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
