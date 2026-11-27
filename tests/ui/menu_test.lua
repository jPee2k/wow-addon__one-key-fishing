-- UI/Widgets.lua: the addon's own menu (ns.OpenMenu, specs/029-blocked-actions). The game's menus take their rows
-- from a pool shared with the game's own menus, and rows created while addon code opens a menu stay tainted (a unit
-- menu reusing one could not set a raid marker in a fight, reproduced in game 2026-11-26): the addon's menus never
-- use them.

local escRegistered = 0
GameMenuEscPriority = { Menu = 2, AddOn = 8, AddOnPost2 = 10 }
function RegisterGameMenuEscHandler()
    escRegistered = escRegistered + 1
end

load_addon()

local owner = CreateFrame("Button")
local other = CreateFrame("Button")

local function MenuFrame()
    return _G.OneKeyFishingMenu
end

test("the addon's menus do not use the game's menu", function()
    local used = false
    MenuUtil = { CreateContextMenu = function() used = true end }
    ns.OpenRadioMenu(owner, { { value = 1, text = "One" } }, function() return false end, function() end)
    ns.OpenCheckboxMenu(owner, { { value = 1, text = "One" } }, function() return false end, function() end)
    OneKeyFishing_OnAddonCompartmentClick(nil, "RightButton")
    MenuUtil = nil
    assert(not used, "MenuUtil was called")
    assert(MenuFrame(), "the addon's menu frame")
end)

test("a radio closes the menu and passes its value; the mark follows the choice", function()
    local chosen = "a"
    local choices = { { value = "a", text = "A" }, { value = "b", text = "B" } }
    ns.OpenRadioMenu(owner, choices, function(value) return chosen == value end, function(value) chosen = value end)
    assert(MenuFrame():IsShown(), "shown")
    eq(#menu_entries, 2)
    assert(menu_entries[1].isSelected(), "A is marked")
    assert(not menu_entries[2].isSelected(), "B is not")
    menu_entries[2].onClick()
    eq(chosen, "b")
end)

test("a checkbox click keeps the menu open and redraws its marks; a row click runs it", function()
    local shown = { fish = true }
    ns.OpenCheckboxMenu(owner, { { value = "fish", text = "Fish" } }, function(value) return shown[value] end,
        function(value) shown[value] = not shown[value] end)
    local row = MenuFrame().rows[1]
    assert(row.text:GetText():find("Fish", 1, true), row.text:GetText())
    row.scripts.OnClick(row)
    eq(shown.fish, false, "toggled")
    assert(MenuFrame():IsShown(), "still open")
    row.scripts.OnClick(row)
    eq(shown.fish, true, "toggled back")
end)

test("a button closes the menu; a disabled one does nothing", function()
    local clicks = 0
    ns.OpenMenu(owner, function(_, root)
        root:CreateButton("Go", function() clicks = clicks + 1 end)
        root:CreateButton("Off", function() clicks = clicks + 10 end):SetEnabled(false)
    end)
    local rows = MenuFrame().rows
    rows[2].scripts.OnClick(rows[2])
    eq(clicks, 0, "disabled")
    assert(MenuFrame():IsShown(), "still open")
    rows[1].scripts.OnClick(rows[1])
    eq(clicks, 1)
    assert(not MenuFrame():IsShown(), "closed")
end)

test("a disabled entry's highlight is dimmed, as the game's; a reused row lights up fully again", function()
    ns.OpenMenu(other, function(_, root)
        root:CreateButton("Go", function() end)
        root:CreateButton("Off", function() end):SetEnabled(false)
    end)
    local rows = MenuFrame().rows
    eq(rows[1].highlight:GetAlpha(), 1, "enabled")
    eq(rows[2].highlight:GetAlpha(), 0.4, "disabled")
    MenuFrame():Hide()
    ns.OpenMenu(other, function(_, root)
        root:CreateButton("Go", function() end)
        root:CreateButton("On", function() end)
    end)
    eq(rows[2].highlight:GetAlpha(), 1, "the same row, enabled now")
    MenuFrame():Hide()
end)

test("a mark is its frame with the dot or check on top, as the game's; a reused row takes the new kind", function()
    local choices = { { value = "a", text = "A" }, { value = "b", text = "B" } }
    ns.OpenRadioMenu(other, choices, function(value) return value == "b" end, function() end)
    local rows = MenuFrame().rows
    assert(rows[1].box:IsShown() and not rows[1].mark:IsShown(), "an empty ring")
    assert(rows[2].box:IsShown() and rows[2].mark:IsShown(), "the ring and its dot")
    eq(rows[2].box.texture, "Interface\\Buttons\\UI-RadioButton")
    eq(table.concat(rows[2].box.texCoord, ","), "0,0.25,0,1", "the ring")
    eq(rows[2].mark.texture, "Interface\\Buttons\\UI-RadioButton")
    eq(table.concat(rows[2].mark.texCoord, ","), "0.25,0.5,0,1", "the dot")
    eq(anchor(rows[1].text, "LEFT")[2], 20, "the text after the mark")
    MenuFrame():Hide()
    ns.OpenCheckboxMenu(other, choices, function(value) return value == "b" end, function() end)
    assert(rows[2].box:IsShown() and rows[2].mark:IsShown(), "the box and its check")
    eq(rows[2].box.texture, "Interface\\Buttons\\UI-CheckBox-Up")
    eq(table.concat(rows[2].box.texCoord, ","), "0,1,0,1", "the whole box, not the radio's quarter")
    eq(rows[2].mark.texture, "Interface\\Buttons\\UI-CheckBox-Check")
    eq(table.concat(rows[2].mark.texCoord, ","), "0,1,0,1", "the whole check")
    MenuFrame():Hide()
    ns.OpenMenu(other, function(_, root)
        root:CreateButton("Go", function() end)
        root:CreateButton("On", function() end)
    end)
    assert(not rows[2].box:IsShown() and not rows[2].mark:IsShown(), "a button has no mark")
    eq(anchor(rows[2].text, "LEFT")[2], 2, "its text at the row's edge")
    MenuFrame():Hide()
end)

test("a press outside closes it; a press on its owner closes it and the owner's click does not reopen it", function()
    local function Open(from)
        ns.OpenMenu(from, function(_, root) root:CreateButton("Go", function() end) end)
    end
    Open(owner)
    local menu = MenuFrame()
    menu.IsMouseOver = function() return false end
    owner.IsMouseOver = function() return false end
    menu.scripts.OnEvent(menu, "GLOBAL_MOUSE_DOWN")
    assert(not menu:IsShown(), "closed by a press elsewhere")
    Open(owner)
    owner.IsMouseOver = function() return true end
    menu.scripts.OnEvent(menu, "GLOBAL_MOUSE_DOWN")
    Open(owner) -- the owner's click after its press
    assert(not menu:IsShown(), "a second click on the owner closes it")
    owner.IsMouseOver = function() return false end
    Open(other)
    assert(menu:IsShown(), "another owner opens it")
end)

test("the owner's click after its press closes it, however late; the next click opens it again", function()
    local function Open()
        ns.OpenMenu(owner, function(_, root) root:CreateButton("Go", function() end) end)
    end
    local now = GetTime
    local clock = 100
    GetTime = function() return clock end
    Open()
    local menu = MenuFrame()
    menu.IsMouseOver = function() return false end
    owner.IsMouseOver = function() return true end
    menu.scripts.OnEvent(menu, "GLOBAL_MOUSE_DOWN") -- the press
    clock = clock + 0.1 -- the release, a few frames later
    Open()
    assert(not menu:IsShown(), "closed by the second click")
    clock = clock + 2
    Open()
    assert(menu:IsShown(), "a later click opens it")
    GetTime = now
    owner.IsMouseOver = function() return false end
end)

test("a press while the menu is closed forgets the owner's note: its next click opens the menu", function()
    local function Open()
        ns.OpenMenu(owner, function(_, root) root:CreateButton("Go", function() end) end)
    end
    Open()
    local menu = MenuFrame()
    menu.IsMouseOver = function() return false end
    owner.IsMouseOver = function() return true end
    menu.scripts.OnEvent(menu, "GLOBAL_MOUSE_DOWN") -- a press on the owner closes it; its release never clicks
    assert(not menu:IsShown())
    menu.scripts.OnEvent(menu, "GLOBAL_MOUSE_DOWN") -- a later press, the menu closed
    Open()
    assert(menu:IsShown(), "the owner's next click opens it")
    owner.IsMouseOver = function() return false end
end)

test("the menu closes with its owner", function()
    local window = CreateFrame("Frame")
    local button = CreateFrame("Button", nil, window)
    ns.OpenMenu(button, function(_, root) root:CreateButton("Go", function() end) end)
    local menu = MenuFrame()
    assert(menu:IsShown())
    window:Hide()
    menu.scripts.OnUpdate(menu, 0)
    assert(not menu:IsShown(), "closed when the owner's window hid")
end)

test("opening a menu notes it for a blocked action's state line", function()
    ns.OpenRadioMenu(owner, { { value = 1, text = "One" } }, function() return false end, function() end)
    fire("ADDON_ACTION_FORBIDDEN", "OneKeyFishing", "SetRaidTarget()")
    local log = ns.GetErrors()
    assert(log[#log].stack:find("last addon menu: radio menu", 1, true), log[#log].stack)
end)

test("Escape closes it with the special frames; the game's Escape chain is never written by the addon", function()
    ns.OpenMenu(owner, function(_, root) root:CreateButton("Go", function() end) end)
    local listed = false
    for _, name in ipairs(UISpecialFrames) do
        listed = listed or name == "OneKeyFishingMenu"
    end
    assert(listed, "in UISpecialFrames")
    eq(escRegistered, 0, "RegisterGameMenuEscHandler never called (it would taint every Escape)")
end)

test("a failing mark is logged and shows no menu", function()
    take_errors()
    ns.OpenMenu(owner, function(_, root) root:CreateRadio("Broken", nil, function() end) end, "marks")
    eq(#take_errors(), 1, "handed on")
    assert(not MenuFrame():IsShown(), "no menu")
end)

test("without an owner frame the menu opens at the cursor", function()
    ns.OpenMenu(nil, function(_, root) root:CreateButton("Go", function() end) end)
    assert(MenuFrame():IsShown(), "shown")
end)

test("a failing generator is logged and leaves the menu as it was; a failing entry is logged", function()
    ns.OpenMenu(owner, function(_, root) root:CreateButton("Kept", function() end) end, "good")
    take_errors()
    ns.OpenMenu(other, function(_, root)
        root:CreateButton("Half", function() end)
        error("broken generator")
    end, "broken")
    eq(#take_errors(), 1, "handed to the error handler")
    eq(menu_entries[1].text, "Kept", "the earlier entries stay")
    ns.OpenMenu(owner, function(_, root) root:CreateButton("Fails", function() error("broken entry") end) end, "bad")
    local row = MenuFrame().rows[1]
    row.scripts.OnClick(row)
    eq(#take_errors(), 1, "the entry's error handed on")
    local found = false
    for _, entry in ipairs(ns.GetErrors()) do
        found = found or entry.context == "menu bad"
    end
    assert(found, "logged under the menu's name")
end)
