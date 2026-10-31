-- Share.lua and Channel.lua: the channel's setting changed while the notice is owed (specs/003-guild-group-sync,
-- data-model.md: a setting changed on the page that says what is shared counts as reading the notice). One login.

local POPUP = "ONEKEYFISHING_SHARE_NOTICE"

OneKeyFishingDB = { shareNotice = true } -- the channel's notice not read yet (FR-022)
reset_popup()
load_addon()

test("ticking the channel's box while the notice is owed closes it and joins", function()
    fire("LOADING_SCREEN_DISABLED")
    advance(65)
    eq(rawget(_G, "last_popup"), POPUP, "shown")
    eq(ns.Channel.GetState(), "notice", "the channel waits")
    ns.Channel.SetEnabled(true)
    eq(popups_hidden[#popups_hidden], POPUP, "the popup hidden")
    eq(ns.db.shareNoticeChannel, true, "read")
    eq(#channel_joins, 1, "joined")
end)
