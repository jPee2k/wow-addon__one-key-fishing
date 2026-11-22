-- Channel.lua: a channel of the game that turns up behind the hidden channel (specs/022-channel-order). It took the
-- lowest free number, which without the addon was the addon's, so the two trade places; the channels listed before
-- the join, the player's own channels and a row the player dragged stay. The tests run in order and share one login.

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
local MAIN = "OneKeyFishingShare"
-- The player left LocalDefense: its number 3 is free. The city's OOC is not known to the client yet (seen after a
-- login on 2026-11-22).
channels_joined = {
    { name = "General", number = 1, zone = 1, general = true },
    { name = "Trade", number = 2, zone = 2, disabled = true },
    { name = "Services", number = 4, zone = 42, disabled = true },
    { name = "TradeLocal", number = 5, zone = 43, disabled = true },
}
load_addon()

local function NumberOf(name)
    return (GetChannelName(name))
end

local function Entry(name)
    for _, entry in ipairs(channels_joined) do
        if entry.name == name then
            return entry
        end
    end
end

local function Arrives(name, zone)
    local number = game_channel_join(name, zone)
    fire("CHANNEL_UI_UPDATE")
    return number
end

test("the channel joins on the free number 3 and moves no channel that was there before it", function()
    advance(70)
    eq(ns.Channel.GetState(), "in", "in")
    eq(NumberOf(MAIN), 3, "the lowest free number")
    fire("CHANNEL_UI_UPDATE")
    Entry("Services").disabled = nil -- the player enters a city: Services and TradeLocal come alive
    Entry("TradeLocal").disabled = nil
    fire("CHANNEL_UI_UPDATE")
    advance(5)
    eq(#channel_swaps, 0, "no swap")
    eq(NumberOf("Services"), 4, "Services stays")
end)

test("the player's own channel joined behind it stays there", function()
    table.insert(channels_joined, { name = "mychannel", number = 6 })
    fire("CHANNEL_UI_UPDATE")
    advance(5)
    eq(#channel_swaps, 0, "no swap")
    eq(NumberOf("mychannel"), 6, "the player's channel stays")
end)

test("a channel of the game that turns up behind it gets its number, once the game tells what it is", function()
    -- First only its number is kept (the game tells nothing about it yet), then it comes alive.
    table.insert(channels_joined, { name = "OOC", number = 7, zone = 44, disabled = true })
    fire("CHANNEL_UI_UPDATE")
    advance(5)
    eq(#channel_swaps, 0, "no swap while the game tells nothing about it")
    eq(game_channel_join("OOC", 44), 7, "OOC alive behind the channel, with no event")
    advance(5)
    eq(#channel_swaps, 1, "one swap, by the addon's own look")
    eq(NumberOf("OOC"), 3, "OOC on the number it would have had")
    eq(NumberOf(MAIN), 7, "the channel behind it")
    advance(5)
    eq(#channel_swaps, 1, "no second swap")
end)

test("two of them at once are handled one swap at a time, the lowest first", function()
    game_channel_join("Newcomers", 50)
    eq(Arrives("WorldDefense", 23), 9, "the second one on 9")
    eq(#channel_swaps, 2, "one swap at once")
    eq(NumberOf("Newcomers"), 7, "the first got the channel's number")
    advance(1)
    eq(#channel_swaps, 2, "not two swaps within 2 s")
    advance(2)
    eq(#channel_swaps, 3, "the second swap after the gap")
    eq(NumberOf("WorldDefense"), 8, "the second one before the channel")
    eq(NumberOf(MAIN), 9, "the channel last")
end)

test("a channel of the game the player dragged behind it, and its new name there, are left alone", function()
    advance(5)
    C_ChatInfo.SwapChatChannelsByChannelIndex(4, 10) -- the player drags Services to an empty row
    local swaps = #channel_swaps
    fire("CHANNEL_UI_UPDATE")
    advance(5)
    eq(#channel_swaps, swaps, "no swap by the addon")
    Entry("Services").name = "Services - City" -- the same channel named after the place
    fire("CHANNEL_UI_UPDATE")
    advance(5)
    eq(#channel_swaps, swaps, "a known number is not a new channel")
    eq(NumberOf("Services - City"), 10, "where the player put it")
end)

test("after six swaps in a session the repair stops", function()
    eq(Arrives("Filler", 59), 4, "the row Services left is the lowest free number: before the channel, no swap")
    local swaps = #channel_swaps
    for i = 1, 3 do
        Arrives("City" .. i, 60 + i)
        advance(3)
    end
    eq(#channel_swaps, swaps + 3, "six swaps in all")
    assert(ns.Channel.Describe()[2]:find("swaps 6, failed 0, repair on", 1, true), "six counted")
    Arrives("City4", 64)
    advance(5)
    eq(#channel_swaps, swaps + 3, "no seventh swap")
    assert(ns.Channel.Describe()[2]:find("repair stopped", 1, true), "stopped in /okf debug")
end)
