-- Channel.lua with the public channel off, as it ships (specs/010-exchange-forever-fixes US2, contracts C1, C3): no
-- join, and a channel an earlier build left joined is left once at login, silently.

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
channels_joined = { { name = "OneKeyFishingShare", number = 1 } } -- joined by an earlier build
chat_window_add(1, "OneKeyFishingShare")
load_addon()

test("the channel is unavailable and nothing is joined", function()
    eq(ns.Channel.AVAILABLE, false, "off")
    eq(ns.Channel.GetState(), "unavailable", "the state")
    advance(120)
    eq(#channel_joins, 0, "no join after the login delay")
end)

test("a channel left joined by an earlier build is left once at login, out of the windows, with no line", function()
    eq(#channel_leaves, 1, "left once")
    eq(channel_leaves[1], "OneKeyFishingShare", "the leftover")
    eq(#window_removals, 1, "taken out of the window")
    eq(#chat, 0, "no chat line")
    enter_world(false, true)
    eq(#channel_leaves, 1, "a second login leaves nothing")
    eq(#chat, 0, "still no line")
end)

test("a channel the game rejoins after the login is left too, and taken out of the windows", function()
    channels_joined = { { name = "OneKeyFishingShare2", number = 2 } }
    chat_window_add(1, "OneKeyFishingShare2")
    local leaves, removals = #channel_leaves, #window_removals
    channel_notice("CHAT_MSG_CHANNEL_NOTICE", "YOU_CHANGED", "OneKeyFishingShare2")
    eq(#channel_leaves, leaves + 1, "left")
    eq(channel_leaves[#channel_leaves], "OneKeyFishingShare2", "that one")
    eq(#window_removals, removals + 1, "out of the window")
    eq(#chat, 0, "no chat line")
end)
