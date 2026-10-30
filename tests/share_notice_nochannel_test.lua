-- Share.lua: the one-time popup in a release without the public channel (Channel.AVAILABLE false, FR-026): the
-- part 2 text, and only the part 2 flag is set. One login.

local POPUP = "ONEKEYFISHING_SHARE_NOTICE"

reset_popup()
load_addon(function() ns.Channel.AVAILABLE = false end)
local L = ns.L

test("without the channel the notice has the part 2 first sentence, and closing it sets only shareNotice", function()
    fire("LOADING_SCREEN_DISABLED")
    advance(3)
    eq(rawget(_G, "last_popup"), POPUP, "shown")
    local text = StaticPopupDialogs[POPUP].text
    local first =
        L["OneKeyFishing now shares your catches under a random ID with your guild, group and friends who use it."]
    eq(text:sub(1, #first), first, "the part 2 sentence")
    assert(not text:find(L["It reaches your guild, group and friends, and anyone else through a hidden chat channel."],
        1, true), "no channel")
    accept_popup()
    eq(ns.db.shareNotice, true, "closed")
    eq(ns.db.shareNoticeChannel, false, "the channel's notice still owed for a release that has it")
    advance(600)
    eq(#channel_joins, 0, "nothing joined")
end)
