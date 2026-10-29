-- Share.lua: the one-time popup about the exchange. The first login lands in combat; nothing is exchanged before
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
    assert(dialog.text:find(L["No character names are sent."], 1, true), dialog.text)
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
    advance(120)
    eq(#addon_sent, 1, "a HELLO")
    eq(addon_sent[1].chatType, "GUILD", "to the guild")
    eq(ns.Share.GetStatus().state, "alone", "nobody answered yet")
end)
