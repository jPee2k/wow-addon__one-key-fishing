-- Channel.lua: the first /reload after an update from a version before spec 022 (specs/022-channel-order, FR-005):
-- its record names no channels, so the listed channels are taken as "not new" 10 s after the /reload, when the list
-- has filled, not at PLAYER_ENTERING_WORLD.

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
OneKeyFishingCharDB = { channelSession = { left = false, kicks = 0 } } -- as 1.5.0 wrote it
local MAIN = "OneKeyFishingShare"
channels_joined = {
    { name = "General", number = 1, zone = 1, general = true },
    { name = MAIN, number = 3 },
}
load_files(TOC_FILES)
fire("ADDON_LOADED", "OneKeyFishing")
fire("PLAYER_LOGIN")
enter_world(false, true)

local function NumberOf(name)
    return (GetChannelName(name))
end

test("channels listed in the seconds after the /reload are not new: nothing moves", function()
    advance(1)
    table.insert(channels_joined, { name = "Services", number = 4, zone = 42 })
    table.insert(channels_joined, { name = "TradeLocal", number = 5, zone = 43 })
    fire("CHANNEL_UI_UPDATE")
    advance(20)
    fire("CHANNEL_UI_UPDATE")
    eq(#channel_swaps, 0, "no swap")
    eq(NumberOf("Services"), 4, "Services stays")
    eq(NumberOf(MAIN), 3, "the channel where it was")
end)

test("a channel of the game that turns up later is new", function()
    eq(game_channel_join("OOC", 44), 2, "the free number 2: before the channel")
    eq(game_channel_join("WorldDefense", 23), 6, "behind the channel")
    fire("CHANNEL_UI_UPDATE")
    eq(#channel_swaps, 1, "one swap")
    eq(NumberOf("WorldDefense"), 3, "on the channel's number")
end)
