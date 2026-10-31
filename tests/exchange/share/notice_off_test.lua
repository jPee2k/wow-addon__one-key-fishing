-- Share.lua: the one-time popup when the player turned sharing off on the settings page before it showed.

reset_popup()
load_addon()

test("turning the setting off before the popup closes the notice; no popup claims sharing", function()
    ns.Share.SetEnabled(false)
    eq(ns.db.shareNotice, true, "the page told the player what is shared")
    advance(5)
    fire("LOADING_SCREEN_DISABLED")
    advance(5)
    eq(rawget(_G, "last_popup"), nil, "no popup")
    eq(ns.Share.GetStatus().state, "off", "off")
    eq(#addon_sent, 0, "nothing sent")
end)
