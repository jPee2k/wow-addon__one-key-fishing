-- Channel.lua: the answers to the addon's own leaves of a name, however late within their window and however many,
-- are never taken for the player's leave (specs/004-public-channel-sync, contracts/channel.md "Joining", "Locks,
-- kicks, bans"). The tests run in order and share one login.

local NAMES = {}

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
load_addon()
local Channel = ns.Channel
for i, name in ipairs(Channel.NAMES) do
    NAMES[i] = name
end

local function notice(token, index)
    channel_notice("CHAT_MSG_CHANNEL_NOTICE", token, NAMES[index])
end

-- The state with the index joined or, while waiting, the name being joined.
local function Where()
    local state, index = Channel.GetState()
    if state == "waiting" then
        for i, name in ipairs(NAMES) do
            if name == channel_joins[#channel_joins].name then
                index = i
            end
        end
    end
    return state .. tostring(index or "")
end

test("a second name of ours is left; its answer, late after a move to that name, is not the player's", function()
    advance(65)
    eq(Where(), "in1", "in the main channel")
    table.insert(channels_joined, { name = NAMES[2], number = 9 }) -- an old session's channel
    notice("YOU_JOINED", 2)
    eq(channel_leaves[#channel_leaves], NAMES[2], "left at once")
    notice("MUTED", 1) -- moves on: to that same name
    eq(Where(), "waiting2", "joining the first fallback")
    advance(2)
    notice("YOU_LEFT", 2) -- the answer to the leave above
    eq(Where(), "waiting2", "still joining")
    advance(5)
    eq(Where(), "in2", "in the first fallback")
end)

test("the setting unticked and ticked twice in a row: both answers are the addon's own", function()
    Channel.SetEnabled(false)
    Channel.SetEnabled(true)
    Channel.SetEnabled(false)
    Channel.SetEnabled(true)
    notice("YOU_LEFT", 2)
    notice("YOU_LEFT", 2)
    eq(Where(), "waiting2", "still joining")
    advance(5)
    eq(Where(), "in2", "in again")
end)

test("a leave the server never answered does not cover the player's /leave of that name later", function()
    Channel.SetEnabled(false) -- no answer comes to this leave
    advance(20)
    Channel.SetEnabled(true)
    advance(5)
    eq(Where(), "in2", "in again")
    Channel.SetEnabled(false)
    Channel.SetEnabled(true)
    notice("YOU_LEFT", 2) -- the answer to the second leave
    notice("YOU_JOINED", 2)
    advance(1)
    LeaveChannelByName(NAMES[2]) -- the player's /leave
    notice("YOU_LEFT", 2)
    eq(Channel.GetState(), "left", "left by hand")
end)
