-- Character friends (Comm.ForEachFriend, specs/010-exchange-forever-fixes US1, contracts N3-N4): a friend is
-- greeted under the name the friends list gives ("First Last", no realm added), the same address the friend's own
-- messages come from, so the friend is one peer.

OneKeyFishingDB = { shareNotice = true }
friends = { { name = "Ann Lee", connected = true } }
load_addon()

local function WhisperTargets(since)
    local targets = {}
    for i = since + 1, #addon_sent do
        if addon_sent[i].chatType == "WHISPER" then
            targets[addon_sent[i].target] = (targets[addon_sent[i].target] or 0) + 1
        end
    end
    return targets
end

test("a friend's address is the name as the friends list gives it", function()
    local found = {}
    ns.Comm.ForEachFriend(function(address) table.insert(found, address) end)
    eq(table.concat(found, " "), "w:Ann Lee", "no realm added")
end)

test("the friend is greeted, answers, and is greeted again at the one address", function()
    advance(130) -- the first HELLO round
    local targets = WhisperTargets(0)
    eq(targets["Ann Lee"] ~= nil, true, "greeted at the friends list name")
    receive_addon("OKF1", "H frnd 0 0 " .. ("a"):rep(16), "WHISPER", "Ann Lee")
    advance(1)
    eq(ns.Share.GetStatus().heard.friend, 1, "one friend heard")
    local before = #addon_sent
    advance(700) -- the next round greets the known peer first
    for target in pairs(WhisperTargets(before)) do
        eq(target, "Ann Lee", "every whisper goes to the one address")
    end
end)
