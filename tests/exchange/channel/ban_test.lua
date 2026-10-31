-- Channel.lua: a ban whose YOU_LEFT comes before the PLAYER_BANNED notice (specs/004-public-channel-sync, FR-005a,
-- contracts/channel.md "Locks, kicks, bans"): a ban, not a leave by hand, so the client moves to the next name.

local MAIN = "OneKeyFishingShare"
OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
load_addon()

test("banned with the leave notice first: the next name, not 'left'", function()
    advance(65)
    eq(ns.Channel.GetState(), "in", "in the main channel")
    channel_notice("CHAT_MSG_CHANNEL_NOTICE", "YOU_LEFT", MAIN)
    channel_notice("CHAT_MSG_CHANNEL_NOTICE_USER", "PLAYER_BANNED", MAIN, "Me")
    advance(6)
    local state, index = ns.Channel.GetState()
    eq(state .. tostring(index), "in2", "in the first fallback")
    eq(channel_joins[#channel_joins].name, "OneKeyFishingShare2", "joined it")
end)
