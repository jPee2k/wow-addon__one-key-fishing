-- Channel.lua: a channel of the game that turns up behind the hidden channel on a number the game kept for it
-- (specs/022-channel-order, FR-004, FR-005): the player dragged it there in an earlier session, and the client only
-- learns of it in a city. It did not take the lowest free number (free numbers lie below it), so the hidden channel
-- did not push it there and it is not moved.

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
local MAIN = "OneKeyFishingShare"
channels_joined = {
    { name = "General", number = 1, zone = 1, general = true },
    { name = "Trade", number = 2, zone = 2, disabled = true },
}
load_addon()

local function NumberOf(name)
    return (GetChannelName(name))
end

test("a channel of the game listed on a kept number with free numbers below it stays there", function()
    advance(70)
    eq(NumberOf(MAIN), 3, "the channel on the lowest free number")
    table.insert(channels_joined, { name = "OOC", number = 10, zone = 44 }) -- where the player dragged it once
    fire("CHANNEL_UI_UPDATE")
    advance(30)
    eq(#channel_swaps, 0, "no swap")
    eq(NumberOf("OOC"), 10, "OOC where the player put it")
end)

test("one that takes the lowest free number behind the channel still gets the channel's number", function()
    eq(game_channel_join("Services", 42), 4, "the lowest free number")
    fire("CHANNEL_UI_UPDATE")
    eq(#channel_swaps, 1, "one swap")
    eq(NumberOf("Services"), 3, "on the channel's number")
    eq(NumberOf(MAIN), 4, "the channel behind it")
    eq(NumberOf("OOC"), 10, "OOC still there")
end)
