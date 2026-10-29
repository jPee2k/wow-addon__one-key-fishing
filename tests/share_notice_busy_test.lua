-- Share.lua: the one-time popup when the game has no free dialog frame at first (other addons' prompts at login).
-- The tests run in order and share one login.

local POPUP = "ONEKEYFISHING_SHARE_NOTICE"

in_guild = true
reset_popup()
popup_frames_busy = true
load_addon()

test("while every dialog frame is busy the notice is tried again, and nothing is exchanged before", function()
    fire("LOADING_SCREEN_DISABLED")
    advance(5)
    eq(rawget(_G, "last_popup"), nil, "no frame was free")
    eq(#settings_opened, 0, "the Settings page did not open by itself (the game runs OnCancel for a failed show)")
    eq(ns.db.shareNotice, false, "not closed")
    eq(ns.Share.GetStatus().state, "notice", "still waiting for the notice")
    popup_frames_busy = false
    advance(30)
    eq(rawget(_G, "last_popup"), POPUP, "shown on the next try")
    eq(#addon_sent, 0, "nothing sent before it is closed")
end)

test("Got it on the retried notice closes it for good and starts the exchange", function()
    accept_popup()
    eq(ns.db.shareNotice, true, "saved")
    advance(120)
    eq(#addon_sent, 1, "a HELLO to the guild")
    advance(60)
    eq(rawget(_G, "last_popup"), POPUP, "no second popup")
end)
