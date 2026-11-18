-- The addon's two windows (the statistics window and the copy window of the debug report): the close button in a
-- fight, and how they stack. The game's own close button script hides through the panel manager, which refuses
-- addon code in combat (seen in game 2026-11-18); the stub does the same.

load_addon()

ns.StatsFrame.Toggle()
ns.ShowCopyWindow("Title", "Text")
local stats = assert(rawget(_G, "OneKeyFishingStatsFrame"), "the statistics window")
local copy = assert(rawget(_G, "OneKeyFishingCopyWindow"), "the copy window")
local windows = { statistics = stats, copy = copy }
-- How the addon opens each window (the copy window is only ever shown by ns.ShowCopyWindow).
local open = {
    statistics = function() ns.StatsFrame.Toggle() end,
    copy = function() ns.ShowCopyWindow("Title", "Text") end,
}

local function close(window)
    local button = assert(window.CloseButton, "the close button")
    button.scripts.OnClick(button, "LeftButton")
end

test("the stub's panel manager refuses addon code in combat, as the game does", function()
    local frame = CreateFrame("Frame", nil, nil, "BasicFrameTemplateWithInset")
    in_combat = true
    close(frame)
    assert(frame:IsShown(), "still shown")
    in_combat = false
    close(frame)
    assert(not frame:IsShown(), "hidden out of combat")
end)

for name, window in pairs(windows) do
    test("the close button closes the " .. name .. " window in combat", function()
        window:Show()
        in_combat = true
        close(window)
        in_combat = false
        assert(not window:IsShown(), "closed")
    end)

    test("the close button closes the " .. name .. " window out of combat", function()
        window:Show()
        close(window)
        assert(not window:IsShown(), "closed")
    end)

    test("the " .. name .. " window is a top-level dialog", function()
        eq(window.toplevel, true, "top-level: a click raises it with its children")
        -- the game's popups are DIALOG and top-level: a window of that strata raised by a click would cover them
        eq(window.strata, "HIGH", "strata: below the game's popups")
    end)

    test("opening the " .. name .. " window raises it", function()
        window:Hide()
        local raised = window.raised or 0
        open[name]()
        assert(window:IsShown(), "shown")
        assert((window.raised or 0) > raised, "raised")
    end)
end

test("Escape closes both windows: each is listed once under its name", function()
    local count = {}
    for _, name in ipairs(UISpecialFrames) do
        count[name] = (count[name] or 0) + 1
    end
    eq(count.OneKeyFishingStatsFrame, 1, "the statistics window")
    eq(count.OneKeyFishingCopyWindow, 1, "the copy window")
end)

test("a second report raises the copy window that is already shown", function()
    ns.ShowCopyWindow("Title", "Text")
    local raised = copy.raised
    ns.ShowCopyWindow("Title", "Other")
    assert(copy.raised > raised, "raised again")
    eq(copy.edit.text, "Other", "the new text")
end)

test("opening the catalog raises the statistics window that is already shown", function()
    stats:Show()
    local raised = stats.raised
    ns.StatsFrame.OpenCatalog()
    assert(stats.raised > raised, "raised again")
end)

test("the statistics window keeps its page after the close button", function()
    ns.StatsFrame.OpenCatalog()
    close(stats)
    ns.StatsFrame.Toggle()
    assert(stats:IsShown(), "shown again")
    assert(stats.catalogPage:IsShown(), "on the catalog page")
end)
