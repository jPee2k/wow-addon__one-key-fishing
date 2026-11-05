-- UI/Settings.lua, the settings pages: right from their first view (spec 007, User Story 1).
-- The Settings panel shows a page with SetParent + Show (Blizzard_SettingsPanel.lua DisplayLayout); a page that is
-- still shown from its creation gets no OnShow there. The test shows the pages the same way.

-- The game's tooltip refuses an item without an ID; the test's tooltip does the same.
local tooltipItems = {}
GameTooltip = {
    SetOwner = function() end,
    SetItemByID = function(_, itemID)
        assert(itemID, "Usage: GameTooltip:SetItemByID(itemID)")
        table.insert(tooltipItems, itemID)
    end,
    Show = function() end,
    Hide = function() end,
    AddLine = function() end,
    AddDoubleLine = function() end,
}

load_addon()
local L = ns.L
local page = assert(settings_pages[L["Fishing gear"]], "the Fishing gear page is registered")
local main = assert(settings_pages["OneKeyFishing"], "the main page is registered")

test("the pages wait hidden for the panel, which shows them", function()
    assert(not page:IsShown() and not main:IsShown(), "hidden after creation")
    page:Show()
end)

-- Shown for the player: the frame and every parent up to the page.
local function visible(frame)
    while frame and frame ~= page do
        if not frame:IsShown() then
            return false
        end
        frame = frame.parent
    end
    return frame == page
end

local function shownRemoveButtons()
    local count = 0
    for _, frame in ipairs(frames) do
        if frame.text == L["Remove"] and visible(frame) then
            count = count + 1
        end
    end
    return count
end

-- The rows: the page's children with a tooltip on hover.
local function rows()
    local list = {}
    for _, frame in ipairs(frames) do
        if frame.parent == page and frame.scripts.OnEnter then
            table.insert(list, frame)
        end
    end
    return list
end

test("an empty gear list shows no row and says so, on the first view", function()
    eq(#ns.charDB.gear.items, 0, "no extra gear")
    eq(shownRemoveButtons(), 0, "Remove buttons shown")
    assert(visible(find_frame(L["No items yet."], page)), "the empty text is shown")
end)

test("hovering anywhere in the list shows no error", function()
    for _, row in ipairs(rows()) do
        row.scripts.OnEnter(row)
    end
    eq(#tooltipItems, 0, "no item tooltip without an item")
end)

test("added items get one row each, without switching pages", function()
    table.insert(ns.charDB.gear.items, 10001)
    table.insert(ns.charDB.gear.items, 10002)
    ns.Fire("GEAR_LIST_CHANGED")
    eq(shownRemoveButtons(), 2, "Remove buttons shown")
    for _, row in ipairs(rows()) do
        row.scripts.OnEnter(row)
    end
    eq(#tooltipItems, 2, "a tooltip for each row with an item")
end)

test("a removed item leaves the list", function()
    ns.Gear.RemoveItem(10001)
    eq(shownRemoveButtons(), 1, "Remove buttons shown")
end)

test("the page is not rebuilt while it is off screen", function()
    local searches = 0
    local find = ns.Gear.FindBestPole
    ns.Gear.FindBestPole = function(...)
        searches = searches + 1
        return find(...)
    end
    -- The panel closed: the page is still shown, its parent (the panel's canvas) is not.
    local canvas = CreateFrame("Frame")
    page.parent = canvas
    canvas:Hide()
    fire("BAG_UPDATE_DELAYED")
    eq(searches, 0, "no pole search while the panel is closed")
    page.parent = nil
    ns.Gear.FindBestPole = find
end)

test("the main page shows both keys of each action on its first view, within the page width", function()
    bindings.ONEKEYFISHING_ACTION = { "`", "'" }
    main:Show()
    local found
    for _, frame in ipairs(frames) do
        if frame.parent == main and type(frame.text) == "string" and frame.text:find("` / '", 1, true) then
            found = frame
        end
    end
    assert(found, "the key line names both keys")
    eq(found:GetWidth(), 560, "key line width")
end)
