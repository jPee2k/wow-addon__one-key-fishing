-- Comm.lua: the hidden "No player named ..." line is the offline signal (specs/010-exchange-forever-fixes US4,
-- contracts O1-O2). On Forever a whisper to an offline player returns 0, and the game prints that line (V12): the
-- filter hides it, ends the session to that address and drops what is queued to it, once.

load_addon()

local Comm = ns.Comm
local offline = {}
Comm.OnOffline(function(address) table.insert(offline, address) end)

local function SentTo(target)
    local count = 0
    for _, message in ipairs(addon_sent) do
        if message.chatType == "WHISPER" and message.target == target then
            count = count + 1
        end
    end
    return count
end

test("the hidden line ends the session to its address and drops what is queued to it, once", function()
    Comm.Send("w:Ann Lee", "Wab")
    Comm.Send("w:Ann Lee", "Wcd")
    advance(0)
    eq(SentTo("Ann Lee"), 1, "the first whisper went out")
    local line = ERR_CHAT_PLAYER_NOT_FOUND_S:format("Ann Lee")
    eq(filter_hides("CHAT_MSG_SYSTEM", line), true, "hidden")
    eq(#offline, 0, "the filter alone ends nothing (it may run once per chat window, or never)")
    fire("CHAT_MSG_SYSTEM", line)
    eq(table.concat(offline, " "), "w:Ann Lee", "the event ran the offline handlers for that address")
    advance(5)
    eq(SentTo("Ann Lee"), 1, "the queued whisper was dropped")
    fire("CHAT_MSG_SYSTEM", line)
    eq(filter_hides("CHAT_MSG_SYSTEM", line), true, "a repeat line is still hidden")
    eq(#offline, 1, "but the handlers run once")
end)

test("a line for a name not whispered is left to the game and ends nothing", function()
    wipe(offline)
    local line = ERR_CHAT_PLAYER_NOT_FOUND_S:format("Bob Stone")
    eq(filter_hides("CHAT_MSG_SYSTEM", line), false, "shown")
    fire("CHAT_MSG_SYSTEM", line)
    eq(#offline, 0, "nothing ended")
end)

test("with no chat window showing system lines (no filter runs), the event still ends the session", function()
    wipe(offline)
    Comm.Send("w:Cid Moon", "Wab")
    advance(1)
    fire("CHAT_MSG_SYSTEM", ERR_CHAT_PLAYER_NOT_FOUND_S:format("Cid Moon"))
    eq(table.concat(offline, " "), "w:Cid Moon", "ended")
end)

test("a target with a realm: the line shows 'A-B' as 'A B' (V12 seen), and that line ends the session", function()
    wipe(offline)
    Comm.Send("w:Dan Fox-OtherRealm", "Wab")
    advance(1)
    local line = ERR_CHAT_PLAYER_NOT_FOUND_S:format("Dan Fox OtherRealm")
    eq(filter_hides("CHAT_MSG_SYSTEM", line), true, "hidden")
    fire("CHAT_MSG_SYSTEM", line)
    eq(table.concat(offline, " "), "w:Dan Fox-OtherRealm", "ended")
end)
