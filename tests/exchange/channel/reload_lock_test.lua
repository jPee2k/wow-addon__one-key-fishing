-- Channel.lua: a /reload during the 10-20 s wait after a stranger's lock (specs/004-public-channel-sync,
-- contracts/channel.md "Locks, kicks, bans"): the client is still in the locked channel, so the wait starts again.

channel_on = true

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
-- As the logout of the /reload saved it: a stranger's password seen, the wait running.
OneKeyFishingCharDB = { channelSession = { lockWait = true, sawPassword = true } }
channels_joined = { { name = "OneKeyFishingShare", number = 1 } }
load_files(TOC_FILES)
fire("ADDON_LOADED", "OneKeyFishing")
fire("PLAYER_LOGIN")
enter_world(false, true)

test("a /reload during the wait after a stranger's lock: the wait goes on, then the move", function()
    local state, index = ns.Channel.GetState()
    eq(state .. index, "in1", "in the main channel")
    eq(channel_owner_queries[#channel_owner_queries], "OneKeyFishingShare", "asks again who owns it")
    advance(9.5)
    eq(#channel_joins, 0, "still waiting")
    advance(11)
    eq(channel_leaves[#channel_leaves], "OneKeyFishingShare", "left")
    eq(channel_joins[#channel_joins].name, "OneKeyFishingShare2", "the first fallback")
end)
