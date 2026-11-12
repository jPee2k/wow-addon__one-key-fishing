-- Share.lua and Comm.lua on an account whose addon messages the game refuses (a Trial or Veteran account): in a
-- guild, with a Battle.net friend playing Forever, never in a group. Only the guild is ever tried with more than a
-- greeting, yet the state says the exchange is unavailable. The tests run in order and share one login.

OneKeyFishingDB = { shareNotice = true }
in_guild = true
bn_friends = { { { gameAccountID = 11, clientProgram = "WoW", wowProjectID = 18, isOnline = true } } }
addon_send_result.default, bn_send_result = 9, 9 -- GeneralError on every path
load_addon()

local Share, Comm = ns.Share, ns.Comm
local L = ns.L

test("five refused HELLO rounds to the guild: unavailable, though group, whisper and bnet were never tried", function()
    advance(120 + 5 * 900) -- the first round after 60-120 s, then one every 10-15 minutes
    eq(Comm.private.GetPaths().guild.disabled, true, "the guild is left out")
    eq(Comm.private.GetPaths().bnet.disabled, false, "refused greetings do not leave Battle.net out")
    eq(Share.GetStatus().state, "unavailable", "state")
    eq(Share.StatusLine(), L["Exchange unavailable: the game refuses addon messages"], "status line")
    assert(Comm.GetPause() ~= "unavailable", "no pause: the paths not tried yet still may work")
end)

test("a later success on a path not tried yet clears it for good", function()
    addon_send_result.default = nil
    Comm.Send("w:Someone-Realm", "Wab")
    advance(1)
    eq(Share.GetStatus().state, "alone", "the game takes this account's messages")
    addon_send_result.default = 9
    for i = 1, 5 do
        Comm.Send("w:Someone" .. i .. "-Realm", "Wab") -- one player counts once
    end
    advance(5)
    eq(Comm.private.GetPaths().whisper.disabled, true, "whispers refused since")
    eq(Share.GetStatus().state, "alone", "still not unavailable: something went out this login")
    addon_send_result.default = nil
end)
