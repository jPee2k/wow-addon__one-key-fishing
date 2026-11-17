-- UI/ShareNotice.lua and Exchange/ShareGame.lua:
-- the one-time popup about the exchange. The first login lands in combat; nothing is exchanged before
-- the popup is closed. The tests run in order and share one login.

local POPUP = "ONEKEYFISHING_SHARE_NOTICE"

in_guild = true
in_combat = true
reset_popup()
load_addon()

local L = ns.L

test("in combat at login the popup waits", function()
    fire("LOADING_SCREEN_DISABLED")
    advance(5)
    eq(rawget(_G, "last_popup"), nil, "not shown in combat")
end)

test("after combat the popup is shown with Got it and Settings", function()
    in_combat = false
    fire("PLAYER_REGEN_ENABLED")
    eq(rawget(_G, "last_popup"), POPUP, "shown")
    local dialog = StaticPopupDialogs[POPUP]
    local first = L["OneKeyFishing now shares your catches under a random ID with other players who use it."]
    eq(dialog.text:sub(1, #first), first, "the first sentence names other players (part 3, the channel)")
    local channel = L["It reaches your guild, group and friends, and anyone else through a hidden chat channel."]
    assert(dialog.text:find(channel, 1, true), "the channel is named")
    local seen = L["No character names are sent, but the players you exchange with can tell which ID is yours."]
    assert(dialog.text:find(seen, 1, true), "says what the players exchanged with can see: " .. dialog.text)
    assert(dialog.text:find(L["Turn it off in Options -> AddOns -> OneKeyFishing -> Shared database."], 1, true),
        "where to turn it off")
    eq(dialog.button1, L["Got it"], "first button")
    eq(dialog.button2, L["Settings"], "second button")
    eq(ns.db.settings.shareDB, true, "sharing is on by default")
end)

test("nothing is exchanged before the popup is closed", function()
    advance(600)
    eq(#addon_sent, 0, "no addon message")
    eq(#bn_sent, 0, "no Battle.net message")
    eq(ns.Share.GetStatus().state, "notice", "state")
    eq(ns.Share.StatusLine(), L["Waiting for you to read the notice"], "status line")
end)

test("the popup hidden with the whole interface (Alt+Z) does not count as closed", function()
    UIParent:Hide()
    StaticPopup_Hide("ONEKEYFISHING_SHARE_NOTICE")
    eq(ns.db.shareNotice, false, "still open as far as the player knows")
    UIParent:Show()
    StaticPopup_Show("ONEKEYFISHING_SHARE_NOTICE") -- the game shows it again with the interface
end)

test("Got it closes the popup for good and starts the exchange within 120 s", function()
    accept_popup()
    eq(ns.db.shareNotice, true, "saved")
    eq(ns.db.shareNoticeChannel, true, "the channel's notice is read with it (part 3, FR-022)")
    advance(120)
    local guild, channel = 0, 0
    for _, message in ipairs(addon_sent) do
        guild = guild + (message.chatType == "GUILD" and 1 or 0)
        channel = channel + (message.chatType == "CHANNEL" and 1 or 0)
    end
    eq(guild, 1, "a HELLO to the guild")
    eq(channel, 1, "and one to the hidden channel, joined after the notice")
    eq(#addon_sent, 2, "nothing else")
    eq(ns.Share.GetStatus().state, "alone", "nobody answered yet")
end)
