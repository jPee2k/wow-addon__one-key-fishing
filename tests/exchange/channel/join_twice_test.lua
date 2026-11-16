-- Channel.lua: two join notices for one join of a second name of ours (YOU_JOINED and YOU_CHANGED) leave it once and
-- owe one answer, so a /leave of that name after a move to it is the player's (specs/004-public-channel-sync,
-- contracts/channel.md "Joining", "Locks, kicks, bans").

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

test("two join notices of a second name 6 s apart, a move to it and a /leave: left until the next login", function()
    advance(65)
    eq(Channel.GetState(), "in", "in the main channel")
    table.insert(channels_joined, { name = NAMES[2], number = 9 }) -- an old session's channel
    notice("YOU_JOINED", 2)
    advance(6) -- a laggy login
    notice("YOU_CHANGED", 2) -- a second notice for the same join, late
    local leaves = 0
    for _, name in ipairs(channel_leaves) do
        leaves = leaves + (name == NAMES[2] and 1 or 0)
    end
    eq(leaves, 1, "left once")
    notice("YOU_LEFT", 2) -- the one answer
    notice("MUTED", 1) -- moves on: to that name
    advance(1)
    LeaveChannelByName(NAMES[2]) -- the player's /leave while the join waits
    notice("YOU_LEFT", 2)
    eq(Channel.GetState(), "left", "left by hand")
end)
