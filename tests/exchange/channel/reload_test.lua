-- Channel.lua: a /reload while in the channel (specs/004-public-channel-sync, contracts/channel.md "Joining"): the
-- client is still in it, so it counts as joined at once; a second one of our names (an older session's) is left.

channel_on = true

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
channels_joined = { { name = "OneKeyFishingShare", number = 1 }, { name = "OneKeyFishingShare3", number = 2 } }
chat_window_add(1, "OneKeyFishingShare")
load_files(TOC_FILES)
fire("ADDON_LOADED", "OneKeyFishing")
fire("PLAYER_LOGIN")
enter_world(false, true)

test("after a /reload the joined channel is taken at once, a second one left, nothing joined", function()
    local state, index = ns.Channel.GetState()
    eq(state, "in", "in at once")
    eq(index, 1, "the main channel")
    eq(#channel_joins, 0, "nothing joined")
    eq(channel_leaves[1], "OneKeyFishingShare3", "the second one left")
    eq(#window_removals, 1, "taken out of the window again")
    advance(120)
    eq(#channel_joins, 0, "no join after the delay either")
end)
