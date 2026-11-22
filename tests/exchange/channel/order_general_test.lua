-- Channel.lua: the hidden channel found on General's number (specs/022-channel-order). Seen in game on 2026-11-22:
-- the channel on 1 and General on 7, behind every channel of the game. A /reload (or the update from a version that
-- did it) finds that order and puts General back; the player's own order is not touched afterwards.

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
local MAIN = "OneKeyFishingShare"
channels_joined = {
    { name = MAIN, number = 1 },
    { name = "Trade", number = 2, zone = 2, disabled = true },
    { name = "LocalDefense", number = 3, zone = 22 },
    { name = "Services", number = 4, zone = 42, disabled = true },
    { name = "TradeLocal", number = 5, zone = 43, disabled = true },
    { name = "OOC", number = 6, zone = 44, disabled = true },
    { name = "General", number = 7, zone = 1, general = true },
}
load_files(TOC_FILES)
fire("ADDON_LOADED", "OneKeyFishing")
fire("PLAYER_LOGIN")
enter_world(false, true)

local function NumberOf(name)
    return (GetChannelName(name))
end

test("after a /reload with the channel on 1 and General on 7, the two trade places", function()
    eq(ns.Channel.GetState(), "in", "in at once")
    eq(#channel_swaps, 1, "one swap")
    eq(channel_swaps[1].first, 1, "the channel's number")
    eq(channel_swaps[1].second, 7, "General's number")
    eq(NumberOf("General"), 1, "General on 1")
    eq(NumberOf(MAIN), 7, "the channel behind the game's")
    eq(NumberOf("LocalDefense"), 3, "nothing else moved")
    eq(#channel_joins, 0, "no join")
end)

test("the swap is counted once its result shows, and no second one follows", function()
    advance(10)
    fire("CHANNEL_UI_UPDATE")
    eq(#channel_swaps, 1, "still one swap")
    assert(ns.Channel.Describe()[1]:find("(name 1, chat number 7)", 1, true), "the chat number in /okf debug")
    assert(ns.Channel.Describe()[2]:find("General 1, swaps 1, failed 0, repair on", 1, true), "the repair in debug")
end)

test("General dragged behind the channel by the player afterwards stays there", function()
    C_ChatInfo.SwapChatChannelsByChannelIndex(1, 8) -- the player's drag in Chat Settings > Channels
    local swaps = #channel_swaps
    fire("CHANNEL_UI_UPDATE")
    advance(10)
    eq(#channel_swaps, swaps, "no swap by the addon")
    eq(NumberOf("General"), 8, "General where the player put it")
end)
