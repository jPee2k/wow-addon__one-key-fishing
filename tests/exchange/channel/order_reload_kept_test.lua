-- Channel.lua: General behind the hidden channel by the player's own drag (specs/022-channel-order, FR-005). The
-- comparison with General was made before the /reload (the logout's record says so), so the /reload does not make
-- it again and the player's order stays.

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
OneKeyFishingCharDB = { channelSession = { generalOwed = false } }
local MAIN = "OneKeyFishingShare"
channels_joined = {
    { name = "Trade", number = 2, zone = 2, disabled = true },
    { name = "LocalDefense", number = 3, zone = 22 },
    { name = MAIN, number = 7 },
    { name = "General", number = 8, zone = 1, general = true },
}
load_files(TOC_FILES)
fire("ADDON_LOADED", "OneKeyFishing")
fire("PLAYER_LOGIN")
enter_world(false, true)

test("a /reload after the comparison with General was made leaves General where the player dragged it", function()
    eq(ns.Channel.GetState(), "in", "in at once")
    fire("CHANNEL_UI_UPDATE")
    advance(30)
    eq(#channel_swaps, 0, "no swap")
    eq((GetChannelName("General")), 8, "General where the player put it")
    eq((GetChannelName(MAIN)), 7, "the channel where it was")
end)

test("the next logout says again that nothing is owed", function()
    fire("PLAYER_LOGOUT")
    eq(ns.charDB.channelSession.generalOwed, false, "not owed")
end)
