-- Share.lua: the game node in the hidden public channel (specs/004-public-channel-sync, research R5): the channel
-- HELLO rounds, Share.HeardInChannel and the status count. The notice (and the channel's) was closed in an earlier
-- session. The tests run in order and share one login.

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
load_addon()

local Share, Channel = ns.Share, ns.Channel
local inAt -- GetTime() of the last CHANNEL_STATE "in"
ns.On("CHANNEL_STATE", function(state) inAt = state == "in" and GetTime() or inAt end)

local function ChannelHellos(since)
    local out = {}
    for _, message in ipairs(addon_sent) do
        if message.chatType == "CHANNEL" and message.at >= since then
            table.insert(out, message)
        end
    end
    return out
end

test("the first channel HELLO comes 30-90 s after joining, to the channel's number", function()
    advance(70) -- the login delay and the join check
    eq(Channel.GetState(), "in", "in")
    local joined = inAt
    eq(#ChannelHellos(0), 0, "nothing at once")
    advance(joined + 29 - GetTime())
    eq(#ChannelHellos(0), 0, "not before 30 s")
    advance(joined + 91 - GetTime())
    local hellos = ChannelHellos(0)
    eq(#hellos, 1, "one by 90 s")
    eq(hellos[1].target, Channel.GetNumber(), "to the channel's number")
    assert(hellos[1].text:find("^H %w%w%w%w %d+ %d+ %w+$"), "a HELLO: " .. hellos[1].text)
end)

test("then one every 30-50 minutes", function()
    local first = ChannelHellos(0)[1].at
    advance(first + 29 * 60 - GetTime())
    eq(#ChannelHellos(0), 1, "none before 30 min")
    advance(first + 51 * 60 - GetTime())
    eq(#ChannelHellos(0), 2, "the second by 50 min")
end)

test("a channel HELLO heard: Share.HeardInChannel knows the player with or without the realm; status counts it",
    function()
        receive_addon("OKF1", "H wxyz 0 3 abcdefg", "CHANNEL", "Angler-Realm", "", Channel.GetNumber(),
            "OneKeyFishingShare")
        eq(Share.HeardInChannel("Angler-Realm"), true, "with the realm")
        eq(Share.HeardInChannel("Angler"), true, "without")
        eq(Share.HeardInChannel("Other"), false, "somebody else")
        receive_addon("OKF1", "H vxyz 0 3 abcdefg", "CHANNEL", "Fisher-Elsewhere", "", Channel.GetNumber(),
            "OneKeyFishingShare")
        eq(Share.HeardInChannel("Fisher-Elsewhere"), true, "from another realm, with its realm")
        eq(Share.HeardInChannel("Fisher"), false, "a Fisher of the own realm is somebody else")
        eq(Share.HeardInChannel(""), false, "empty")
        eq(Share.GetStatus().heard.channel, 2, "two channel peers this hour")
    end)

test("after a move to a fallback channel the next HELLO comes 5-30 s later, to the new number", function()
    local since = GetTime()
    channel_notice("CHAT_MSG_CHANNEL_NOTICE_USER", "PASSWORD_CHANGED", "OneKeyFishingShare", "Griefer")
    channel_notice("CHAT_MSG_CHANNEL_NOTICE_USER", "CHANNEL_OWNER", "OneKeyFishingShare", "Owner")
    for _ = 1, 30 do -- the 10-20 s wait and the join check, a second at a time: the HELLO may come 5 s after
        advance(1)
        local state, index = Channel.GetState()
        if state == "in" and index == 2 then
            break
        end
    end
    local state, index = Channel.GetState()
    eq(state .. index, "in2", "in the first fallback")
    local moved = inAt
    advance(moved + 4 - GetTime())
    eq(#ChannelHellos(since), 0, "not before 5 s")
    advance(moved + 31 - GetTime())
    local hellos = ChannelHellos(since)
    eq(#hellos, 1, "one by 30 s")
    eq(hellos[1].target, Channel.GetNumber(), "to the fallback's number")
end)

test("a pause and its end bring no extra channel HELLO: the round goes on", function()
    local since = GetTime()
    in_combat = true
    fire("PLAYER_REGEN_DISABLED")
    advance(10)
    eq(Channel.GetState(), "paused", "paused")
    in_combat = false
    fire("PLAYER_REGEN_ENABLED")
    eq(Channel.GetState(), "in", "in again")
    advance(100)
    eq(#ChannelHellos(since), 0, "none")
end)

test("back in the same channel after a kick: the next HELLO comes 30-90 s after the rejoin", function()
    local since = GetTime()
    channel_notice("CHAT_MSG_CHANNEL_NOTICE_USER", "PLAYER_KICKED", "OneKeyFishingShare2", "Me")
    advance(70) -- the 60 s wait and the join check
    local state, index = Channel.GetState()
    eq(state .. index, "in2", "the same channel again")
    local rejoined = inAt
    advance(rejoined + 29 - GetTime())
    eq(#ChannelHellos(since), 0, "not before 30 s")
    advance(rejoined + 91 - GetTime())
    eq(#ChannelHellos(since), 1, "one by 90 s, not 30-50 min later")
end)

test("a rejoin after a kick confirmed during a pause: the next HELLO still comes 30-90 s after the pause", function()
    local since = GetTime()
    channel_notice("CHAT_MSG_CHANNEL_NOTICE_USER", "PLAYER_KICKED", "OneKeyFishingShare2", "Me")
    advance(60) -- the rejoin starts
    in_combat = true
    fire("PLAYER_REGEN_DISABLED")
    advance(6) -- the join check confirms it during the pause
    eq(Channel.GetState(), "paused", "paused")
    in_combat = false
    fire("PLAYER_REGEN_ENABLED")
    local state, index = Channel.GetState()
    eq(state .. index, "in2", "in")
    advance(91)
    eq(#ChannelHellos(since), 1, "one by 90 s, not 30-50 min later")
end)

test("no channel HELLO while not in the channel", function()
    Channel.SetEnabled(false)
    local since = GetTime()
    advance(2 * 3600)
    eq(#ChannelHellos(since), 0, "none in two hours")
end)
