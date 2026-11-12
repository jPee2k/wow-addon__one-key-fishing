-- Channel.lua: a /reload that cut a leave off (specs/004-public-channel-sync, contracts/channel.md "Locks, kicks,
-- bans"): the client is still in a channel the logout saved as locked, so it leaves it and joins the next one.

channel_on = true

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
OneKeyFishingCharDB = { channelSession = { locked = { [1] = true } } }
channels_joined = { { name = "OneKeyFishingShare", number = 1 } }
load_files(TOC_FILES)
fire("ADDON_LOADED", "OneKeyFishing")
fire("PLAYER_LOGIN")
enter_world(false, true)

test("after a /reload, a channel found locked that the client is still in is left, and the next one joined", function()
    eq(channel_leaves[1], "OneKeyFishingShare", "left")
    eq(channel_joins[1] and channel_joins[1].name, "OneKeyFishingShare2", "the first fallback")
    advance(5)
    local state, index = ns.Channel.GetState()
    eq(state .. tostring(index), "in2", "in the first fallback")
end)
