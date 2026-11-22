-- Channel.lua: a /reload whose channel list fills after PLAYER_ENTERING_WORLD (specs/022-channel-order, FR-005). The
-- channels the logout's record knows are not new when they are listed late, on the numbers the game kept for them:
-- nothing above the hidden channel moves, not Services and TradeLocal, not General the player dragged behind it.

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
OneKeyFishingCharDB = { channelSession = { generalOwed = false, known = {
    names = { Trade = true, Services = true, TradeLocal = true, General = true },
    numbers = { [2] = true, [4] = true, [5] = true, [8] = true },
} } }
local MAIN = "OneKeyFishingShare"
general_local_id = false
channels_joined = { { name = MAIN, number = 3 } } -- only the hidden channel is listed yet
load_files(TOC_FILES)
fire("ADDON_LOADED", "OneKeyFishing")
fire("PLAYER_LOGIN")
enter_world(false, true)

local function NumberOf(name)
    return (GetChannelName(name))
end

test("the channels known before the /reload, listed a moment after it, are not moved", function()
    eq(ns.Channel.GetState(), "in", "in at once")
    advance(1)
    table.insert(channels_joined, { name = "Trade", number = 2, zone = 2, disabled = true })
    table.insert(channels_joined, { name = "Services", number = 4, zone = 42 })
    table.insert(channels_joined, { name = "TradeLocal", number = 5, zone = 43 })
    table.insert(channels_joined, { name = "General", number = 8, zone = 1, general = true })
    fire("CHANNEL_UI_UPDATE")
    advance(30)
    eq(#channel_swaps, 0, "no swap")
    eq(NumberOf(MAIN), 3, "the channel where it was")
    eq(NumberOf("Services"), 4, "Services stays")
    eq(NumberOf("General"), 8, "General where the player dragged it")
end)

test("a channel of the game that is new after the /reload still gets the channel's number", function()
    eq(game_channel_join("OOC", 44), 1, "the free number 1: before the channel, nothing to do")
    eq(game_channel_join("WorldDefense", 23), 6, "behind the channel")
    fire("CHANNEL_UI_UPDATE")
    eq(#channel_swaps, 1, "one swap")
    eq(NumberOf("WorldDefense"), 3, "on the channel's number")
    eq(NumberOf(MAIN), 6, "the channel behind it")
end)

test("the logout's record holds the channels that are not new", function()
    advance(5)
    fire("PLAYER_LOGOUT")
    local known = ns.charDB.channelSession.known
    eq(known.names.WorldDefense, true, "the swapped channel by name")
    eq(known.names.General, true, "General by name")
    eq(known.numbers[8], true, "and by number")
    eq(known.names[MAIN], nil, "not the hidden channel")
end)
