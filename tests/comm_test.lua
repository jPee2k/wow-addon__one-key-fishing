-- Comm.lua: the transport of the catch exchange (framing, pace, budget, send results, pauses, friends, the chat
-- filter). The tests run in order and share one login; the exchange itself (Share.lua) is not started
-- (shareNotice is false and the popup is never closed), so only the tests send.

load_addon()

local Comm = ns.Comm
local received = {}
Comm.OnReceive(function(address, via, text)
    table.insert(received, { address = address, via = via, text = text })
end)
local offline = {}
Comm.OnOffline(function(address) table.insert(offline, address) end)

local sentSince = addon_sent_since

-- Runs the queue until it is empty (at most `seconds`).
local function drain(seconds)
    advance(seconds or 60)
end

test("the prefix is registered at load", function()
    eq(addon_prefixes.OKF1, true, "OKF1")
end)

test("a 600-byte message goes in parts of at most 255 bytes and is joined in any order", function()
    local body = ("x"):rep(590) .. "0123456789"
    local text = "Rab " .. body
    local before = #addon_sent
    Comm.Send("w:Other-Realm", text)
    drain(10)
    local parts = sentSince(before)
    assert(#parts >= 3, "parts: " .. #parts)
    for _, part in ipairs(parts) do
        assert(#part.text <= 255, "part length " .. #part.text)
        eq(part.chatType, "WHISPER", "whisper")
        eq(part.target, "Other-Realm", "target")
        assert(part.text:find("^Rab#%w+%.%d+%.%d+ "), "part header: " .. part.text:sub(1, 20))
    end
    wipe(received)
    for i = #parts, 1, -1 do
        receive_addon("OKF1", parts[i].text, "WHISPER", "Other-Realm")
    end
    eq(#received, 1, "one whole message")
    eq(received[1].text, text, "joined")
    eq(received[1].address, "w:Other-Realm", "address")
    eq(received[1].via, "whisper", "via")
end)

test("parts that never complete are dropped after 15 s; a flood of parts is dropped", function()
    wipe(received)
    receive_addon("OKF1", "Rab#zz.1.2 half", "WHISPER", "Slow-Realm")
    advance(16)
    receive_addon("OKF1", "Rab#zz.2.2 rest", "WHISPER", "Slow-Realm")
    eq(#received, 0, "the first part expired")
    local chunk = ("y"):rep(240)
    for part = 1, 300 do
        receive_addon("OKF1", ("Rcd#q.%d.300 %s"):format(part, chunk), "WHISPER", "Flood-Realm")
    end
    eq(#received, 0, "more than 64 KB of parts: dropped")
end)

test("a long message whose parts keep coming is joined even after more than 15 s", function()
    wipe(received)
    local parts = Comm.Split("Rlg " .. ("q"):rep(240 * 60))
    eq(#parts > 40, true, "many parts")
    for _, part in ipairs(parts) do
        receive_addon("OKF1", part, "WHISPER", "Long-Realm")
        advance(0.5)
    end
    eq(#received, 1, "joined after " .. (#parts * 0.5) .. " s")
    eq(#received[1].text, 4 + 240 * 60, "whole")
end)

test("broadcasts go 2 s apart, whispers at most 2 per second", function()
    in_guild, group_type = true, "party"
    local before = #addon_sent
    Comm.Broadcast("H abcd 0 1 aaaaaaa")
    drain(10)
    local sent = sentSince(before)
    eq(#sent, 2, "guild and party")
    eq(sent[1].chatType, "GUILD", "guild first")
    eq(sent[2].chatType, "PARTY", "then the group")
    assert(sent[2].at - sent[1].at >= 2, "2 s apart")
    before = #addon_sent
    for i = 1, 6 do
        Comm.Send("w:Peer" .. i, "Wab")
    end
    drain(10)
    sent = sentSince(before)
    eq(#sent, 6, "all whispers")
    for i = 2, #sent do
        assert(sent[i].at - sent[i - 1].at >= 0.5, "0.5 s between whispers")
    end
    in_guild, group_type = false, nil
end)

test("a broadcast goes to the raid in a raid, and nowhere outside guild and group", function()
    local before = #addon_sent
    Comm.Broadcast("H abcd 0 1 aaaaaaa")
    drain(5)
    eq(#sentSince(before), 0, "no guild, no group")
    group_type = "raid"
    Comm.Broadcast("H abcd 0 1 aaaaaaa")
    drain(5)
    local sent = sentSince(before)
    eq(#sent, 1, "one")
    eq(sent[1].chatType, "RAID", "raid")
    group_type = nil
end)

test("throttle results put the message back and wait 2 s, then 4 s", function()
    addon_send_result.WHISPER = 3
    local before = #addon_sent
    Comm.Send("w:Peer", "Wab")
    advance(0)
    eq(#sentSince(before), 1, "first try")
    advance(1.9)
    eq(#sentSince(before), 1, "waits 2 s")
    advance(0.2)
    eq(#sentSince(before), 2, "second try after 2 s")
    advance(3.7)
    eq(#sentSince(before), 2, "then waits 4 s")
    addon_send_result.WHISPER = nil
    advance(0.2)
    eq(#sentSince(before), 3, "third try goes through")
    advance(10)
    eq(#sentSince(before), 3, "and is not sent again")
end)

test("AddOnMessageLockdown pauses for 60 s, doubling while it repeats", function()
    local pauses = {}
    ns.On("SHARE_PAUSE", function(reason) table.insert(pauses, tostring(reason)) end)
    addon_send_result.WHISPER = 11
    Comm.Send("w:Peer", "Wab")
    advance(0)
    eq(Comm.GetPause(), "lockdown", "paused")
    eq(pauses[#pauses], "lockdown", "SHARE_PAUSE fired")
    eq(Comm.CanSend(), false, "cannot send")
    advance(59)
    eq(Comm.GetPause(), "lockdown", "still after 59 s")
    advance(6)
    eq(Comm.GetPause(), nil, "over after 60 s")
    eq(pauses[#pauses], "nil", "SHARE_PAUSE with nil")
    Comm.Send("w:Peer", "Wab")
    advance(0)
    advance(119)
    eq(Comm.GetPause(), "lockdown", "120 s the second time")
    addon_send_result.WHISPER = nil
    advance(10)
    eq(Comm.GetPause(), nil, "over")
end)

test("TargetOffline reports the address to the offline handlers", function()
    addon_send_result.WHISPER = 12
    Comm.Send("w:Gone-Realm", "Wab")
    advance(0)
    eq(offline[#offline], "w:Gone-Realm", "reported")
    addon_send_result.WHISPER = nil
end)

test("pause reasons: combat, instance, loading screen, restrictions; nothing goes out or comes in", function()
    in_combat = true
    eq(Comm.GetPause(), "combat", "combat")
    in_combat = false
    in_instance = true
    eq(Comm.GetPause(), "instance", "instance")
    in_instance = false
    fire("LOADING_SCREEN_ENABLED")
    eq(Comm.GetPause(), "loading", "loading screen")
    fire("LOADING_SCREEN_DISABLED")
    restrictions[Enum.AddOnRestrictionType.Chat] = true
    eq(Comm.GetPause(), "restricted", "chat restriction")
    restrictions[Enum.AddOnRestrictionType.Chat] = nil
    chat_lockdown = true
    eq(Comm.GetPause(), "restricted", "chat lockdown")
    chat_lockdown = false
    addon_chat_restricted = true -- true on every normal realm: about chat messages, not addon messages
    eq(Comm.GetPause(), nil, "outgoing addon chat (chat messages by addons) does not pause the exchange")
    chat_lockdown = true
    eq(Comm.GetPause(), "restricted", "chat lockdown still does")
    local before = #addon_sent
    eq(Comm.Send("w:Peer", "Wab"), false, "refused while paused")
    wipe(received)
    receive_addon("OKF1", "Wab", "WHISPER", "Peer")
    eq(#received, 0, "incoming dropped")
    addon_chat_restricted, chat_lockdown = false, false
    fire("ADDON_RESTRICTION_STATE_CHANGED")
    eq(Comm.GetPause(), nil, "free again")
    advance(5)
    eq(#sentSince(before), 0, "nothing was sent")
end)

test("a restriction is read on the frame after its event, when it is active", function()
    local pauses = {}
    ns.On("SHARE_PAUSE", function(reason) table.insert(pauses, tostring(reason)) end)
    restrictions[Enum.AddOnRestrictionType.Map] = true
    fire("ADDON_RESTRICTION_STATE_CHANGED", Enum.AddOnRestrictionType.Map, 1)
    eq(#pauses, 0, "not during the event")
    advance(0)
    eq(pauses[1], "restricted", "on the next frame")
    restrictions[Enum.AddOnRestrictionType.Map] = nil
    fire("ADDON_RESTRICTION_STATE_CHANGED", Enum.AddOnRestrictionType.Map, 0)
    advance(0)
    eq(pauses[2], "nil", "lifted")
end)

test("a long text that cannot be split is not reported as sent", function()
    eq(Comm.Send("w:Peer", ("x"):rep(300)), false, "no <type><sid> head")
end)

test("a message queued before a pause is dropped by it", function()
    local before = #addon_sent
    Comm.Send("w:Peer", "Wab")
    in_combat = true
    fire("PLAYER_REGEN_DISABLED")
    advance(1)
    in_combat = false
    fire("PLAYER_REGEN_ENABLED")
    advance(1)
    eq(#sentSince(before), 0, "dropped")
end)

test("the budget: after 50 KB in an hour only BYE goes out, and it frees up as the minutes roll out", function()
    advance(3600) -- earlier tests' traffic rolls out
    eq(Comm.CanSend(), true, "within budget")
    local text = "Rab " .. ("z"):rep(250)
    for _ = 1, 205 do
        Comm.Send("w:Big", text)
    end
    drain(205)
    assert(Comm.GetTraffic() >= 50 * 1024 - 260, "about 50 KB: " .. Comm.GetTraffic())
    eq(Comm.CanSend(), false, "over the budget")
    local before = #addon_sent
    Comm.Send("w:Big", "Wab x")
    Comm.Send("w:Big", "Bab done", "bye")
    drain(5)
    local sent = sentSince(before)
    eq(#sent, 1, "only BYE")
    eq(sent[1].text, "Bab done", "BYE")
    advance(3600)
    eq(Comm.CanSend(), true, "an hour later")
end)

test("the rolling hour drops a minute after 60 minutes, for the budget and the per-sender limits alike", function()
    local counts = {}
    eq(ns.CountRecent(counts, 120, 5, 60), 5, "added")
    eq(ns.CountRecent(counts, 120 + 59 * 60, 0, 60), 5, "59 minutes later")
    eq(ns.CountRecent(counts, 120 + 60 * 60, 0, 60), 0, "60 minutes later")
    eq(next(counts), nil, "the old minute is gone, and a read adds none")
end)

test("friends: connected character friends and Battle.net friends playing Forever", function()
    friends = { { name = "Alice", connected = true }, { name = "Bob", connected = false },
        { name = "Carol-Elsewhere", connected = true } }
    bn_friends = {
        { { gameAccountID = 11, clientProgram = "WoW", wowProjectID = 18, isOnline = true } },
        { { gameAccountID = 12, clientProgram = "WoW", wowProjectID = 1, isOnline = true },
          { gameAccountID = 13, clientProgram = "App", wowProjectID = 18, isOnline = true } },
        { { gameAccountID = 14, clientProgram = "WoW", wowProjectID = 18, isOnline = false } },
    }
    local found = {}
    Comm.ForEachFriend(function(address) table.insert(found, address) end)
    eq(table.concat(found, " "), "w:Alice-Realm w:Carol-Elsewhere b:11",
        "only those that can answer, with the realm their messages come from")
    friends, bn_friends = {}, {}
end)

test("Battle.net messages go by SendGameData and come back as bnet", function()
    local before = #bn_sent
    Comm.Send("b:11", "Wab")
    advance(1)
    eq(#bn_sent, before + 1, "sent")
    eq(bn_sent[#bn_sent].gameAccountID, 11, "game account")
    eq(bn_sent[#bn_sent].prefix, "OKF1", "prefix")
    wipe(received)
    receive_bn("OKF1", "Wab", 11)
    eq(received[1].address, "b:11", "address")
    eq(received[1].via, "bnet", "via")
end)

test("the chat filter hides 'No player named' for 10 s after a whisper to that name", function()
    Comm.Send("w:Other", "Wab")
    advance(0)
    local line = ERR_CHAT_PLAYER_NOT_FOUND_S:format("Other")
    eq(filter_hides("CHAT_MSG_SYSTEM", line), true, "hidden")
    eq(filter_hides("CHAT_MSG_SYSTEM", ERR_CHAT_PLAYER_NOT_FOUND_S:format("Someone")), false, "another name")
    advance(11)
    eq(filter_hides("CHAT_MSG_SYSTEM", line), false, "after 10 s")
end)

test("messages with another prefix or a NUL byte are ignored", function()
    wipe(received)
    receive_addon("OKF2", "Wab", "WHISPER", "Peer")
    receive_addon("OKF1", "Wa\0b", "WHISPER", "Peer")
    receive_addon("OKF1", "Wab", "SAY", "Peer")
    eq(#received, 0, "ignored")
end)

test("CanSend with a size says whether that message still fits the budget whole", function()
    advance(3600)
    eq(Comm.CanSend(40 * 1024), true, "40 KB fits an empty hour")
    eq(Comm.CanSend(50 * 1024), false, "50 KB plus its part headers does not")
end)

test("queued messages count against the budget, so messages checked one after another stay within it", function()
    advance(3600)
    local text = "Rab " .. ("q"):rep(8 * 1024)
    local queued = 0
    while Comm.CanSend(#text) and queued < 20 do -- what a session does: check, queue, check the next one
        Comm.Send("w:Big", text)
        queued = queued + 1
    end
    assert(queued < 20, "CanSend saw the queue")
    eq(queued, 5, "five 8 KB messages fit the hour")
    drain(600)
    assert(Comm.GetTraffic() <= 50 * 1024, "within the budget: " .. Comm.GetTraffic())
    eq(Comm.CanSend(), true, "the queue is empty, the rest of the hour is free")
    assert(table.concat(Comm.Describe(), "\n"):find("queue 0 (0 bytes)", 1, true), "Describe: nothing queued")
end)

test("refused greetings to friends do not count against the path", function()
    bn_send_result = 9
    for _ = 1, 6 do
        Comm.Send("b:77", "H abcd 0 1 aaaaaaa", "greeting")
    end
    advance(5)
    bn_send_result = nil
    eq(Comm.GetPaths().bnet.failures, 0, "not counted")
    eq(Comm.GetPaths().bnet.disabled, false, "the path stays")
end)

test("five refusals in a row leave a path out; a success resets the count; codes 3, 8, 10, 11, 12 never count",
    function()
    addon_send_result.WHISPER = 9
    for _ = 1, 4 do
        Comm.Send("w:Peer", "Wab")
    end
    advance(5)
    eq(Comm.GetPaths().whisper.failures, 4, "four refusals")
    addon_send_result.WHISPER = nil
    Comm.Send("w:Peer", "Wab")
    advance(1)
    eq(Comm.GetPaths().whisper.failures, 0, "reset by a success")
    addon_send_result.WHISPER = 10
    Comm.Send("w:Peer", "Wab")
    advance(1)
    eq(Comm.GetPaths().whisper.failures, 0, "NotInGuild does not count")
    addon_send_result.WHISPER = 9
    for _ = 1, 5 do
        Comm.Send("w:Peer", "Wab")
    end
    advance(5)
    eq(Comm.GetPaths().whisper.disabled, true, "left out")
    addon_send_result.WHISPER = nil
    local before = #addon_sent
    eq(Comm.Send("w:Peer", "Wab"), false, "whispers refused")
    advance(2)
    eq(#sentSince(before), 0, "nothing sent")
    eq(Comm.GetPause(), nil, "other paths still work")
end)

test("with every path left out the exchange is unavailable until logout", function()
    in_guild, group_type = true, "party"
    addon_send_result.default = 9
    bn_send_result = 9
    for _ = 1, 5 do
        Comm.Broadcast("H abcd 0 1 aaaaaaa")
        Comm.Send("b:11", "Wab")
    end
    advance(40)
    eq(Comm.GetPause(), "unavailable", "unavailable")
    addon_send_result.default, bn_send_result = nil, nil
    advance(60)
    eq(Comm.GetPause(), "unavailable", "stays")
    in_guild, group_type = false, nil
end)

test("Describe has no names", function()
    local text = table.concat(Comm.Describe(), "\n")
    assert(text:find("transport:", 1, true), text)
    for _, name in ipairs({ "Peer", "Other", "Alice", "Gone" }) do
        assert(not text:find(name, 1, true), name)
    end
end)
