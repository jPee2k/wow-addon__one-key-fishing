-- Channel.lua: a /reload while the hidden channel is on number 1 without General (specs/022-channel-order, FR-003,
-- FR-009): the wait for General had run out before it, the comparison with General is still owed, and General coming
-- back later is seen by the 5 s look though no event tells of it.

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
OneKeyFishingCharDB = { channelSession = { generalOwed = true } }
local MAIN = "OneKeyFishingShare"
general_local_id = false -- the player is not in General
channels_joined = {
    { name = MAIN, number = 1 },
    { name = "Trade", number = 2, zone = 2, disabled = true },
}
load_files(TOC_FILES)
fire("ADDON_LOADED", "OneKeyFishing")
fire("PLAYER_LOGIN")
enter_world(false, true)

test("after the /reload nothing is swapped while General is away", function()
    eq(ns.Channel.GetState(), "in", "in at once")
    advance(60)
    eq(#channel_swaps, 0, "no swap")
end)

test("General joining with no event is seen within 5 s and gets number 1", function()
    eq(game_channel_join("General", 1, true), 3, "the game puts General behind")
    advance(5)
    eq(#channel_swaps, 1, "one swap")
    eq((GetChannelName("General")), 1, "General on 1")
    eq((GetChannelName(MAIN)), 3, "the channel behind")
end)
