-- Channel.lua: the swap with General that the game ignored once (specs/022-channel-order, FR-006): it is tried again
-- after 10 s, not earlier (a swap that shows late must not be undone by a second one), and the logout's record says
-- whether the comparison with General is still owed.

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
local MAIN = "OneKeyFishingShare"
channels_joined = {
    { name = MAIN, number = 1 },
    { name = "Trade", number = 2, zone = 2, disabled = true },
    { name = "General", number = 3, zone = 1, general = true },
}
channel_swap_dead = true
load_files(TOC_FILES)
fire("ADDON_LOADED", "OneKeyFishing")
fire("PLAYER_LOGIN")
enter_world(false, true)

test("a swap with General that does not show is not repeated within 10 s, and stays owed", function()
    eq(#channel_swaps, 1, "tried at the /reload")
    fire("CHANNEL_UI_UPDATE")
    advance(8)
    fire("CHANNEL_UI_UPDATE")
    eq(#channel_swaps, 1, "no second try yet")
    fire("PLAYER_LOGOUT")
    eq(ns.charDB.channelSession.generalOwed, true, "still owed")
    ns.charDB.channelSession = nil
end)

test("after 10 s it is tried again, and General gets its number", function()
    channel_swap_dead = false
    advance(2)
    eq(#channel_swaps, 2, "the second try")
    eq((GetChannelName("General")), 1, "General on 1")
    eq((GetChannelName(MAIN)), 3, "the channel behind")
    advance(15)
    eq(#channel_swaps, 2, "no third swap")
    assert(ns.Channel.Describe()[2]:find("swaps 1, failed 1, repair on", 1, true), "one failure, one swap in debug")
    fire("PLAYER_LOGOUT")
    eq(ns.charDB.channelSession.generalOwed, false, "no longer owed")
end)
