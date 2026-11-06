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

---------------------------------------------------------------------------
-- The public channel (specs/004-public-channel-sync, US3)
---------------------------------------------------------------------------
-- The first frame inside the page whose text contains `text`.
local function TextWith(text)
    for _, frame in ipairs(frames) do
        if type(frame.text) == "string" and frame.text:find(text, 1, true) then
            local parent = frame
            while parent and parent ~= page do
                parent = parent.parent
            end
            if parent then
                return frame
            end
        end
    end
end

test("the page has the channel setting, the two sentences and the channel's state line", function()
    local label = assert(find_frame(L["Use the public channel"], page), "the checkbox label")
    eq(label.parent, page.channelBox, "on the page's channel checkbox")
    local where =
        L["With the public channel on, they also go to every other addon user, through a hidden chat channel."]
    assert(TextWith(where), "where the data goes")
    assert(TextWith(L["Anyone who joins that channel by its name can see which characters in it use the addon."]),
        "what others can see")
    page:Hide()
    page:Show()
    eq(page.channelLine.text, ns.Share.ChannelLine(), "the channel's line on show")
end)

test("the channel setting is greyed out while sharing is off and clickable again when it is on", function()
    local box = page.channelBox
    ns.Share.SetEnabled(false)
    eq(box:IsEnabled(), false, "greyed out")
    ns.Share.SetEnabled(true)
    eq(box:IsEnabled(), true, "clickable")
end)

test("clicking the channel setting calls Channel.SetEnabled; the state line follows with the status timer", function()
    local box = page.channelBox
    local changed
    ns.On("SETTINGS_CHANGED", function(key) changed = key end)
    box.GetChecked = function() return false end
    box.scripts.OnClick(box)
    eq(ns.db.settings.shareChannel, false, "off")
    eq(changed, "shareChannel", "SETTINGS_CHANGED")
    page.scripts.OnUpdate(page, 1)
    eq(page.channelLine.text, L["Public channel: off"], "the state line")
    box.GetChecked = function() return true end
    box.scripts.OnClick(box)
    eq(ns.db.settings.shareChannel, true, "on")
    page.scripts.OnUpdate(page, 1)
    eq(page.channelLine.text ~= L["Public channel: off"], true, "the state line again")
end)

---------------------------------------------------------------------------
-- Catch chances in tooltips (specs/005-catch-catalog, FR-019)
---------------------------------------------------------------------------
test("the main page has Show catch chances in tooltips, on by default; off fires SETTINGS_CHANGED", function()
    eq(ns.db.settings.tooltipChances, true, "on by default")
    local checkbox = assert(find_frame(L["Show catch chances in tooltips"]), "the checkbox").parent
    local changed
    ns.On("SETTINGS_CHANGED", function(key) changed = key end)
    checkbox.GetChecked = function() return false end
    checkbox.scripts.OnClick(checkbox)
    eq(ns.db.settings.tooltipChances, false, "off")
    eq(changed, "tooltipChances", "SETTINGS_CHANGED")
end)

---------------------------------------------------------------------------
-- The Debug report button
---------------------------------------------------------------------------
test("the main page's Debug report button shows the report in the copy window", function()
    click(L["Debug report"])
    local window = assert(rawget(_G, "OneKeyFishingCopyWindow"), "the copy window")
    assert(window:IsShown(), "shown")
    eq(window.title.text, L["OneKeyFishing - debug report"], "its title")
    assert(window.edit.text:find("== OneKeyFishing", 1, true), "the report")
end)
