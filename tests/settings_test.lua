-- UI/Settings.lua: the "Shared database" page, and the popup's Settings button that opens it.

reset_popup()
load_addon()

local L = ns.L
local page = settings_pages[L["Shared database"]]

test("the popup's Settings button opens the Shared database page and closes the notice", function()
    fire("LOADING_SCREEN_DISABLED")
    advance(3)
    eq(rawget(_G, "last_popup"), "ONEKEYFISHING_SHARE_NOTICE", "shown")
    cancel_popup()
    eq(ns.db.shareNotice, true, "closed")
    eq(settings_opened[#settings_opened], page.categoryID, "the page opened")
    eq(ns.db.settings.shareDB, true, "the setting is still on")
end)

test("a Shared database page with the setting, the explanation and a status line", function()
    assert(page, "registered as a subcategory")
    local label = assert(find_frame(L["Use the shared catch database"], page), "checkbox label")
    local checkbox = label.parent
    assert(checkbox.scripts.OnClick, "a checkbox")
    assert(find_frame(L["Turned off: nothing is sent or received, and other players' data is not counted."], page),
        "explanation")
    page:Hide()
    page:Show()
    eq(page.status.text, ns.Share.StatusLine(), "status line on show")
end)

test("clicking the checkbox switches sharing and fires SETTINGS_CHANGED", function()
    local checkbox = find_frame(L["Use the shared catch database"], page).parent
    local changed
    ns.On("SETTINGS_CHANGED", function(key) changed = key end)
    checkbox.GetChecked = function() return false end
    checkbox.scripts.OnClick(checkbox)
    eq(ns.db.settings.shareDB, false, "off")
    eq(changed, "shareDB", "SETTINGS_CHANGED")
    page.scripts.OnUpdate(page, 1)
    eq(page.status.text, L["Shared catch database is off"], "the status follows every second")
    checkbox.GetChecked = function() return true end
    checkbox.scripts.OnClick(checkbox)
    eq(ns.db.settings.shareDB, true, "on")
end)
