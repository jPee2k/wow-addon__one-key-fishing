-- UI/Settings.lua, UI/Minimap.lua and /okf sound: the "Sound effects" page (specs/013-fishing-sounds US1, US2,
-- FR-001 to FR-004a): the switch, the minimap menu entry and the command agree on one saved option.

load_addon()

local L = ns.L
local page = settings_pages[L["Sound effects"]]

local function checkbox_of(text)
    local label = assert(find_frame(text, page), "the label " .. text)
    return label.parent
end

test("a Sound effects page with the switch, off by default", function()
    assert(page, "registered as a subcategory")
    page:Hide()
    page:Show()
    eq(checkbox_of(L["Play fishing sounds"]):GetChecked(), false, "off by default")
end)

test("clicking the switch turns the sounds on and fires SETTINGS_CHANGED", function()
    local box = checkbox_of(L["Play fishing sounds"])
    local changed
    ns.On("SETTINGS_CHANGED", function(key) changed = key end)
    box:SetChecked(true)
    box.scripts.OnClick(box)
    eq(ns.Sound.IsEnabled(), true, "on")
    eq(changed, "fishingSounds", "SETTINGS_CHANGED")
end)

test("a change from elsewhere shows on the open page", function()
    page:Hide()
    page:Show()
    ns.Sound.SetEnabled(false)
    eq(checkbox_of(L["Play fishing sounds"]):GetChecked(), false, "unchecked")
    ns.Sound.SetEnabled(true)
    eq(checkbox_of(L["Play fishing sounds"]):GetChecked(), true, "checked")
end)

-- The menu entry is a button whose text says what a click does (no checkbox).
local function menu_entry()
    local button = assert(_G.OneKeyFishingMinimapButton, "the minimap button")
    button.scripts.OnClick(button, "RightButton")
    for _, e in ipairs(menu_entries) do
        if e.text == L["Turn fishing sounds on"] or e.text == L["Turn fishing sounds off"] then
            return e
        end
    end
end

test("the minimap menu's entry names the action and switches the option", function()
    ns.Sound.SetEnabled(true)
    local entry = assert(menu_entry(), "the entry")
    eq(entry.kind, "button", "a plain button, not a checkbox")
    eq(entry.text, L["Turn fishing sounds off"], "on: offers to turn them off")
    entry.onClick()
    eq(ns.Sound.IsEnabled(), false, "switched off")
    eq(menu_entry().text, L["Turn fishing sounds on"], "off: offers to turn them on")
    eq(checkbox_of(L["Play fishing sounds"]):GetChecked(), false, "the page follows")
    menu_entry().onClick()
    eq(ns.Sound.IsEnabled(), true, "switched on again")
end)

test("/okf sound opens the Sound effects page", function()
    local before = #settings_opened
    SlashCmdList.ONEKEYFISHING("sound")
    eq(#settings_opened, before + 1, "opened")
    eq(settings_opened[#settings_opened], page.categoryID, "this page")
end)

-- US2: the volume slider.
local function slider_of()
    for _, frame in ipairs(frames) do
        if frame.template == "MinimalSliderWithSteppersTemplate" and frame.parent == page then
            return frame
        end
    end
end

test("the volume slider reads the volume and is greyed while the sounds are off", function()
    local slider = assert(slider_of(), "a slider on the page")
    ns.Sound.SetEnabled(false)
    page:Hide()
    page:Show()
    eq(slider.Slider:GetValue(), ns.Sound.Volume(), "the volume")
    eq(slider.minValue, 0, "from 0")
    eq(slider.maxValue, 100, "to 100")
    eq(slider.steps, 10, "in steps of 10")
    eq(slider:IsSliderEnabled(), false, "greyed while off")
    ns.Sound.SetEnabled(true)
    eq(slider:IsSliderEnabled(), true, "usable while on")
end)

test("moving the slider stores the volume and plays one sample", function()
    local slider = slider_of()
    sound_calls = {}
    slider:SetValue(70)
    eq(ns.Sound.Volume(), 70, "stored")
    eq(#sound_calls, 1, "one sample")
    slider:SetValue(70)
    eq(#sound_calls, 1, "the same value plays no new sample")
    ns.Sound.SetVolume(100)
end)

-- US3, US4: the two game settings, never greyed by the sounds switch.
test("the background and focus switches write their setting and fire SETTINGS_CHANGED", function()
    ns.Sound.SetEnabled(false)
    for key, label in pairs({ backgroundSound = L["Fishing sound in the background"],
        splashFocus = L["Splash focus while fishing"] }) do
        local box = checkbox_of(label)
        local changed
        ns.On("SETTINGS_CHANGED", function(k) changed = k end)
        box:SetChecked(true)
        box.scripts.OnClick(box)
        eq(ns.db.settings[key], true, key .. " on")
        eq(changed, key, key .. " fired")
        eq(box:IsEnabled(), true, key .. " usable with the sounds off")
        box:SetChecked(false)
        box.scripts.OnClick(box)
        eq(ns.db.settings[key], false, key .. " off")
    end
end)
