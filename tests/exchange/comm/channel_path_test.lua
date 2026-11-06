-- Comm.lua and CommReceive.lua:
-- the channel path and the part rules of part 3 (specs/004-public-channel-sync, research R6, contracts/api.md
-- "ns.Comm additions"). Channel.lua's state is stubbed, so only Comm is under test. The exchange itself (Share.lua) is
-- not started. The tests run in order and share one login.

in_guild = true
load_addon()

local Comm = ns.Comm
local received = {}
Comm.OnReceive(function(address, via, text)
    table.insert(received, { address = address, via = via, text = text })
end)
local flooded = {}
Comm.OnFlood(function(address) table.insert(flooded, address) end)

-- Channel.lua stand-ins: the state, the channel's number and the refusal callback.
local channelState, channelNumber, refusals = "waiting", nil, 0
ns.Channel.GetState = function() return channelState end
ns.Channel.GetNumber = function() return channelNumber end
ns.Channel.OnRefused = function() refusals = refusals + 1 end

local sentSince = addon_sent_since

-- `count` parts of a message of `total` parts from `sender`, each chunk `size` bytes.
local function parts(sender, id, from, to, total, size)
    for part = from, to do
        receive_addon("OKF1", ("Rab#%s.%d.%d %s"):format(id, part, total, ("x"):rep(size)), "WHISPER", sender)
    end
end

local function receivedFrom(address)
    for _, message in ipairs(received) do
        if message.address == address then
            return message
        end
    end
end

test("ChannelBroadcast queues nothing unless the channel is in use", function()
    local before = #addon_sent
    Comm.ChannelBroadcast("H abcd 0 1 aaaaaaa")
    advance(10)
    eq(#sentSince(before, "CHANNEL"), 0, "not in the channel")
end)

test("a channel HELLO goes with the number the channel has when it goes out, at the broadcast pace", function()
    channelState, channelNumber = "in", 5
    local before = #addon_sent
    Comm.Broadcast("H abcd 0 1 aaaaaaa")
    Comm.ChannelBroadcast("H abcd 0 1 aaaaaaa")
    channelNumber = 7 -- a move to a fallback channel before the queue reaches it
    advance(10)
    local guild, channel = sentSince(before, "GUILD")[1], sentSince(before, "CHANNEL")[1]
    eq(channel ~= nil, true, "sent to the channel")
    eq(channel.target, 7, "the number at send time")
    eq(channel.at - guild.at >= 2, true, "2 s after the guild HELLO: one pace for every broadcast")
end)

test("a channel HELLO left in the queue when the channel is left is dropped", function()
    local before = #addon_sent
    Comm.ChannelBroadcast("H abcd 0 1 aaaaaaa")
    channelNumber = nil
    advance(10)
    eq(#sentSince(before, "CHANNEL"), 0, "dropped")
    channelNumber = 7
end)

test("a channel message counts only from one of our channels, named in name or else in target", function()
    wipe(received)
    receive_addon("OKF1", "H abcd 0 1 aaaaaaa", "CHANNEL", "Stranger-Realm", "", 7, "OneKeyFishingShare")
    eq(#received, 1, "from our channel")
    eq(received[1].via, "channel", "via the channel")
    eq(received[1].address, "w:Stranger-Realm", "answered by whisper")
    receive_addon("OKF1", "H abcd 0 1 aaaaaaa", "CHANNEL", "Stranger-Realm", "onekeyfishingshare2", 8, "")
    eq(#received, 2, "the name empty: target, in any case")
    receive_addon("OKF1", "H abcd 0 1 aaaaaaa", "CHANNEL", "Stranger-Realm", "", 2, "Trade")
    eq(#received, 2, "another channel")
end)

test("a part of a long message from the channel is dropped", function()
    wipe(received)
    receive_addon("OKF1", "Rab#1.1.1 xyz", "CHANNEL", "Stranger-Realm", "", 7, "OneKeyFishingShare")
    eq(#received, 0, "dropped")
end)

test("the part filter: parts from an address it refuses are dropped, from one it takes they join", function()
    Comm.SetPartFilter(function(address) return address == "w:Peer-Realm" end)
    wipe(received)
    parts("Other-Realm", "a1", 1, 2, 2, 10)
    eq(#received, 0, "refused")
    parts("Peer-Realm", "a2", 1, 2, 2, 10)
    eq(#received, 1, "joined")
    eq(received[1].text, "Rab " .. ("x"):rep(20), "whole")
end)

test("the part buffers of all senders stay within 128 KB: the sender whose last part is oldest goes first", function()
    Comm.SetPartFilter(function() return true end)
    wipe(received)
    parts("A-Realm", "b1", 1, 299, 300, 200) -- 59.8 KB each, under the 64 KB per sender
    advance(1)
    parts("B-Realm", "b2", 1, 299, 300, 200)
    advance(1)
    parts("C-Realm", "b3", 1, 60, 300, 200) -- passes 128 KB over all three
    parts("A-Realm", "b1", 300, 300, 300, 200)
    eq(receivedFrom("w:A-Realm"), nil, "the oldest sender's parts were dropped")
    parts("B-Realm", "b2", 300, 300, 300, 200)
    eq(receivedFrom("w:B-Realm") ~= nil, true, "another sender's message joins")
end)

test("the leftovers of a session that ended (a 32 KB record, 140 parts) are dropped, but the peer is no flooder",
    function()
    Comm.SetPartFilter(function() return false end)
    wipe(received)
    parts("Late-Realm", "d1", 1, 140, 140, 235)
    eq(#received, 0, "dropped")
    eq(#flooded, 0, "not reported")
    receive_addon("OKF1", "H abcd 0 1 aaaaaaa", "WHISPER", "Late-Realm")
    eq(#received, 1, "its next message arrives")
    Comm.SetPartFilter(nil)
end)

test("a sender of more refused parts within 10 minutes than a whole hourly budget carries is reported once, then "
    .. "ignored until logout", function()
    Comm.SetPartFilter(function(address) return address ~= "w:Flooder-Realm" end)
    wipe(received)
    local limit = math.ceil(2 * Comm.BUDGET / 255) -- 402: 50 KB in parts, two to a long message at the least
    parts("Flooder-Realm", "c1", 1, limit, 999, 5)
    eq(#flooded, 0, limit .. " parts: not yet")
    parts("Flooder-Realm", "c1", limit + 1, limit + 1, 999, 5)
    eq(#flooded, 1, "reported")
    eq(flooded[1], "w:Flooder-Realm", "the address")
    parts("Flooder-Realm", "c1", limit + 2, limit + 50, 999, 5)
    eq(#flooded, 1, "once")
    receive_addon("OKF1", "H abcd 0 1 aaaaaaa", "WHISPER", "Flooder-Realm")
    eq(#received, 0, "every later message dropped")
    Comm.SetPartFilter(nil)
end)

test("two channel refusals in a row move to the next channel; five do not leave the path out", function()
    addon_send_result.CHANNEL = 7 -- InvalidChannel
    for _ = 1, 2 do
        Comm.ChannelBroadcast("H abcd 0 1 aaaaaaa")
    end
    advance(10)
    eq(refusals, 1, "Channel.OnRefused after the second")
    for _ = 1, 3 do
        Comm.ChannelBroadcast("H abcd 0 1 aaaaaaa")
    end
    advance(10)
    eq(refusals, 2, "a fresh count: the fourth is the next second in a row")
    eq(Comm.private.GetPaths().channel.disabled, false, "five refusals: the path is not left out")
    addon_send_result.CHANNEL = 9 -- GeneralError counts too
    Comm.ChannelBroadcast("H abcd 0 1 aaaaaaa")
    advance(10)
    eq(refusals, 3, "GeneralError")
    addon_send_result.CHANNEL = 4 -- any other refusal code counts the same way
    for _ = 1, 2 do
        Comm.ChannelBroadcast("H abcd 0 1 aaaaaaa")
    end
    advance(10)
    eq(refusals, 4, "another code")
    eq(Comm.private.GetPaths().channel.disabled, false, "never the part 2 path rule")
    addon_send_result.CHANNEL = nil
    local before = #addon_sent
    Comm.ChannelBroadcast("H abcd 0 1 aaaaaaa")
    advance(10)
    eq(#sentSince(before, "CHANNEL"), 1, "still sends")
end)

test("the refusals count per join of the channel: a move starts them again, a pause's end does not", function()
    channelState, channelNumber = "in", 5
    ns.Fire("CHANNEL_STATE", "in", 1, 1)
    local before = refusals
    addon_send_result.CHANNEL = 7
    Comm.ChannelBroadcast("H abcd 0 1 aaaaaaa")
    advance(10)
    ns.Fire("CHANNEL_STATE", "waiting", nil, 1) -- moved on by a notice (MUTED): the next channel is joined
    ns.Fire("CHANNEL_STATE", "in", 2, 2)
    Comm.ChannelBroadcast("H abcd 0 1 aaaaaaa")
    advance(10)
    eq(refusals, before, "one refusal on the new channel: no move")
    ns.Fire("CHANNEL_STATE", "paused", 2, 2)
    ns.Fire("CHANNEL_STATE", "in", 2, 2)
    Comm.ChannelBroadcast("H abcd 0 1 aaaaaaa")
    advance(10)
    eq(refusals, before + 1, "the end of a pause is no new join: the second in a row moves on")
    addon_send_result.CHANNEL = nil
end)

test("the channel alone never keeps the exchange available when the game refuses every other path", function()
    addon_send_result.default, bn_send_result = 9, 9
    group_type = "party"
    for i = 1, 5 do
        Comm.Broadcast("H abcd 0 1 aaaaaaa")
        Comm.Send("w:Someone" .. i, "Wab")
        Comm.Send("b:" .. (10 + i), "Wab")
    end
    addon_send_result.CHANNEL = 0
    Comm.ChannelBroadcast("H abcd 0 1 aaaaaaa")
    advance(60)
    eq(Comm.GetPause(), "unavailable", "unavailable")
end)
