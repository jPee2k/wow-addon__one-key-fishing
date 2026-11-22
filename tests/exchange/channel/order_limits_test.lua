-- Channel.lua: when the repair of the channel numbers holds back (specs/022-channel-order): in a fight, while the game
-- hides the channel list, and for good once the game ignores the swap. The tests run in order and share one login.

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
local MAIN = "OneKeyFishingShare"
channels_joined = { { name = "General", number = 1, zone = 1, general = true } }
load_addon()

local function NumberOf(name)
    return (GetChannelName(name))
end

local function Arrives(name, zone)
    local number = game_channel_join(name, zone)
    fire("CHANNEL_UI_UPDATE")
    return number
end

test("in a fight nothing is swapped; the swap follows the fight", function()
    advance(70)
    eq(NumberOf(MAIN), 2, "joined behind General")
    in_combat = true
    eq(Arrives("Trade", 2), 3, "Trade behind the channel")
    advance(10)
    eq(#channel_swaps, 0, "no swap in the fight")
    in_combat = false
    fire("PLAYER_REGEN_ENABLED")
    eq(#channel_swaps, 1, "swapped after it")
    eq(NumberOf("Trade"), 2, "Trade before the channel")
    eq(NumberOf(MAIN), 3, "the channel last")
end)

test("a channel list of secret values is not read; the swap follows once it shows", function()
    advance(5)
    secret_values["LocalDefense"] = true
    eq(Arrives("LocalDefense", 22), 4, "LocalDefense behind the channel")
    advance(10)
    eq(#channel_swaps, 1, "no swap")
    secret_values["LocalDefense"] = nil
    advance(5) -- no event tells that the list shows again: the addon looks by itself
    eq(#channel_swaps, 2, "swapped")
    eq(NumberOf("LocalDefense"), 3, "LocalDefense before the channel")
end)

test("a swap the game ignores is tried twice, then the repair stops for the session", function()
    advance(5)
    channel_swap_dead = true
    eq(Arrives("Services", 42), 5, "Services behind the channel")
    eq(#channel_swaps, 3, "the first try")
    advance(8)
    eq(#channel_swaps, 3, "not tried again before 10 s")
    advance(2.5)
    eq(#channel_swaps, 4, "the second try")
    advance(10.5)
    eq(#channel_swaps, 4, "no third try")
    channel_swap_dead = false
    fire("CHANNEL_UI_UPDATE")
    advance(30)
    eq(#channel_swaps, 4, "stopped")
    eq(NumberOf(MAIN), 4, "the channel where it was")
    assert(ns.Channel.Describe()[2]:find("swaps 2, failed 2, repair stopped", 1, true), "in /okf debug")
    eq(ns.Channel.GetState(), "in", "still in the channel")
end)
