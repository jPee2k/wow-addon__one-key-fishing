-- Channel.lua: locks, kicks and bans while in the channel (specs/004-public-channel-sync, contracts/channel.md
-- "Locks, kicks, bans", research R4). The tests run in order and share one login; each move goes one index on.

channel_on = true

local NAMES = {}

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
load_addon()
local Channel = ns.Channel
for i, name in ipairs(Channel.NAMES) do
    NAMES[i] = name
end

-- Share.HeardInChannel stand-in: the players heard announcing in the channel this session.
local heard = { Friend = true }
ns.Share.HeardInChannel = function(name) return heard[name] == true end

local function notice(token, index, player, actor)
    channel_notice("CHAT_MSG_CHANNEL_NOTICE_USER", token, NAMES[index], player, actor)
end

local function index()
    local state, current = Channel.GetState()
    return state == "in" and current or state
end

test("the main channel is joined after the login delay", function()
    advance(65)
    eq(index(), 1, "in the main channel")
end)

test("a password set by a stranger while this client owns the channel is cleared at once, and nobody moves", function()
    notice("PASSWORD_CHANGED", 1, "Griefer")
    eq(channel_owner_queries[#channel_owner_queries], NAMES[1], "asks who owns the channel")
    eq(#channel_passwords, 0, "nothing cleared before the answer")
    notice("CHANNEL_OWNER", 1, "First Last")
    eq(#channel_passwords, 1, "cleared")
    eq(channel_passwords[1].name, NAMES[1], "on our channel")
    eq(channel_passwords[1].password, "", "an empty password")
    advance(30)
    eq(index(), 1, "no move")
end)

test("a stranger's password undone by a player heard announcing within the wait: nobody moves", function()
    notice("OWNER_CHANGED", 1, "Owner") -- somebody else owns it now
    local passwords = #channel_passwords
    notice("PASSWORD_CHANGED", 1, "Griefer")
    advance(5)
    notice("PASSWORD_CHANGED", 1, "Friend") -- an addon owner clears it
    advance(30)
    eq(index(), 1, "no move")
    eq(#channel_passwords, passwords, "this client did not touch the password")
end)

test("a change by a player heard announcing alone starts nothing", function()
    local queries = #channel_owner_queries
    notice("PASSWORD_CHANGED", 1, "Friend")
    advance(30)
    eq(index(), 1, "no move")
    eq(#channel_owner_queries, queries, "nobody asked")
end)

test("a stranger's password nobody undoes: the move to the next name after the random 10-20 s wait", function()
    notice("PASSWORD_CHANGED", 1, "Griefer")
    notice("CHANNEL_OWNER", 1, "Owner")
    advance(9.5)
    eq(index(), 1, "still waiting")
    advance(11)
    eq(channel_leaves[#channel_leaves], NAMES[1], "left")
    eq(channel_joins[#channel_joins].name, NAMES[2], "joined the first fallback")
    advance(5)
    eq(index(), 2, "in the first fallback")
end)

test("moderation set by a stranger moves on after the wait, even for the owner (it has no undo call)", function()
    notice("OWNER_CHANGED", 2, "First Last")
    local passwords = #channel_passwords
    notice("MODERATION_ON", 2, "Griefer")
    eq(#channel_passwords, passwords, "no password call for moderation")
    advance(25)
    advance(5)
    eq(index(), 3, "moved on")
end)

test("becoming the owner after a lock clears the password; becoming it without one does not", function()
    local passwords = #channel_passwords
    notice("OWNER_CHANGED", 3, "First Last")
    eq(#channel_passwords, passwords, "no lock seen: nothing cleared")
    notice("OWNER_CHANGED", 3, "Other")
    notice("PASSWORD_CHANGED", 3, "Griefer")
    notice("CHANNEL_OWNER", 3, "Other")
    advance(5)
    notice("OWNER_CHANGED", 3, "First Last-Realm") -- the griefer left; with the realm, the player still matches
    eq(#channel_passwords, passwords + 1, "cleared")
    eq(channel_passwords[#channel_passwords].name, NAMES[3], "on that channel")
    advance(30)
    eq(index(), 3, "no move")
end)

test("a kick rejoins after 60 s; a kick of somebody else changes nothing; the third kick counts as a ban", function()
    notice("PLAYER_KICKED", 3, "Someone")
    eq(index(), 3, "somebody else")
    notice("PLAYER_KICKED", 3, "Me-Elsewhere")
    eq(index(), 3, "a player of the same name on another realm")
    local joins = #channel_joins
    notice("PLAYER_KICKED", 3, "First Last")
    eq(Channel.GetState() ~= "in", true, "out")
    fire("CHANNEL_UI_UPDATE") -- what the kick itself may bring: no early rejoin from it
    advance(30)
    in_combat = true
    fire("PLAYER_REGEN_DISABLED")
    in_combat = false
    fire("PLAYER_REGEN_ENABLED") -- the end of a pause calls the join check too
    advance(29)
    eq(#channel_joins, joins, "not before 60 s")
    advance(2)
    eq(channel_joins[#channel_joins].name, NAMES[3], "the same channel again")
    advance(5)
    eq(index(), 3, "back in")
    notice("PLAYER_KICKED", 3, "First Last")
    advance(66)
    eq(index(), 3, "back after the second kick")
    notice("PLAYER_KICKED", 3, "First Last")
    advance(5)
    eq(index(), 4, "the third kick: the next name")
end)

test("a ban of this player, or a mute, moves to the next name; a ban of somebody else does not", function()
    notice("PLAYER_BANNED", 4, "Someone")
    eq(index(), 4, "somebody else")
    notice("PLAYER_BANNED", 4, "First Last")
    advance(5)
    eq(index(), 5, "banned: the next name")
    notice("MUTED", 5)
    advance(5)
    eq(index(), 6, "muted: the next name")
end)

test("the game refusing the channel itself (TRIAL_RESTRICTED): locked, no fallback, until logout", function()
    local joins = #channel_joins
    notice("TRIAL_RESTRICTED", 6)
    eq(Channel.GetState(), "locked", "locked")
    advance(3600)
    eq(#channel_joins, joins, "nothing joined")
    eq(ns.Share.GetStatus().state ~= "unavailable", true, "guild, group and friends go on")
end)
