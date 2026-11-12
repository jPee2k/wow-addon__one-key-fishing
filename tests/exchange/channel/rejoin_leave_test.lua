-- Channel.lua: a leave by hand of a name the addon left and joined again a moment before, after the answer to its own
-- leave has come (specs/004-public-channel-sync, contracts/channel.md "Joining"): that answer is used up, so the next
-- YOU_LEFT is the player's.

channel_on = true

local MAIN = "OneKeyFishingShare"
OneKeyFishingDB = { shareNotice = true, shareNoticeChannel = true }
load_addon()
local Channel = ns.Channel

local function notice(token)
    channel_notice("CHAT_MSG_CHANNEL_NOTICE", token, MAIN)
end

test("the setting unticked and ticked, the answers come, then a /leave: left until the next login", function()
    advance(65)
    eq(Channel.GetState(), "in", "in the main channel")
    Channel.SetEnabled(false) -- leaves
    Channel.SetEnabled(true) -- joins the same name again
    notice("YOU_LEFT") -- the answer to the leave
    notice("YOU_JOINED") -- the answer to the join
    eq(Channel.GetState(), "in", "in again")
    advance(1) -- inside the 5 s after the addon's own leave
    LeaveChannelByName(MAIN) -- the player's /leave
    notice("YOU_LEFT")
    eq(Channel.GetState(), "left", "left by hand")
end)
