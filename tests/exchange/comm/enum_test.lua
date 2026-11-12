-- Comm.lua reads the send results from Enum.SendAddonMessageResult when it loads: a patch that renumbers them
-- changes nothing (here every value is 20 higher than in the 1.60.1 export).
local RENUMBERED = {}
for name, value in pairs(Enum.SendAddonMessageResult) do
    RENUMBERED[name] = value + 20
end
Enum.SendAddonMessageResult = RENUMBERED
addon_send_result.default = RENUMBERED.Success

load_addon()

local Comm = ns.Comm
local offline = {}
Comm.OnOffline(function(address) table.insert(offline, address) end)

test("a success by the new number counts as sent", function()
    Comm.Send("w:Peer", "Wab")
    advance(1)
    assert(Comm.GetTraffic() > 0, "traffic counted")
    eq(Comm.private.GetPaths().whisper.failures, 0, "no refusal")
end)

test("TargetOffline by the new number reports the player offline, not a refusal", function()
    addon_send_result.WHISPER = RENUMBERED.TargetOffline
    Comm.Send("w:Gone-Realm", "Wab")
    advance(1)
    eq(offline[#offline], "w:Gone-Realm", "reported offline")
    eq(Comm.private.GetPaths().whisper.failures, 0, "not counted against the path")
end)

test("AddOnMessageLockdown by the new number pauses the exchange", function()
    addon_send_result.WHISPER = RENUMBERED.AddOnMessageLockdown
    Comm.Send("w:Peer", "Wab")
    advance(0)
    eq(Comm.GetPause(), "lockdown", "paused")
    addon_send_result.WHISPER = nil
    advance(61)
    eq(Comm.GetPause(), nil, "over")
end)

test("the old TargetOffline number is an ordinary refusal now", function()
    addon_send_result.WHISPER = 12
    Comm.Send("w:Peer", "Wab")
    advance(1)
    eq(Comm.private.GetPaths().whisper.failures, 1, "counted")
    addon_send_result.WHISPER = nil
end)
