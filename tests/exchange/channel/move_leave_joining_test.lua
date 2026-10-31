-- Channel.lua: a leave by hand of the fallback joined after a move, before the join is confirmed and within the echo
-- window of the addon's own leave of the old name (specs/004-public-channel-sync, contracts/channel.md "Locks, kicks,
-- bans"; spec FR-005): left, the fallback is not taken for locked and no third name is joined.

local NAMES = {}

OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
load_addon()
local Channel = ns.Channel
for i, name in ipairs(Channel.NAMES) do
    NAMES[i] = name
end

local function notice(token, index, player)
    channel_notice("CHAT_MSG_CHANNEL_NOTICE_USER", token, NAMES[index], player)
end

local function JoinsOf(name)
    local count = 0
    for _, join in ipairs(channel_joins) do
        if join.name == name then
            count = count + 1
        end
    end
    return count
end

test("a /leave of the fallback while its join waits: left, the fallback not locked, no third name", function()
    advance(65)
    eq(Channel.GetState(), "in", "in the main channel")
    notice("MUTED", 1) -- moves on: leaves the main channel, joins the first fallback
    eq(Channel.GetState(), "waiting", "the join of the first fallback waits")
    advance(1)
    LeaveChannelByName(NAMES[2]) -- the player's /leave
    notice("YOU_LEFT", 2)
    eq(Channel.GetState(), "left", "left by hand")
    advance(20) -- past every join check
    eq(Channel.GetState(), "left", "still left")
    eq(JoinsOf(NAMES[3]), 0, "no third name joined")
    local line = Channel.Describe()[1]
    eq(line:find("locked 1, kicks", 1, true) ~= nil, true, "only the main channel is locked, not the first fallback")
end)
