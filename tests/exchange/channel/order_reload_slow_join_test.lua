-- Channel.lua: a /reload that joins the hidden channel, with a join the server confirms only after the 10 s in which
-- the list fills (specs/022-channel-order, FR-005): the channels listed in those seconds are still not new.

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
local MAIN = "OneKeyFishingShare"
channels_joined = {
    { name = "General", number = 1, zone = 1, general = true },
    { name = "Trade", number = 2, zone = 2, disabled = true },
}
channel_join_result[MAIN] = { 0, MAIN } -- the game answers; the test puts the player in the channel when it lands
load_files(TOC_FILES)
fire("ADDON_LOADED", "OneKeyFishing")
fire("PLAYER_LOGIN")
enter_world(false, true)

test("channels listed before a slow join is confirmed are not moved", function()
    eq(#channel_joins, 1, "the join asked at the /reload")
    advance(1)
    table.insert(channels_joined, { name = "Services", number = 4, zone = 42 })
    table.insert(channels_joined, { name = "TradeLocal", number = 5, zone = 43 })
    advance(11) -- the 10 s are over, the join is not confirmed yet
    table.insert(channels_joined, { name = MAIN, number = 3 })
    advance(5)
    eq(ns.Channel.GetState(), "in", "in")
    advance(20)
    eq(#channel_swaps, 0, "no swap")
    eq((GetChannelName("Services")), 4, "Services stays")
    eq((GetChannelName(MAIN)), 3, "the channel on the free number")
end)
