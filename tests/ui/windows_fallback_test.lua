-- The addon's windows on a client without the window template: each is still built, with a close button that
-- closes it in a fight.

no_window_template = true
load_addon()

ns.StatsFrame.Toggle()
ns.ShowCopyWindow("Title", "Text")
local windows = {
    statistics = assert(rawget(_G, "OneKeyFishingStatsFrame"), "the statistics window"),
    copy = assert(rawget(_G, "OneKeyFishingCopyWindow"), "the copy window"),
}

local function CloseButton(window)
    local found
    for _, frame in ipairs(frames) do
        if frame.parent == window and frame.template == "UIPanelCloseButton" then
            assert(not found, "one close button")
            found = frame
        end
    end
    return assert(found, "a close button")
end

for name, window in pairs(windows) do
    test("the " .. name .. " window without the template has a close button that works in combat", function()
        assert(window:IsShown(), "shown")
        local button = CloseButton(window)
        in_combat = true
        button.scripts.OnClick(button, "LeftButton")
        in_combat = false
        assert(not window:IsShown(), "closed")
        eq(window.toplevel, true, "top-level")
    end)
end
