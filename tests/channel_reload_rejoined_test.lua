-- Channel.lua: a /reload after the player left the channel by hand and joined it again by hand
-- (specs/004-public-channel-sync, FR-005): the channel is the player's now, so the addon neither hides nor leaves it.

local MAIN = "OneKeyFishingShare"
OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
OneKeyFishingCharDB = { channelSession = { left = true } }
channels_joined = { { name = MAIN, number = 1 } }
chat_window_add(1, MAIN)
load_files(TOC_FILES)
fire("ADDON_LOADED", "OneKeyFishing")
fire("PLAYER_LOGIN")
enter_world(false, true)

test("after a /reload, a channel joined again by hand after a /leave stays the player's", function()
    eq(ns.Channel.GetState(), "left", "left")
    eq(#window_removals, 0, "still in the chat window")
    ns.Channel.SetEnabled(false)
    advance(120)
    eq(#channel_leaves, 0, "not left by the addon")
    eq(#channel_joins, 0, "nothing joined")
end)
