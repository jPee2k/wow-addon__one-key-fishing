-- UI/ShareNotice.lua and Exchange/ShareGame.lua:
-- the notice shown once more to a player who closed the part 2 notice in an earlier release (FR-022): the
-- guild exchange keeps running meanwhile, and the channel waits for the notice. One login.

local POPUP = "ONEKEYFISHING_SHARE_NOTICE"

OneKeyFishingDB = { shareNotice = true } -- closed in 1.2.0 before the channel, shareNoticeChannel not set yet
in_guild = true
reset_popup()
load_addon()

test("the notice naming the channel shows again at login; the guild exchange does not wait for it", function()
    fire("LOADING_SCREEN_DISABLED")
    advance(3)
    eq(rawget(_G, "last_popup"), POPUP, "shown again")
    advance(120)
    eq(#addon_sent_since(0, "GUILD") >= 1, true, "the guild HELLO went out")
    eq(ns.Channel.GetState(), "notice", "the channel waits for the notice")
    eq(#channel_joins, 0, "not joined")
end)

test("closing it sets the channel's flag and the channel joins", function()
    accept_popup()
    eq(ns.db.shareNoticeChannel, true, "saved")
    eq(#channel_joins, 1, "joined at once: the login delay has passed")
    advance(5)
    eq(ns.Channel.GetState(), "in", "in")
end)
