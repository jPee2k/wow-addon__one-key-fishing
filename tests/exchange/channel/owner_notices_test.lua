-- Channel.lua: the owner notices as seen in game on 2026-11-16 (spec 016 FR-006, FR-007, contracts S6). A stranger's
-- password is cleared once OWNER_CHANGED names the player in argument 2 ("First Last"); SET_MODERATOR, which names
-- the new owner by the first name only, changes nothing. One login.

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
load_addon()
local Channel = ns.Channel
local MAIN = "OneKeyFishingShare"

local function debugLine()
    return Channel.Describe()[1]
end

test("joined, a stranger's password, SET_MODERATOR with the first name: nothing cleared", function()
    advance(61)
    channel_notice("CHAT_MSG_CHANNEL_NOTICE", "YOU_CHANGED", MAIN)
    eq(Channel.GetState(), "in", "joined")
    channel_notice("CHAT_MSG_CHANNEL_NOTICE_USER", "PASSWORD_CHANGED", MAIN, "Some Stranger")
    local passwords = #channel_passwords
    local firstName = ns.PlayerName():match("^%S+")
    assert(firstName ~= ns.PlayerName(), "the stub's name has a first and a last name")
    channel_notice("CHAT_MSG_CHANNEL_NOTICE_USER", "SET_MODERATOR", MAIN, firstName)
    eq(#channel_passwords, passwords, "no password cleared")
    assert(debugLine():find("owner false", 1, true), "not the owner: " .. debugLine())
end)

test("OWNER_CHANGED with the player's full name: the owner clears the password once", function()
    local passwords = #channel_passwords
    channel_notice("CHAT_MSG_CHANNEL_NOTICE_USER", "OWNER_CHANGED", MAIN, ns.PlayerName())
    eq(#channel_passwords, passwords + 1, "one password change")
    eq(channel_passwords[#channel_passwords].name, MAIN, "on the main channel")
    eq(channel_passwords[#channel_passwords].password, "", "cleared")
    assert(debugLine():find("owner true", 1, true), "the owner: " .. debugLine())
    assert(debugLine():find("self-heals 1", 1, true), "one self-heal: " .. debugLine())
    advance(30) -- past the 10-20 s wait after the lock: the self-heal ended it, nobody moves
    eq(Channel.GetState(), "in", "still in the main channel")
    eq(#channel_joins, 1, "no move to a fallback")
end)
