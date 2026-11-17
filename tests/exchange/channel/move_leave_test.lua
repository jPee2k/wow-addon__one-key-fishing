-- Channel.lua: a leave by hand of the fallback joined after a move, within the echo window of the addon's own leave
-- of the old name (specs/004-public-channel-sync, contracts/channel.md "Locks, kicks, bans"; spec FR-005). The echo
-- window covers only the name the addon left: the leave of the new one is the player's.

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

test("a /leave of the fallback right after the move, the join confirmed: left until the next login", function()
    advance(65)
    eq(Channel.GetState(), "in", "in the main channel")
    notice("MUTED", 1) -- moves on: leaves the main channel, joins the first fallback
    eq(channel_joins[#channel_joins].name, NAMES[2], "joining the first fallback")
    notice("YOU_JOINED", 2) -- the server confirms at once
    local state, index = Channel.GetState()
    eq(state .. tostring(index), "in2", "in the first fallback")
    advance(1) -- well inside the 5 s echo window of the leave of the main channel
    LeaveChannelByName(NAMES[2]) -- the player's /leave
    notice("YOU_LEFT", 2)
    eq(Channel.GetState(), "left", "left by hand")
    local joins = #channel_joins
    advance(3600)
    eq(#channel_joins, joins, "not joined again this session")
end)
