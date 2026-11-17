-- Channel.lua: the addon's join comes while the player is joining channels at the 20-channel limit (seen 2026-11-17:
-- JoinTemporaryChannel returned nothing there, and the addon stopped the channel for the whole session). Now it waits
-- for two free slots and joins the main channel when they are free (spec 016). One login.

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
channel_join_result.OneKeyFishingShare = {} -- the limit: JoinTemporaryChannel returns nothing
load_addon()

test("a join at the limit waits, then joins the main channel once slots are free", function()
    advance(65)
    eq(#channel_joins, 1, "tried once")
    eq(ns.Channel.GetState(), "noslot", "no slot")
    channel_join_result.OneKeyFishingShare = nil -- the player left some channels
    fire("CHANNEL_UI_UPDATE")
    eq(#channel_joins, 2, "tried again")
    channel_notice("CHAT_MSG_CHANNEL_NOTICE", "YOU_CHANGED", "OneKeyFishingShare")
    local state, index = ns.Channel.GetState()
    eq(state, "in", "joined")
    eq(index, 1, "the main channel, no fallback")
end)
