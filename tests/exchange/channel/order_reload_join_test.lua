-- Channel.lua: a /reload while the hidden channel is not joined (inside the login delay, after a kick): it joins at
-- once, on a channel list that may still be filling (specs/022-channel-order, FR-005). The channels listed in the
-- seconds after it were there before the join: none of them is new, none moves.

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
local MAIN = "OneKeyFishingShare"
-- The player left LocalDefense, so number 3 is free; Services and TradeLocal are not listed yet.
channels_joined = {
    { name = "General", number = 1, zone = 1, general = true },
    { name = "Trade", number = 2, zone = 2, disabled = true },
}
load_files(TOC_FILES)
fire("ADDON_LOADED", "OneKeyFishing")
fire("PLAYER_LOGIN")
enter_world(false, true)

local function NumberOf(name)
    return (GetChannelName(name))
end

test("the channel joins at the /reload, and channels listed a second later are not moved", function()
    eq(#channel_joins, 1, "joined at once")
    advance(1)
    table.insert(channels_joined, { name = "Services", number = 4, zone = 42 })
    table.insert(channels_joined, { name = "TradeLocal", number = 5, zone = 43 })
    fire("CHANNEL_UI_UPDATE")
    advance(30)
    eq(ns.Channel.GetState(), "in", "in")
    eq(#channel_swaps, 0, "no swap")
    eq(NumberOf(MAIN), 3, "the channel on the free number")
    eq(NumberOf("Services"), 4, "Services stays")
    eq(NumberOf("TradeLocal"), 5, "TradeLocal stays")
end)

test("a channel of the game that turns up after those seconds is new", function()
    eq(game_channel_join("OOC", 44), 6, "behind the channel")
    fire("CHANNEL_UI_UPDATE")
    eq(#channel_swaps, 1, "one swap")
    eq(NumberOf("OOC"), 3, "on the channel's number")
    eq(NumberOf(MAIN), 6, "the channel behind it")
end)
