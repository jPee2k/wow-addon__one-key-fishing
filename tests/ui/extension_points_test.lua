-- The extension points for code loaded after the addon (specs/027-import-export, User Story 2,
-- contracts/extension-points.md): /okf share lines, debug report sections, minimap menu entries, settings pages.
-- With none added, nothing changes; an addition that fails leaves the rest.

load_addon()
local L = ns.L

local function OpenMenu()
    OneKeyFishing_OnAddonCompartmentClick(nil, "RightButton")
end

local function lastEntry()
    return menu_entries[#menu_entries].text
end

test("with nothing added, the menu ends with the debug report", function()
    OpenMenu()
    eq(lastEntry(), L["Debug report"], "the last entry")
end)

test("an added minimap entry comes after the addon's own; a failing one leaves the menu whole", function()
    ns.MinimapMenu.AddEntries(function() error("broken entry") end)
    ns.MinimapMenu.AddEntries(function(root) root:CreateButton("Extra entry", function() end) end)
    OpenMenu()
    take_errors()
    eq(lastEntry(), "Extra entry", "added last")
    assert(menu_entry(L["Debug report"]), "the addon's entries are there")
end)

test("an added /okf share line prints after the addon's lines; nil adds nothing", function()
    ns.Share.AddStatusLine(function() return "Extra status line" end)
    ns.Share.AddStatusLine(function() return nil end)
    ns.Share.PrintStatus()
    assert(chat_contains("Extra status line"), "the line")
end)

test("an added report section comes before Errors; a failing one says so", function()
    ns.Debug.AddSection("Extra section", function(add) add("value %d", 7) end)
    ns.Debug.AddSection("Broken section", function() error("oops") end)
    local _, report = ns.Debug.Report()
    local extra = assert(report:find("-- Extra section --", 1, true), "the section")
    assert(report:find("  value 7", 1, true), "its line")
    assert(report:find("!! failed", 1, true), "the failing one")
    assert(extra < report:find("-- Errors --", 1, true), "before Errors")
end)

test("a page added after the registration is registered at once and opens", function()
    local frame = CreateFrame("Frame")
    local open = ns.SettingsUI.AddPage(frame, "Extra page")
    eq(settings_pages["Extra page"], frame, "registered")
    settings_opened = {}
    open()
    eq(#settings_opened, 1, "opened")
end)
