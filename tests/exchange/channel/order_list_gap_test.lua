-- Channel.lua: a look that misses channels which were there all along (specs/022-channel-order, FR-005): after a
-- loading screen the list may come back in parts. A channel once known stays known until the hidden channel's next
-- join, so it is not new when it is listed again, and nothing above the hidden channel moves. Also: a channel of the
-- player whose name reads as another channel's number is not taken for a channel of the game.

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
local MAIN = "OneKeyFishingShare"
-- The player left LocalDefense: number 3 is free.
channels_joined = {
    { name = "General", number = 1, zone = 1, general = true },
    { name = "Trade", number = 2, zone = 2 },
    { name = "Services", number = 4, zone = 42 },
    { name = "TradeLocal", number = 5, zone = 43 },
    { name = "OOC", number = 6, zone = 44 },
}
load_addon()

local function NumberOf(name)
    return (GetChannelName(name))
end

test("channels missing from one look and listed again are not new: nothing moves", function()
    advance(70)
    eq(NumberOf(MAIN), 3, "the channel on the free number 3")
    local gone = {}
    for i = #channels_joined, 1, -1 do
        local entry = channels_joined[i]
        if entry.number > 3 then
            table.insert(gone, table.remove(channels_joined, i))
        end
    end
    fire("CHANNEL_UI_UPDATE") -- a look in the middle of a loading screen
    for _, entry in ipairs(gone) do
        table.insert(channels_joined, entry)
    end
    fire("CHANNEL_UI_UPDATE")
    advance(30)
    eq(#channel_swaps, 0, "no swap")
    eq(NumberOf("Services"), 4, "Services stays")
    eq(NumberOf("OOC"), 6, "OOC stays")
    eq(NumberOf(MAIN), 3, "the channel where it was")
end)

test("the player's channel named like a number is not taken for the game's channel of that number", function()
    table.insert(channels_joined, { name = "2", number = 7 }) -- /join 2: "2" also reads as Trade's number
    fire("CHANNEL_UI_UPDATE")
    advance(30)
    eq(#channel_swaps, 0, "no swap")
    eq(NumberOf(MAIN), 3, "the channel where it was")
end)

test("a channel of the game that is really new still gets the channel's number", function()
    eq(game_channel_join("WorldDefense", 23), 8, "behind the channel")
    fire("CHANNEL_UI_UPDATE")
    eq(#channel_swaps, 1, "one swap")
    eq(NumberOf("WorldDefense"), 3, "on the channel's number")
    eq(NumberOf(MAIN), 8, "the channel behind it")
end)
