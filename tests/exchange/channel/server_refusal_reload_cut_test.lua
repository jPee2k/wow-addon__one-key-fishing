-- Channel.lua: a /reload that cut off the leave of a refusal by the server (spec 016 US4, contracts S4): the client is
-- still in the channel the logout saved as refused, so it leaves it and is not taken as joined.

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
OneKeyFishingCharDB = { channelSession = { refused = "server" } }
channels_joined = { { name = "OneKeyFishingShare", number = 1 } }
load_files(TOC_FILES)
fire("ADDON_LOADED", "OneKeyFishing")
fire("PLAYER_LOGIN")
enter_world(false, true)

test("after a /reload, a channel refused by the server that the client is still in is left, not taken as joined",
    function()
        eq(channel_leaves[1], "OneKeyFishingShare", "left")
        eq(ns.Channel.GetState(), "locked", "locked")
        eq(ns.Channel.GetNumber(), nil, "not joined")
        advance(3600)
        eq(#channel_joins, 0, "no join until the next login")
    end)
